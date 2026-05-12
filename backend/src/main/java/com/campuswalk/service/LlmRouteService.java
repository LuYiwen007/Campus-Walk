package com.campuswalk.service;

import com.campuswalk.config.AppProperties;
import com.campuswalk.dto.ChatTurn;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.server.ResponseStatusException;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.Consumer;
import java.util.regex.Pattern;

/**
 * 对话编排：多轮历史（user/assistant）参与路线规划与对话应用；纯文本走 DashScope 文本接口，含图走兼容模式 Chat + 视觉模型；无内置示例路线。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class LlmRouteService {

    private static final Pattern FENCE = Pattern.compile("^```(?:json)?\\s*([\\s\\S]*?)\\s*```$", Pattern.CASE_INSENSITIVE);
    private static final int MAX_TURN_CHARS = 2000;
    private static final int MAX_HISTORY_BLOCK_CHARS = 12000;

    private static final String DEFAULT_AR_VISION_SYSTEM = """
            你是校园场景建筑识别助手。用户会提供一张照片（可能含建筑外观）以及若干候选建筑的 id、名称与简介。
            你必须只输出一个 JSON 对象，不要 Markdown，不要解释性前缀。JSON 键为：
            building_id（整数，必须从候选 id 中选一个最匹配的；若无法判断则 null）、
            confidence（0 到 1 的小数）、
            note（一句中文说明）。
            """;

    private final AppProperties appProperties;
    private final ObjectMapper objectMapper;

    private final HttpClient dashscopeHttpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(45))
            .build();

    public record ReplyAndRoutes(String replyText, List<Map<String, Object>> routes) {}

    /** 单次请求附带的用户图片（Base64），mime 如 image/jpeg */
    public record UserImageAttachment(String mimeType, String base64) {}

    public ReplyAndRoutes generateReplyAndRoutes(String userText, List<ChatTurn> priorTurns, UserImageAttachment image) {
        List<Map<String, Object>> norm = planRoutesNormalized(userText, priorTurns, image);
        String reply = callDialogueApplication(userText, norm, priorTurns != null ? priorTurns : List.of())
                .filter(s -> !s.isBlank())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                        "对话应用未返回有效文本，请检查百炼应用与 DASHSCOPE_DIALOGUE_APP_ID"));
        return new ReplyAndRoutes(reply.strip(), norm);
    }

    /**
     * 仅路线规划（同步），供流式接口在 SSE 推送路线后再流式生成自然语言。
     */
    public List<Map<String, Object>> planRoutesNormalized(String userText, List<ChatTurn> priorTurns, UserImageAttachment image) {
        requireLlmConfigured();
        List<ChatTurn> history = priorTurns != null ? priorTurns : List.of();
        Optional<List<Map<String, Object>>> routesOpt = image != null && image.base64() != null && !image.base64().isBlank()
                ? callDashscopeRoutesWithImage(userText, history, image)
                : callDashscopeRoutesText(userText, history);
        if (routesOpt.isEmpty()) {
            log.warn("route planner: 无有效输出");
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "路线规划模型未返回有效结果，请检查 API、提示词、模型与网络");
        }
        List<Map<String, Object>> norm = normalizeRoutes(routesOpt.get());
        if (norm == null) {
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
                    "路线规划 JSON 校验失败：需要恰好 3 条路线且 route_number 为 1、2、3");
        }
        return norm;
    }

    /**
     * 百炼对话应用流式输出：通过 DashScope SSE，将增量文本片段交给 {@code onDelta}，返回拼接后的全文（用于落库）。
     */
    public String streamDialogueApplication(String userText, List<Map<String, Object>> routes, List<ChatTurn> history,
                                            Consumer<String> onDelta) {
        requireLlmConfigured();
        String key = appProperties.getDashscopeApiKey();
        String appId = appProperties.getDashscopeDialogueAppId();
        if (key == null || key.isBlank() || appId == null || appId.isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "未配置 DASHSCOPE_DIALOGUE_APP_ID");
        }
        try {
            Map<String, Object> routesWrapper = Map.of("routes", routes);
            String routesJson = objectMapper.writeValueAsString(routesWrapper);
            String histBlock = formatHistoryForDialogue(history);
            String prompt = "【此前对话】\n" + histBlock + "\n【用户原话】\n" + userText + "\n\n【路线规划 JSON】\n" + routesJson;
            String url = "https://dashscope.aliyuncs.com/api/v1/apps/" + appId.trim() + "/completion";
            Map<String, Object> body = new LinkedHashMap<>();
            body.put("input", Map.of("prompt", prompt));
            body.put("parameters", Map.of("incremental_output", true));

            String jsonBody = objectMapper.writeValueAsString(body);
            HttpRequest.Builder rb = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofMinutes(5))
                    .header("Authorization", "Bearer " + key.trim())
                    .header("Content-Type", "application/json")
                    .header("X-DashScope-SSE", "enable");
            String ws = appProperties.getDashscopeWorkspace();
            if (ws != null && !ws.isBlank()) {
                rb.header("X-DashScope-WorkSpace", ws.trim());
            }
            HttpRequest request = rb.POST(HttpRequest.BodyPublishers.ofString(jsonBody, StandardCharsets.UTF_8)).build();
            HttpResponse<java.io.InputStream> response = dashscopeHttpClient.send(request, HttpResponse.BodyHandlers.ofInputStream());
            int code = response.statusCode();
            if (code != 200) {
                String errBody = new String(response.body().readAllBytes(), StandardCharsets.UTF_8);
                log.warn("dialogue app stream HTTP {}: {}", code, truncate(errBody, 800));
                throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "对话应用流式请求失败: HTTP " + code);
            }
            StringBuilder full = new StringBuilder();
            AtomicReference<String> lastCumulative = new AtomicReference<>("");
            try (BufferedReader br = new BufferedReader(new InputStreamReader(response.body(), StandardCharsets.UTF_8))) {
                StringBuilder eventBlock = new StringBuilder();
                String line;
                while ((line = br.readLine()) != null) {
                    if (line.isEmpty()) {
                        if (!eventBlock.isEmpty()) {
                            consumeDialogueSseEvent(eventBlock.toString(), onDelta, full, lastCumulative);
                            eventBlock.setLength(0);
                        }
                        continue;
                    }
                    if (line.startsWith(":")) {
                        continue;
                    }
                    eventBlock.append(line).append('\n');
                }
                if (!eventBlock.isEmpty()) {
                    consumeDialogueSseEvent(eventBlock.toString(), onDelta, full, lastCumulative);
                }
            }
            return full.toString().strip();
        } catch (ResponseStatusException e) {
            throw e;
        } catch (Exception e) {
            log.warn("dialogue app stream failed: {}", e.toString());
            throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "对话应用流式调用异常: " + e.getMessage());
        }
    }

    /**
     * AR：单次视觉问答，返回模型文本（应为 JSON），不做路由解析。
     */
    public Optional<String> compatibleVisionPlainText(String systemPrompt, String userText, UserImageAttachment image) {
        if (image == null || image.base64() == null || image.base64().isBlank()) {
            return Optional.empty();
        }
        String url = appProperties.getDashscopeCompatibleChatUrl();
        if (url == null || url.isBlank()) {
            log.warn("dashscope: app.dashscope-compatible-chat-url is empty");
            return Optional.empty();
        }
        if (appProperties.getDashscopeApiKey() == null || appProperties.getDashscopeApiKey().isBlank()) {
            return Optional.empty();
        }
        String visionModel = appProperties.getDashscopeVisionModel() != null && !appProperties.getDashscopeVisionModel().isBlank()
                ? appProperties.getDashscopeVisionModel().trim()
                : "qwen-vl-plus";
        String sys = systemPrompt != null && !systemPrompt.isBlank() ? systemPrompt.strip() : DEFAULT_AR_VISION_SYSTEM;
        String mime = image.mimeType() != null && !image.mimeType().isBlank() ? image.mimeType().trim() : "image/jpeg";
        String dataUrl = "data:" + mime + ";base64," + image.base64();
        List<Map<String, Object>> userParts = new ArrayList<>();
        userParts.add(Map.of("type", "image_url", "image_url", Map.of("url", dataUrl)));
        userParts.add(Map.of("type", "text", "text", truncate(userText, 12000)));
        List<Object> messages = new ArrayList<>();
        messages.add(Map.of("role", "system", "content", sys));
        messages.add(Map.of("role", "user", "content", userParts));
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", visionModel);
        body.put("messages", messages);
        return postCompatibleChatPlainContent(url, body);
    }

    public String arVisionSystemPromptOrDefault() {
        String p = appProperties.getArBuildingVisionSystemPrompt();
        return p != null && !p.isBlank() ? p.strip() : DEFAULT_AR_VISION_SYSTEM;
    }

    private void consumeDialogueSseEvent(String block, Consumer<String> onDelta, StringBuilder full,
                                         AtomicReference<String> lastCumulative) throws Exception {
        String data = extractSseDataPayload(block);
        if (data == null || data.isBlank()) {
            return;
        }
        if ("[DONE]".equalsIgnoreCase(data.strip())) {
            return;
        }
        JsonNode root = objectMapper.readTree(data);
        if (root.has("code")) {
            String c = root.path("code").asText("");
            if (!c.isEmpty() && !"null".equalsIgnoreCase(c) && !"Success".equalsIgnoreCase(c)) {
                String msg = root.path("message").asText(root.toString());
                throw new IllegalStateException("DashScope: " + c + " — " + msg);
            }
        }
        JsonNode output = root.path("output");
        if (output.isMissingNode() || output.isNull()) {
            return;
        }
        String text = output.path("text").asText("");
        if (text.isEmpty()) {
            text = output.path("choices").path(0).path("message").path("content").asText("");
        }
        if (text.isEmpty()) {
            return;
        }
        String prev = lastCumulative.get();
        String piece;
        if (text.startsWith(prev)) {
            piece = text.substring(prev.length());
            lastCumulative.set(text);
        } else {
            piece = text;
            lastCumulative.set(prev + text);
        }
        if (!piece.isEmpty()) {
            full.append(piece);
            onDelta.accept(piece);
        }
    }

    private static String extractSseDataPayload(String block) {
        StringBuilder sb = new StringBuilder();
        for (String rawLine : block.split("\n")) {
            String line = rawLine.stripTrailing();
            if (line.startsWith("data:")) {
                if (!sb.isEmpty()) {
                    sb.append('\n');
                }
                sb.append(line.substring(5).trim());
            }
        }
        return sb.toString();
    }

    private Optional<String> postCompatibleChatPlainContent(String requestUrl, Map<String, Object> body) {
        try {
            String jsonBody = objectMapper.writeValueAsString(body);
            var spec = RestClient.create()
                    .post()
                    .uri(requestUrl)
                    .contentType(MediaType.APPLICATION_JSON)
                    .header("Authorization", "Bearer " + appProperties.getDashscopeApiKey().trim());
            String ws = appProperties.getDashscopeWorkspace();
            if (ws != null && !ws.isBlank()) {
                spec = spec.header("X-DashScope-WorkSpace", ws.trim());
            }
            String raw = spec.body(jsonBody).retrieve().body(String.class);
            if (raw == null || raw.isBlank()) {
                return Optional.empty();
            }
            JsonNode root = objectMapper.readTree(raw);
            if (root.path("error").isObject()) {
                log.warn("compatible chat error: {}", truncate(root.path("error").toString(), 500));
                return Optional.empty();
            }
            String content = extractCompatibleChatContent(root);
            return content.isBlank() ? Optional.empty() : Optional.of(content);
        } catch (RestClientResponseException e) {
            log.warn("compatible chat HTTP {}: {}", e.getStatusCode().value(),
                    truncate(e.getResponseBodyAsString(), 600));
            return Optional.empty();
        } catch (Exception e) {
            log.warn("compatible chat failed: {}", e.toString());
            return Optional.empty();
        }
    }

    private void requireLlmConfigured() {
        if (appProperties.getDashscopeApiKey() == null || appProperties.getDashscopeApiKey().isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "未配置 DASHSCOPE_API_KEY");
        }
        if (appProperties.getRoutePlannerSystemPrompt() == null || appProperties.getRoutePlannerSystemPrompt().isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "未配置 ROUTE_PLANNER_SYSTEM_PROMPT（路线规划 system）");
        }
        if (appProperties.getDashscopeDialogueAppId() == null || appProperties.getDashscopeDialogueAppId().isBlank()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "未配置 DASHSCOPE_DIALOGUE_APP_ID");
        }
    }

    private JsonNode extractJsonObject(String text) throws Exception {
        String t = text.strip();
        var m = FENCE.matcher(t);
        if (m.matches()) {
            t = m.group(1).strip();
        }
        try {
            return objectMapper.readTree(t);
        } catch (Exception e) {
            int start = t.indexOf('{');
            int end = t.lastIndexOf('}');
            if (start >= 0 && end > start) {
                return objectMapper.readTree(t.substring(start, end + 1));
            }
            return null;
        }
    }

    private Optional<List<Map<String, Object>>> callDashscopeRoutesText(String userText, List<ChatTurn> history) {
        String url = appProperties.getDashscopeBaseUrl();
        if (url == null || url.isBlank()) {
            log.warn("dashscope: app.dashscope-base-url is empty");
            return Optional.empty();
        }
        String model = appProperties.getDashscopeModel() != null && !appProperties.getDashscopeModel().isBlank()
                ? appProperties.getDashscopeModel().trim()
                : "qwen-turbo";
        List<Map<String, Object>> messages = buildPlannerMessages(history);
        messages.add(Map.of("role", "user", "content", truncate(userText, 8000)));

        Map<String, Object> body = new HashMap<>();
        body.put("model", model);
        body.put("input", Map.of("messages", messages));
        body.put("parameters", Map.of("result_format", "message"));
        return postDashscopeTextGeneration(url, body);
    }

    private Optional<List<Map<String, Object>>> callDashscopeRoutesWithImage(
            String userText, List<ChatTurn> history, UserImageAttachment image) {
        String url = appProperties.getDashscopeCompatibleChatUrl();
        if (url == null || url.isBlank()) {
            log.warn("dashscope: app.dashscope-compatible-chat-url is empty");
            return Optional.empty();
        }
        String visionModel = appProperties.getDashscopeVisionModel() != null && !appProperties.getDashscopeVisionModel().isBlank()
                ? appProperties.getDashscopeVisionModel().trim()
                : "qwen-vl-plus";

        List<Object> messages = new ArrayList<>();
        messages.add(Map.of("role", "system", "content", appProperties.getRoutePlannerSystemPrompt()));
        for (ChatTurn t : history) {
            if (!"user".equals(t.role()) && !"assistant".equals(t.role())) {
                continue;
            }
            messages.add(Map.of("role", t.role(), "content", truncate(t.content(), MAX_TURN_CHARS)));
        }
        String mime = image.mimeType() != null && !image.mimeType().isBlank() ? image.mimeType().trim() : "image/jpeg";
        String dataUrl = "data:" + mime + ";base64," + image.base64();
        List<Map<String, Object>> userParts = new ArrayList<>();
        userParts.add(Map.of("type", "image_url", "image_url", Map.of("url", dataUrl)));
        userParts.add(Map.of("type", "text", "text", truncate(userText.isBlank() ? "请根据图片规划三条步行路线（仅输出 JSON）。" : userText, 8000)));
        messages.add(Map.of("role", "user", "content", userParts));

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", visionModel);
        body.put("messages", messages);
        return postDashscopeCompatibleChat(url, body);
    }

    private List<Map<String, Object>> buildPlannerMessages(List<ChatTurn> history) {
        List<Map<String, Object>> messages = new ArrayList<>();
        messages.add(Map.of("role", "system", "content", appProperties.getRoutePlannerSystemPrompt()));
        for (ChatTurn t : history) {
            if (!"user".equals(t.role()) && !"assistant".equals(t.role())) {
                continue;
            }
            messages.add(Map.of("role", t.role(), "content", truncate(t.content(), MAX_TURN_CHARS)));
        }
        return messages;
    }

    private Optional<List<Map<String, Object>>> postDashscopeTextGeneration(String url, Map<String, Object> body) {
        try {
            String jsonBody = objectMapper.writeValueAsString(body);
            var spec = RestClient.create()
                    .post()
                    .uri(url)
                    .contentType(MediaType.APPLICATION_JSON)
                    .header("Authorization", "Bearer " + appProperties.getDashscopeApiKey().trim());
            String ws = appProperties.getDashscopeWorkspace();
            if (ws != null && !ws.isBlank()) {
                spec = spec.header("X-DashScope-WorkSpace", ws.trim());
            }
            String raw = spec.body(jsonBody).retrieve().body(String.class);
            return parseRoutesFromDashscopeResponse(raw, true);
        } catch (RestClientResponseException e) {
            log.warn("dashscope HTTP {}: {}", e.getStatusCode().value(),
                    truncate(e.getResponseBodyAsString(), 600));
            return Optional.empty();
        } catch (Exception e) {
            log.warn("dashscope call failed: {}", e.toString());
            return Optional.empty();
        }
    }

    private Optional<List<Map<String, Object>>> postDashscopeCompatibleChat(String url, Map<String, Object> body) {
        return postCompatibleChatPlainContent(url, body).flatMap(this::parseRoutesFromModelContent);
    }

    private Optional<List<Map<String, Object>>> parseRoutesFromDashscopeResponse(String raw, boolean legacyOutputShape) {
        if (raw == null || raw.isBlank()) {
            return Optional.empty();
        }
        try {
            JsonNode root = objectMapper.readTree(raw);
            String content;
            if (legacyOutputShape) {
                if (!root.has("output") || root.get("output").isNull()) {
                    log.warn("dashscope: 无 output: {}", truncate(raw, 600));
                    return Optional.empty();
                }
                content = root.path("output").path("choices").path(0).path("message").path("content").asText("");
            } else {
                content = extractCompatibleChatContent(root);
            }
            return parseRoutesFromModelContent(content);
        } catch (Exception e) {
            log.warn("parse dashscope response: {}", e.toString());
            return Optional.empty();
        }
    }

    private Optional<List<Map<String, Object>>> parseRoutesFromModelContent(String content) {
        if (content == null || content.isEmpty()) {
            log.warn("dashscope empty content");
            return Optional.empty();
        }
        try {
            JsonNode obj = extractJsonObject(content);
            if (obj == null || !obj.isObject()) {
                log.warn("dashscope parse json failed: {}", truncate(content, 500));
                return Optional.empty();
            }
            JsonNode routesNode = obj.path("routes");
            if (!routesNode.isArray()) {
                log.warn("dashscope: routes not array");
                return Optional.empty();
            }
            List<Map<String, Object>> routes = new ArrayList<>();
            for (JsonNode item : routesNode) {
                routes.add(objectMapper.convertValue(item, new TypeReference<>() {
                }));
            }
            return Optional.of(routes);
        } catch (Exception e) {
            log.warn("parse routes from model content: {}", e.toString());
            return Optional.empty();
        }
    }

    private String extractCompatibleChatContent(JsonNode root) {
        JsonNode msg = root.path("choices").path(0).path("message");
        JsonNode contentNode = msg.path("content");
        if (contentNode.isTextual()) {
            return contentNode.asText("").strip();
        }
        if (contentNode.isArray()) {
            StringBuilder sb = new StringBuilder();
            for (JsonNode n : contentNode) {
                if ("text".equals(n.path("type").asText())) {
                    sb.append(n.path("text").asText(""));
                }
            }
            return sb.toString().strip();
        }
        return "";
    }

    private Optional<String> callDialogueApplication(String userText, List<Map<String, Object>> routes, List<ChatTurn> history) {
        String key = appProperties.getDashscopeApiKey();
        String appId = appProperties.getDashscopeDialogueAppId();
        if (key == null || key.isBlank() || appId == null || appId.isBlank()) {
            return Optional.empty();
        }
        try {
            Map<String, Object> routesWrapper = Map.of("routes", routes);
            String routesJson = objectMapper.writeValueAsString(routesWrapper);
            String histBlock = formatHistoryForDialogue(history);
            String prompt = "【此前对话】\n" + histBlock + "\n【用户原话】\n" + userText + "\n\n【路线规划 JSON】\n" + routesJson;
            String url = "https://dashscope.aliyuncs.com/api/v1/apps/" + appId.trim() + "/completion";
            Map<String, Object> body = new HashMap<>();
            body.put("input", Map.of("prompt", prompt));
            body.put("parameters", Map.of());
            String jsonBody = objectMapper.writeValueAsString(body);
            var spec = RestClient.create()
                    .post()
                    .uri(url)
                    .contentType(MediaType.APPLICATION_JSON)
                    .header("Authorization", "Bearer " + key.trim());
            String ws = appProperties.getDashscopeWorkspace();
            if (ws != null && !ws.isBlank()) {
                spec = spec.header("X-DashScope-WorkSpace", ws.trim());
            }
            String raw = spec.body(jsonBody).retrieve().body(String.class);
            if (raw == null || raw.isBlank()) {
                return Optional.empty();
            }
            JsonNode root = objectMapper.readTree(raw);
            JsonNode output = root.path("output");
            String text = output.path("text").asText("").strip();
            if (text.isEmpty()) {
                text = output.path("choices").path(0).path("message").path("content").asText("").strip();
            }
            if (text.isEmpty()) {
                log.warn("dialogue app: empty text, raw snippet: {}", truncate(raw, 600));
                return Optional.empty();
            }
            return Optional.of(text);
        } catch (RestClientResponseException e) {
            log.warn("dialogue app HTTP {}: {}", e.getStatusCode().value(),
                    truncate(e.getResponseBodyAsString(), 600));
            return Optional.empty();
        } catch (Exception e) {
            log.warn("dialogue app failed: {}", e.toString());
            return Optional.empty();
        }
    }

    private String formatHistoryForDialogue(List<ChatTurn> history) {
        if (history == null || history.isEmpty()) {
            return "（无）";
        }
        StringBuilder sb = new StringBuilder();
        int budget = MAX_HISTORY_BLOCK_CHARS;
        for (ChatTurn t : history) {
            if (!"user".equals(t.role()) && !"assistant".equals(t.role())) {
                continue;
            }
            String line = t.role() + ": " + truncate(t.content(), MAX_TURN_CHARS) + "\n";
            if (sb.length() + line.length() > budget) {
                sb.append("…（更早对话已省略）\n");
                break;
            }
            sb.append(line);
        }
        return sb.length() == 0 ? "（无）" : sb.toString().strip();
    }

    private static String truncate(String s, int max) {
        if (s == null) {
            return "";
        }
        return s.length() <= max ? s : s.substring(0, max) + "...";
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> normalizeRoutes(List<Map<String, Object>> routes) {
        if (routes == null || routes.size() != 3) {
            return null;
        }
        List<Map<String, Object>> out = new ArrayList<>();
        var seen = new HashSet<Integer>();
        for (Map<String, Object> item : routes) {
            int n;
            try {
                n = ((Number) item.get("route_number")).intValue();
            } catch (Exception e) {
                return null;
            }
            if (n < 1 || n > 3 || !seen.add(n)) {
                return null;
            }
            Object exObj = item.get("scenic_spot_examples");
            if (!(exObj instanceof List<?> examplesRaw)) {
                return null;
            }
            List<String> examples = new ArrayList<>();
            for (Object x : examplesRaw) {
                examples.add(String.valueOf(x));
                if (examples.size() >= 3) {
                    break;
                }
            }
            int count;
            try {
                count = item.get("scenic_spot_count") != null
                        ? ((Number) item.get("scenic_spot_count")).intValue()
                        : examples.size();
            } catch (Exception e) {
                return null;
            }
            int durMin;
            int distM;
            try {
                durMin = ((Number) item.get("estimated_duration_minutes")).intValue();
                distM = ((Number) item.get("estimated_distance_meters")).intValue();
            } catch (Exception e) {
                return null;
            }
            Map<String, Object> row = new HashMap<>();
            row.put("route_number", n);
            row.put("start", String.valueOf(item.getOrDefault("start", "")).strip());
            row.put("end", String.valueOf(item.getOrDefault("end", "")).strip());
            row.put("scenic_spot_count", Math.max(0, count));
            row.put("scenic_spot_examples", examples);
            row.put("estimated_duration_minutes", Math.max(1, durMin));
            row.put("estimated_distance_meters", Math.max(1, distM));
            row.put("description", String.valueOf(item.getOrDefault("description", "")).strip());
            out.add(row);
        }
        if (!(seen.contains(1) && seen.contains(2) && seen.contains(3))) {
            return null;
        }
        out.sort(Comparator.comparingInt(r -> (Integer) r.get("route_number")));
        return out;
    }
}
