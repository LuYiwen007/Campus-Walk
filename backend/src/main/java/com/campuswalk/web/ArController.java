package com.campuswalk.web;

import com.campuswalk.service.ArService;
import com.campuswalk.service.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class ArController {

    private final CurrentUserService currentUserService;
    private final ArService arService;

    public record ARSessionCreateBody(long routeVariantId, Map<String, Object> deviceInfo) {
    }

    public record ARRecognizeBody(Long sessionId, double latitude, double longitude, double heading,
                                  String imageBase64, String imageMimeType) {
        public ARRecognizeBody {
            if (imageMimeType == null || imageMimeType.isBlank()) {
                imageMimeType = "image/jpeg";
            }
        }
    }

    @PostMapping("/ar/sessions")
    public ApiResponse<Map<String, Object>> startArSession(@RequestBody ARSessionCreateBody body) {
        var user = currentUserService.requireCurrentUser();
        Map<String, Object> device = body.deviceInfo() != null ? body.deviceInfo() : Map.of();
        return ApiResponse.ok(arService.startArSession(user, body.routeVariantId(), device));
    }

    @PostMapping("/ar/sessions/{sessionId}/end")
    public ApiResponse<Map<String, Object>> endArSession(@PathVariable long sessionId) {
        var user = currentUserService.requireCurrentUser();
        return ApiResponse.ok(arService.endArSession(user, sessionId));
    }

    @PostMapping("/ar/recognize")
    public ApiResponse<Map<String, Object>> recognize(@RequestBody ARRecognizeBody body) {
        var user = currentUserService.requireCurrentUser();
        double h = body.heading();
        return ApiResponse.ok(arService.recognize(user, body.sessionId(), body.latitude(), body.longitude(), h,
                body.imageBase64(), body.imageMimeType()));
    }

    @GetMapping("/buildings/{buildingId}")
    public ApiResponse<Map<String, Object>> getBuilding(@PathVariable long buildingId) {
        currentUserService.requireCurrentUser();
        return ApiResponse.ok(arService.getBuilding(buildingId));
    }
}
