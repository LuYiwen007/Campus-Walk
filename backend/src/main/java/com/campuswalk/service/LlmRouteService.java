package com.campuswalk.service;

import com.campuswalk.config.AppProperties;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;

@Slf4j
@Service
@RequiredArgsConstructor
public class LlmRouteService {

    private static final String SYSTEM_PROMPT = """
            你是校园与城内步行导览助手。用户提出地点或校园内的出行需求时，你必须且只能输出一段合法 JSON（不要 Markdown 代码围栏，不要任何 JSON 以外的文字）。
            JSON 结构如下（routes 必须恰好包含 3 个对象，route_number 分别为 1、2、3）：
            {
              "reply_text": "给用户看的自然语言说明",
              "routes": [
                {
                  "route_number": 1,
                  "start": "起点名称或区域",
                  "end": "终点名称或区域",
                  "scenic_spot_count": 3,
                  "scenic_spot_examples": ["景点A","景点B"],
                  "estimated_duration_minutes": 25,
                  "estimated_distance_meters": 1200,
                  "description": "该路线的特点与体验描述"
                }
              ]
            }
            约束：
            - scenic_spot_examples 为字符串数组，长度不超过 scenic_spot_count，且最多 3 个元素。
            - 不要输出数据库建筑 id、内部编码或与建筑表绑定的字段；仅使用自然语言地点名。
            - estimated_duration_minutes、estimated_distance_meters 为正整数，合理即可。
            """;

    private static final Pattern FENCE = Pattern.compile("^```(?:json)?\\s*([\\s\\S]*?)\\s*```$", Pattern.CASE_INSENSITIVE);

    private final AppProperties appProperties;
    private final ObjectMapper objectMapper;

    public record ReplyAndRoutes(String replyText, List<Map<String, Object>> routes) {}

    public ReplyAndRoutes generateReplyAndRoutes(String userText) {
        if (appProperties.isUseMockLlm()) {
            return mockResult(userText);
        }
        Optional<ReplyAndRoutes> ds = callDashscope(userText);
        if (ds.isPresent()) {
            List<Map<String, Object>> norm = normalizeRoutes(ds.get().routes());
            if (norm != null) {
                return new ReplyAndRoutes(ds.get().replyText(), norm);
            }
        }
        log.info("fallback to mock llm routes");
        return mockResult(userText);
    }

    private ReplyAndRoutes mockResult(String userText) {
        String base = userText.strip().length() > 24 ? userText.strip().substring(0, 24) : userText.strip();
        if (base.isEmpty()) {
            base = "校园";
        }
        String reply = "已根据「" + base + "」为你规划了三条不同风格的路线，"
                + "请在下方选择「路线一 / 路线二 / 路线三」查看详情并进入 AR 导航。";
        List<Map<String, Object>> routes = new ArrayList<>();
        routes.add(route(1, "主校门", "图书馆", 3, List.of("林荫大道", "中央草坪", "湖心亭"), 22, 1400,
                "林荫主路，适合拍照与初次到访，路面平缓。"));
        routes.add(route(2, "东门", "体育馆", 2, List.of("梧桐道", "湖畔栈道"), 18, 1100,
                "沿湖慢行，人流较少，适合轻松散步。"));
        routes.add(route(3, "地铁站口", "实验楼", 2, List.of("商业街角", "连廊"), 15, 900,
                "距离较短，以连廊为主，适合赶时间。"));
        return new ReplyAndRoutes(reply, routes);
    }

    private Map<String, Object> route(int n, String start, String end, int count, List<String> examples,
                                      int durMin, int distM, String desc) {
        Map<String, Object> m = new HashMap<>();
        m.put("route_number", n);
        m.put("start", start);
        m.put("end", end);
        m.put("scenic_spot_count", count);
        m.put("scenic_spot_examples", new ArrayList<>(examples));
        m.put("estimated_duration_minutes", durMin);
        m.put("estimated_distance_meters", distM);
        m.put("description", desc);
        return m;
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

    private Optional<ReplyAndRoutes> callDashscope(String userText) {
        String key = appProperties.getDashscopeApiKey();
        if (key == null || key.isBlank()) {
            return Optional.empty();
        }
        String url = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation";
        Map<String, Object> body = new HashMap<>();
        body.put("model", "qwen-turbo");
        body.put("input", Map.of(
                "messages", List.of(
                        Map.of("role", "system", "content", SYSTEM_PROMPT),
                        Map.of("role", "user", "content", userText)
                )
        ));
        body.put("parameters", Map.of("result_format", "message"));
        try {
            String jsonBody = objectMapper.writeValueAsString(body);
            String raw = RestClient.create()
                    .post()
                    .uri(url)
                    .contentType(MediaType.APPLICATION_JSON)
                    .header("Authorization", "Bearer " + key)
                    .body(jsonBody)
                    .retrieve()
                    .body(String.class);
            if (raw == null) {
                return Optional.empty();
            }
            JsonNode root = objectMapper.readTree(raw);
            String content = root.path("output").path("choices").path(0).path("message").path("content").asText("");
            if (content.isEmpty()) {
                log.warn("dashscope empty content: {}", raw);
                return Optional.empty();
            }
            JsonNode obj = extractJsonObject(content);
            if (obj == null || !obj.isObject()) {
                log.warn("dashscope parse json failed: {}", content.length() > 500 ? content.substring(0, 500) : content);
                return Optional.empty();
            }
            String reply = obj.path("reply_text").asText("").strip();
            JsonNode routesNode = obj.path("routes");
            if (reply.isEmpty() || !routesNode.isArray()) {
                return Optional.empty();
            }
            List<Map<String, Object>> routes = new ArrayList<>();
            for (JsonNode item : routesNode) {
                routes.add(objectMapper.convertValue(item, new TypeReference<>() {
                }));
            }
            return Optional.of(new ReplyAndRoutes(reply, routes));
        } catch (Exception e) {
            log.warn("dashscope call failed: {}", e.toString());
            return Optional.empty();
        }
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
