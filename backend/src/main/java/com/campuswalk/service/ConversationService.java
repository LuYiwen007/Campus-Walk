package com.campuswalk.service;

import com.campuswalk.entity.ChatMessage;
import com.campuswalk.entity.Conversation;
import com.campuswalk.entity.RouteBatch;
import com.campuswalk.entity.RouteVariant;
import com.campuswalk.entity.User;
import com.campuswalk.repository.ChatMessageRepository;
import com.campuswalk.repository.ConversationRepository;
import com.campuswalk.repository.RouteBatchRepository;
import com.campuswalk.repository.RouteVariantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

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

    private final ConversationRepository conversationRepository;
    private final ChatMessageRepository chatMessageRepository;
    private final RouteBatchRepository routeBatchRepository;
    private final RouteVariantRepository routeVariantRepository;
    private final LlmRouteService llmRouteService;

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

    @Transactional
    public Map<String, Object> sendMessage(User user, long conversationId, String content) {
        Conversation conv = requireOwned(user, conversationId);
        String text = content.strip();

        ChatMessage userMsg = new ChatMessage();
        userMsg.setConversationId(conv.getId());
        userMsg.setRole("user");
        userMsg.setMessageType("text");
        userMsg.setContent(text);
        userMsg.setExtra(new HashMap<>());
        userMsg = chatMessageRepository.save(userMsg);

        LlmRouteService.ReplyAndRoutes gen = llmRouteService.generateReplyAndRoutes(text);

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
            routeVariantRepository.save(v);
        }

        userMsg = chatMessageRepository.findById(userMsg.getId()).orElseThrow();
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
        map.put("extra", m.getExtra() != null ? m.getExtra() : Map.of());
        map.put("sent_at", ISO.format(m.getSentAt()));
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
        return m;
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
