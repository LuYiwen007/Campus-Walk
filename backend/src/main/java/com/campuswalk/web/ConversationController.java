package com.campuswalk.web;

import com.campuswalk.service.ConversationService;
import com.campuswalk.service.CurrentUserService;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class ConversationController {

    private final CurrentUserService currentUserService;
    private final ConversationService conversationService;

    public record ConversationCreateBody(String title) {
    }

    public record SendMessageBody(
            @NotBlank @Size(max = 8000) String content
    ) {
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
            @RequestBody @jakarta.validation.Valid SendMessageBody body
    ) {
        var user = currentUserService.requireCurrentUser();
        return ApiResponse.ok(conversationService.sendMessage(user, conversationId, body.content()));
    }

    @GetMapping("/route-variants/{variantId}")
    public ApiResponse<Map<String, Object>> getRouteVariant(@PathVariable long variantId) {
        var user = currentUserService.requireCurrentUser();
        return ApiResponse.ok(conversationService.getRouteVariant(user, variantId));
    }
}
