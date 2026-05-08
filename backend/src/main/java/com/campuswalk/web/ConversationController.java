package com.campuswalk.web;

import com.campuswalk.service.ConversationService;
import com.campuswalk.service.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.core.task.AsyncTaskExecutor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class ConversationController {

    private final CurrentUserService currentUserService;
    private final ConversationService conversationService;
    @Qualifier("applicationTaskExecutor")
    private final AsyncTaskExecutor asyncTaskExecutor;

    public record ConversationCreateBody(String title) {
    }

    /**
     * {@code content} 与 {@code imageBase64} 至少其一非空；图片为 Base64 原文（建议 JPEG），由服务层校验长度。
     */
    public record SendMessageBody(String content, String imageBase64, String imageMimeType) {
        public SendMessageBody {
            if (content == null) {
                content = "";
            }
            if (imageMimeType == null || imageMimeType.isBlank()) {
                imageMimeType = "image/jpeg";
            }
        }
    }

    @PostMapping("/conversations")
    public ApiResponse<Map<String, Object>> createConversation(
            @RequestBody(required = false) ConversationCreateBody body
    ) {
        var user = currentUserService.requireCurrentUser();
        String title = body != null && body.title() != null ? body.title() : "新对话";
        return ApiResponse.ok(conversationService.createConversation(user, title));
    }

    @GetMapping("/conversations")
    public ApiResponse<List<Map<String, Object>>> listConversations() {
        var user = currentUserService.requireCurrentUser();
        return ApiResponse.ok(conversationService.listConversations(user));
    }

    @GetMapping("/conversations/{conversationId}/messages")
    public ApiResponse<List<Map<String, Object>>> listMessages(@PathVariable long conversationId) {
        var user = currentUserService.requireCurrentUser();
        return ApiResponse.ok(conversationService.listMessages(user, conversationId));
    }

    @GetMapping("/conversations/{conversationId}/route-batches/latest")
    public ApiResponse<Object> latestRouteBatch(@PathVariable long conversationId) {
        var user = currentUserService.requireCurrentUser();
        return ApiResponse.ok(conversationService.latestRouteBatch(user, conversationId));
    }

    @PostMapping("/conversations/{conversationId}/messages")
    public ApiResponse<Map<String, Object>> sendMessage(
            @PathVariable long conversationId,
            @RequestBody(required = false) SendMessageBody body
    ) {
        var user = currentUserService.requireCurrentUser();
        SendMessageBody b = body != null ? body : new SendMessageBody("", null, null);
        return ApiResponse.ok(conversationService.sendMessage(user, conversationId, b.content(), b.imageBase64(), b.imageMimeType()));
    }

    /**
     * 流式发送消息：{@code text/event-stream}，事件名 {@code user}、{@code route_batch}、{@code delta}、{@code done}、{@code error}；请求体与非流式接口相同。
     */
    @PostMapping(value = "/conversations/{conversationId}/messages/stream",
            consumes = MediaType.APPLICATION_JSON_VALUE,
            produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter streamSendMessage(
            @PathVariable long conversationId,
            @RequestBody(required = false) SendMessageBody body
    ) {
        var user = currentUserService.requireCurrentUser();
        SendMessageBody b = body != null ? body : new SendMessageBody("", null, null);
        SseEmitter emitter = new SseEmitter(300_000L);
        asyncTaskExecutor.execute(() -> conversationService.streamSendMessage(
                user, conversationId, b.content(), b.imageBase64(), b.imageMimeType(), emitter));
        return emitter;
    }

    @GetMapping("/route-variants/{variantId}")
    public ApiResponse<Map<String, Object>> getRouteVariant(@PathVariable long variantId) {
        var user = currentUserService.requireCurrentUser();
        return ApiResponse.ok(conversationService.getRouteVariant(user, variantId));
    }
}
