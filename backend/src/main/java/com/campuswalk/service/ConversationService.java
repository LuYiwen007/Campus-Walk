package com.campuswalk.service;

import com.campuswalk.dto.ChatTurn;
import com.campuswalk.entity.ChatMessage;
import com.campuswalk.entity.Conversation;
import com.campuswalk.entity.NavigationWaypoint;
import com.campuswalk.entity.RouteBatch;
import com.campuswalk.entity.RouteVariant;
import com.campuswalk.entity.User;
import com.campuswalk.repository.ChatMessageRepository;
import com.campuswalk.repository.ConversationRepository;
import com.campuswalk.repository.RouteBatchRepository;
import com.campuswalk.repository.RouteVariantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ConversationService {

    private static final Map<Integer, String> ROUTE_LABEL = Map.of(
            1, "路线一",
            2, "路线二",
            3, "路线三"
    );

    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_INSTANT;
    private static final int PLANNER_HISTORY_CHARS = 2000;

    private final ConversationRepository conversationRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final RouteBatchRepository routeBatchRepository;
    private final RouteVariantRepository routeVariantRepository;
    private final LlmRouteService llmRouteService;
    private final TransactionTemplate transactionTemplate;
    private final RouteWaypointEnrichmentService routeWaypointEnrichmentService;

    public Conversation requireOwned(User user, long conversationId) {
        Conversation conv = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "会话不存在"));
        if (!conv.getUserId().equals(user.getId())) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "会话不存在");
        }
        return conv;
    }

    @Transactional
    public Map<String, Object> createConversation(User user, String title) {
        Conversation conv = new Conversation();
        conv.setUserId(user.getId());
        conv.setTitle(title != null && !title.isBlank() ? title : "新对话");
        conv = conversationRepository.save(conv);

        ChatMessage welcome = new ChatMessage();
        welcome.setConversationId(conv.getId());
        welcome.setRole("assistant");
        welcome.setMessageType("text");
        welcome.setContent("你好，我是校园导览助手。告诉我你想从哪出发、想去哪，我会为你生成三条可选路线（路线一、路线二、路线三）。");
        welcome.setExtra(new HashMap<>());
        welcome = chatMessageRepository.save(welcome);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("conversation", convSummary(conv));
        out.put("welcome_message", messageToVo(welcome));
        return out;
    }

    public List<Map<String, Object>> listConversations(User user) {
        return conversationRepository.findByUserIdOrderByIdDesc(user.getId()).stream()
                .map(this::convSummary)
                .toList();
    }

    public List<Map<String, Object>> listMessages(User user, long conversationId) {
        requireOwned(user, conversationId);
        return chatMessageRepository.findByConversationIdOrderBySentAtAscIdAsc(conversationId).stream()
                .map(this::messageToVo)
                .toList();
    }

    public Object latestRouteBatch(User user, long conversationId) {
        requireOwned(user, conversationId);
        RouteBatch batch = routeBatchRepository.findLatestByConversationId(conversationId).orElse(null);
        if (batch == null) {
            return null;
        }
        List<RouteVariant> variants = routeVariantRepository.findByBatchIdOrderByRouteNumber(batch.getId());
        if (variants.isEmpty()) {
            return null;
        }
        return batchToVo(batch, variants);
    }

    /**
     * 多轮上下文下的路线对话：历史消息 → 用户本轮（可含图）→ 路线规划 → 对话应用 → 持久化 route_batch；
     * 响应含 {@code route_batch}；地图与分段导航由客户端高德 SDK 完成。
     */
    @Transactional
    public Map<String, Object> sendMessage(User user, long conversationId, String content, String imageBase64, String imageMimeType) {
        Conversation conv = requireOwned(user, conversationId);
        String text = content != null ? content.strip() : "";
        String img = imageBase64 != null ? imageBase64.strip() : "";
        if (text.isEmpty() && img.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "文本与图片不能同时为空");
        }
        if (!img.isEmpty() && img.length() > 8_000_000) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "图片 Base64 过大");
        }

        List<ChatMessage> prior = chatMessageRepository.findByConversationIdOrderBySentAtAscIdAsc(conversationId);
        List<ChatTurn> historyTurns = toPlannerChatTurns(prior);

        ChatMessage userMsg = new ChatMessage();
        userMsg.setConversationId(conv.getId());
        userMsg.setRole("user");
        userMsg.setMessageType(img.isEmpty() ? "text" : "image_text");
        userMsg.setContent(text.isEmpty() && !img.isEmpty() ? "（用户上传了图片）" : text);
        Map<String, Object> ux = new HashMap<>();
        if (!img.isEmpty()) {
            ux.put("has_image", true);
        }
        userMsg.setExtra(ux);
        userMsg = chatMessageRepository.save(userMsg);

        String plannerUserText = text.isEmpty() && !img.isEmpty() ? "请根据图片规划三条可选步行路线，仅输出 JSON。" : text;
        LlmRouteService.UserImageAttachment imageAtt = img.isEmpty()
                ? null
                : new LlmRouteService.UserImageAttachment(
                        imageMimeType != null && !imageMimeType.isBlank() ? imageMimeType : "image/jpeg", img);
        LlmRouteService.ReplyAndRoutes gen = llmRouteService.generateReplyAndRoutes(plannerUserText, historyTurns, imageAtt);

        ChatMessage assistantMsg = new ChatMessage();
        assistantMsg.setConversationId(conv.getId());
        assistantMsg.setRole("assistant");
        assistantMsg.setMessageType("route_plan");
        assistantMsg.setContent(gen.replyText());
        assistantMsg.setExtra(new HashMap<>(Map.of("has_route_batch", true)));
        assistantMsg = chatMessageRepository.save(assistantMsg);

        RouteBatch batch = new RouteBatch();
        batch.setConversationId(conv.getId());
        batch.setUserMessageId(userMsg.getId());
        batch.setAssistantMessageId(assistantMsg.getId());
        batch = routeBatchRepository.save(batch);

        for (Map<String, Object> r : gen.routes()) {
            RouteVariant v = new RouteVariant();
            v.setBatchId(batch.getId());
            int n = ((Number) r.get("route_number")).intValue();
            v.setRouteNumber(n);
            v.setStartLabel((String) r.get("start"));
            v.setEndLabel((String) r.get("end"));
            @SuppressWarnings("unchecked")
            List<String> ex = (List<String>) r.get("scenic_spot_examples");
            if (ex == null) {
                ex = List.of();
            }
            ex = new ArrayList<>(ex.subList(0, Math.min(3, ex.size())));
            int count = ((Number) r.getOrDefault("scenic_spot_count", ex.size())).intValue();
            v.setScenicSpotCount(count);
            v.setScenicSpotExamples(new ArrayList<>(ex));
            int durMin = ((Number) r.get("estimated_duration_minutes")).intValue();
            v.setEstimatedDurationSeconds(durMin * 60);
            v.setEstimatedDistanceMeters(((Number) r.get("estimated_distance_meters")).intValue());
            v.setDescription((String) r.getOrDefault("description", ""));
            routeWaypointEnrichmentService.attachWaypoints(v);
            routeVariantRepository.save(v);
        }
        assistantMsg = chatMessageRepository.findById(assistantMsg.getId()).orElseThrow();
        batch = routeBatchRepository.findById(batch.getId()).orElseThrow();
        List<RouteVariant> variants = routeVariantRepository.findByBatchIdOrderByRouteNumber(batch.getId());

        Map<String, Object> routeBatch = new LinkedHashMap<>();
        routeBatch.put("id", batch.getId());
        routeBatch.put("conversation_id", conv.getId());
        routeBatch.put("created_at", ISO.format(batch.getCreatedAt()));
        routeBatch.put("variants", variants.stream().map(this::variantToVo).toList());

        Map<String, Object> data = new LinkedHashMap<>();
        data.put("user_message", messageToVo(userMsg));
        data.put("assistant_message", messageToVo(assistantMsg));
        data.put("route_batch", routeBatch);
        return data;
    }

    /**
     * 与 {@link #sendMessage} 相同业务结果，但路线规划完成后先 SSE 推送 {@code route_batch}，再以 {@code delta} 流式输出百炼对话文本，最后 {@code done} 携带完整落库结构。
     */
    public void streamSendMessage(User user, long conversationId, String content, String imageBase64, String imageMimeType,
                                  SseEmitter emitter) {
        try {
            record UserTx(ChatMessage userMsg, List<ChatTurn> plannerHistory, String plannerUserText,
                          LlmRouteService.UserImageAttachment imageAtt) {
            }
            UserTx first = transactionTemplate.execute(status -> {
                Conversation conv = requireOwned(user, conversationId);
                String text = content != null ? content.strip() : "";
                String img = imageBase64 != null ? imageBase64.strip() : "";
                if (text.isEmpty() && img.isEmpty()) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "文本与图片不能同时为空");
                }
                if (!img.isEmpty() && img.length() > 8_000_000) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "图片 Base64 过大");
                }
                List<ChatMessage> prior = chatMessageRepository.findByConversationIdOrderBySentAtAscIdAsc(conversationId);
                List<ChatTurn> historyTurns = toPlannerChatTurns(prior);

                ChatMessage userMsg = new ChatMessage();
                userMsg.setConversationId(conv.getId());
                userMsg.setRole("user");
                userMsg.setMessageType(img.isEmpty() ? "text" : "image_text");
                userMsg.setContent(text.isEmpty() && !img.isEmpty() ? "（用户上传了图片）" : text);
                Map<String, Object> ux = new HashMap<>();
                if (!img.isEmpty()) {
                    ux.put("has_image", true);
                }
                userMsg.setExtra(ux);
                userMsg = chatMessageRepository.save(userMsg);

                String plannerUserText = text.isEmpty() && !img.isEmpty() ? "请根据图片规划三条可选步行路线，仅输出 JSON。" : text;
                LlmRouteService.UserImageAttachment imageAtt = img.isEmpty()
                        ? null
                        : new LlmRouteService.UserImageAttachment(
                                imageMimeType != null && !imageMimeType.isBlank() ? imageMimeType : "image/jpeg", img);
                return new UserTx(userMsg, historyTurns, plannerUserText, imageAtt);
            });

            emitter.send(SseEmitter.event().name("user").data(messageToVo(first.userMsg()), MediaType.APPLICATION_JSON));

            List<Map<String, Object>> routes = llmRouteService.planRoutesNormalized(
                    first.plannerUserText(), first.plannerHistory(), first.imageAtt());

            record RouteTx(long assistantId, long batchId) {
            }
            RouteTx rt = transactionTemplate.execute(status -> {
                Conversation conv = conversationRepository.findById(conversationId)
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "会话不存在"));
                ChatMessage assistantMsg = new ChatMessage();
                assistantMsg.setConversationId(conv.getId());
                assistantMsg.setRole("assistant");
                assistantMsg.setMessageType("route_plan");
                assistantMsg.setContent("");
                assistantMsg.setExtra(new HashMap<>(Map.of("has_route_batch", true)));
                assistantMsg = chatMessageRepository.save(assistantMsg);

                RouteBatch batch = new RouteBatch();
                batch.setConversationId(conv.getId());
                batch.setUserMessageId(first.userMsg().getId());
                batch.setAssistantMessageId(assistantMsg.getId());
                batch = routeBatchRepository.save(batch);

                for (Map<String, Object> r : routes) {
                    RouteVariant v = new RouteVariant();
                    v.setBatchId(batch.getId());
                    int n = ((Number) r.get("route_number")).intValue();
                    v.setRouteNumber(n);
                    v.setStartLabel((String) r.get("start"));
                    v.setEndLabel((String) r.get("end"));
                    @SuppressWarnings("unchecked")
                    List<String> ex = (List<String>) r.get("scenic_spot_examples");
                    if (ex == null) {
                        ex = List.of();
                    }
                    ex = new ArrayList<>(ex.subList(0, Math.min(3, ex.size())));
                    int count = ((Number) r.getOrDefault("scenic_spot_count", ex.size())).intValue();
                    v.setScenicSpotCount(count);
                    v.setScenicSpotExamples(new ArrayList<>(ex));
                    int durMin = ((Number) r.get("estimated_duration_minutes")).intValue();
                    v.setEstimatedDurationSeconds(durMin * 60);
                    v.setEstimatedDistanceMeters(((Number) r.get("estimated_distance_meters")).intValue());
                    v.setDescription((String) r.getOrDefault("description", ""));
                    routeWaypointEnrichmentService.attachWaypoints(v);
                    routeVariantRepository.save(v);
                }
                return new RouteTx(assistantMsg.getId(), batch.getId());
            });

            RouteBatch batchEntity = routeBatchRepository.findById(rt.batchId())
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "批次丢失"));
            List<RouteVariant> variants = routeVariantRepository.findByBatchIdOrderByRouteNumber(batchEntity.getId());
            emitter.send(SseEmitter.event().name("route_batch").data(batchToVo(batchEntity, variants), MediaType.APPLICATION_JSON));

            String streamed = llmRouteService.streamDialogueApplication(
                    first.plannerUserText(), routes, first.plannerHistory(),
                    piece -> {
                        try {
                            emitter.send(SseEmitter.event().name("delta").data(Map.of("text", piece), MediaType.APPLICATION_JSON));
                        } catch (IOException e) {
                            throw new UncheckedIOException(e);
                        }
                    });

            if (streamed == null || streamed.isBlank()) {
                throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "对话应用流式未返回有效文本");
            }

            transactionTemplate.execute(status -> {
                ChatMessage a = chatMessageRepository.findById(rt.assistantId())
                        .orElseThrow(() -> new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "助手消息丢失"));
                a.setContent(streamed);
                chatMessageRepository.save(a);
                return null;
            });

            ChatMessage userFresh = chatMessageRepository.findById(first.userMsg().getId()).orElseThrow();
            ChatMessage assistantFresh = chatMessageRepository.findById(rt.assistantId()).orElseThrow();
            variants = routeVariantRepository.findByBatchIdOrderByRouteNumber(batchEntity.getId());
            Map<String, Object> donePayload = new LinkedHashMap<>();
            donePayload.put("user_message", messageToVo(userFresh));
            donePayload.put("assistant_message", messageToVo(assistantFresh));
            donePayload.put("route_batch", batchToVo(batchEntity, variants));
            emitter.send(SseEmitter.event().name("done").data(donePayload, MediaType.APPLICATION_JSON));
            emitter.complete();
        } catch (ResponseStatusException e) {
            try {
                emitter.send(SseEmitter.event().name("error").data(Map.of(
                        "code", e.getStatusCode().value(),
                        "message", e.getReason() != null ? e.getReason() : e.getMessage()
                ), MediaType.APPLICATION_JSON));
            } catch (Exception ignored) {
                // ignore secondary failure
            }
            emitter.completeWithError(e);
        } catch (Exception e) {
            try {
                emitter.send(SseEmitter.event().name("error").data(Map.of(
                        "code", 500,
                        "message", e.getMessage() != null ? e.getMessage() : "stream failed"
                ), MediaType.APPLICATION_JSON));
            } catch (Exception ignored) {
                // ignore
            }
            emitter.completeWithError(e);
        }
    }

    private List<ChatTurn> toPlannerChatTurns(List<ChatMessage> prior) {
        List<ChatTurn> out = new ArrayList<>();
        for (ChatMessage m : prior) {
            if (!"user".equals(m.getRole()) && !"assistant".equals(m.getRole())) {
                continue;
            }
            String c = m.getContent() != null ? m.getContent() : "";
            if ("assistant".equals(m.getRole()) && "route_plan".equals(m.getMessageType())) {
                c = "[助手已给出路线规划，界面卡片中有三条路线摘要。]";
            } else if (c.length() > PLANNER_HISTORY_CHARS) {
                c = c.substring(0, PLANNER_HISTORY_CHARS) + "...";
            }
            if ("user".equals(m.getRole()) && "image_text".equals(m.getMessageType())) {
                c = "[用户曾发送图片消息] " + c;
            }
            out.add(new ChatTurn(m.getRole(), c));
        }
        return out;
    }

    public Map<String, Object> getRouteVariant(User user, long variantId) {
        RouteVariant v = routeVariantRepository.findById(variantId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "路线不存在"));
        RouteBatch batch = routeBatchRepository.findById(v.getBatchId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "批次不存在"));
        requireOwned(user, batch.getConversationId());
        return variantToVo(v);
    }

    private Map<String, Object> convSummary(Conversation c) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", c.getId());
        m.put("title", c.getTitle());
        m.put("created_at", ISO.format(c.getCreatedAt()));
        return m;
    }

    private Map<String, Object> messageToVo(ChatMessage m) {
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", m.getId());
        map.put("conversation_id", m.getConversationId());
        map.put("role", m.getRole());
        map.put("message_type", m.getMessageType());
        map.put("content", m.getContent());
        Map<String, Object> rawEx = m.getExtra();
        Map<String, Object> safeExtra = new LinkedHashMap<>();
        boolean hasImage = false;
        if (rawEx != null) {
            for (Map.Entry<String, Object> e : rawEx.entrySet()) {
                String k = e.getKey();
                if (k == null) {
                    continue;
                }
                if (k.startsWith("image_")) {
                    continue;
                }
                safeExtra.put(k, e.getValue());
                if ("has_image".equals(k) && Boolean.TRUE.equals(e.getValue())) {
                    hasImage = true;
                }
            }
        }
        map.put("extra", safeExtra);
        if (hasImage) {
            map.put("has_image", true);
        }
        map.put("sent_at", ISO.format(m.getSentAt()));
        if ("route_plan".equals(m.getMessageType())) {
            routeBatchRepository.findByAssistantMessageId(m.getId()).ifPresent(batch -> {
                List<RouteVariant> variants = routeVariantRepository.findByBatchIdOrderByRouteNumber(batch.getId());
                if (!variants.isEmpty()) {
                    map.put("route_batch", batchToVo(batch, variants));
                }
            });
        }
        return map;
    }

    private Map<String, Object> variantToVo(RouteVariant v) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", v.getId());
        m.put("route_number", v.getRouteNumber());
        m.put("display_label", ROUTE_LABEL.getOrDefault(v.getRouteNumber(), "路线" + v.getRouteNumber()));
        m.put("start_label", v.getStartLabel());
        m.put("end_label", v.getEndLabel());
        m.put("scenic_spot_count", v.getScenicSpotCount());
        m.put("scenic_spot_examples", v.getScenicSpotExamples() != null ? v.getScenicSpotExamples() : List.of());
        m.put("estimated_duration_seconds", v.getEstimatedDurationSeconds());
        m.put("estimated_distance_meters", v.getEstimatedDistanceMeters());
        m.put("description", v.getDescription());
        m.put("waypoints", waypointListToVo(v.getWaypoints()));
        return m;
    }

    private List<Map<String, Object>> waypointListToVo(List<NavigationWaypoint> wps) {
        if (wps == null || wps.isEmpty()) {
            return List.of();
        }
        return wps.stream().map(w -> {
            Map<String, Object> wm = new LinkedHashMap<>();
            wm.put("order", w.getOrder());
            wm.put("label", w.getLabel());
            if (w.getLatitude() != null) {
                wm.put("latitude", w.getLatitude());
            }
            if (w.getLongitude() != null) {
                wm.put("longitude", w.getLongitude());
            }
            return wm;
        }).toList();
    }

    private Map<String, Object> batchToVo(RouteBatch batch, List<RouteVariant> variants) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", batch.getId());
        m.put("conversation_id", batch.getConversationId());
        m.put("created_at", ISO.format(batch.getCreatedAt()));
        m.put("variants", variants.stream().map(this::variantToVo).toList());
        return m;
    }
}
