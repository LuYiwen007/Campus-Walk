package com.campuswalk.web;

import com.campuswalk.service.CurrentUserService;
import com.campuswalk.service.NavigationService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/navigation")
@RequiredArgsConstructor
public class NavigationController {

    private final CurrentUserService currentUserService;
    private final NavigationService navigationService;

    public record CreateSessionBody(long routeVariantId) {
    }

    public record ProgressBody(Integer activeLegIndex, String status) {
    }

    @PostMapping("/sessions")
    public ApiResponse<Map<String, Object>> createSession(@RequestBody CreateSessionBody body) {
        var user = currentUserService.requireCurrentUser();
        return ApiResponse.ok(navigationService.createSession(user, body.routeVariantId()));
    }

    @PatchMapping("/sessions/{sessionId}")
    public ApiResponse<Map<String, Object>> patchSession(
            @PathVariable long sessionId,
            @RequestBody(required = false) ProgressBody body
    ) {
        var user = currentUserService.requireCurrentUser();
        Integer leg = body != null ? body.activeLegIndex() : null;
        String st = body != null ? body.status() : null;
        return ApiResponse.ok(navigationService.updateSession(user, sessionId, leg, st));
    }
}
