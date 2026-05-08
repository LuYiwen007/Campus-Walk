package com.campuswalk.service;

import com.campuswalk.entity.ARRecognitionEvent;
import com.campuswalk.entity.ARSession;
import com.campuswalk.entity.Building;
import com.campuswalk.entity.RouteBatch;
import com.campuswalk.entity.RouteVariant;
import com.campuswalk.entity.User;
import com.campuswalk.repository.ARRecognitionEventRepository;
import com.campuswalk.repository.ARSessionRepository;
import com.campuswalk.repository.BuildingRepository;
import com.campuswalk.repository.RouteBatchRepository;
import com.campuswalk.repository.RouteVariantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class ArService {

    private final RouteVariantRepository routeVariantRepository;
    private final RouteBatchRepository routeBatchRepository;
    private final ConversationService conversationService;
    private final ARSessionRepository arSessionRepository;
    private final ARRecognitionEventRepository arRecognitionEventRepository;
    private final BuildingRepository buildingRepository;

    public RouteVariant requireVariantOwned(User user, long variantId) {
        RouteVariant v = routeVariantRepository.findById(variantId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "路线不存在"));
        RouteBatch batch = routeBatchRepository.findById(v.getBatchId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "批次不存在"));
        conversationService.requireOwned(user, batch.getConversationId());
        return v;
    }

    @Transactional
    public Map<String, Object> startArSession(User user, long routeVariantId, Map<String, Object> deviceInfo) {
        RouteVariant v = requireVariantOwned(user, routeVariantId);
        RouteBatch batch = routeBatchRepository.findById(v.getBatchId()).orElseThrow();

        ARSession sess = new ARSession();
        sess.setUserId(user.getId());
        sess.setConversationId(batch.getConversationId());
        sess.setRouteVariantId(v.getId());
        sess.setDeviceInfo(deviceInfo != null ? new HashMap<>(deviceInfo) : new HashMap<>());
        sess = arSessionRepository.save(sess);

        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", sess.getId());
        m.put("route_variant_id", sess.getRouteVariantId());
        m.put("conversation_id", sess.getConversationId());
        m.put("started_at", java.time.format.DateTimeFormatter.ISO_INSTANT.format(sess.getStartedAt()));
        return m;
    }

    @Transactional
    public Map<String, Object> endArSession(User user, long sessionId) {
        ARSession sess = arSessionRepository.findById(sessionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "会话不存在"));
        if (!sess.getUserId().equals(user.getId())) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "会话不存在");
        }
        sess.setEndedAt(Instant.now());
        arSessionRepository.save(sess);
        return Map.of("ended", true);
    }

    @Transactional
    public Map<String, Object> recognize(User user, Long sessionId, double latitude, double longitude, double heading) {
        Nearest n = nearestBuilding(latitude, longitude);
        Map<String, Object> overlay = null;
        if (n.building() != null) {
            Building b = n.building();
            overlay = new LinkedHashMap<>();
            overlay.put("id", b.getId());
            overlay.put("name", b.getName());
            overlay.put("description", b.getDescription());
            overlay.put("cover_image_url", b.getCoverImageUrl());
            overlay.put("gallery_urls", b.getGalleryUrls() != null ? b.getGalleryUrls() : List.of());
        }
        if (sessionId != null) {
            arSessionRepository.findById(sessionId).ifPresent(sess -> {
                if (sess.getUserId().equals(user.getId())) {
                    ARRecognitionEvent ev = new ARRecognitionEvent();
                    ev.setSessionId(sess.getId());
                    ev.setBuildingId(n.building() != null ? n.building().getId() : null);
                    ev.setConfidence(n.confidence());
                    ev.setClientLat(latitude);
                    ev.setClientLon(longitude);
                    ev.setClientHeading(heading);
                    ev.setRawResponse(Map.of("source", "nearest_mock"));
                    arRecognitionEventRepository.save(ev);
                }
            });
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("building", overlay);
        data.put("confidence", n.confidence());
        data.put("match_note", n.building() != null ? "后端根据坐标匹配最近建筑（演示）" : "未找到附近建筑");
        return data;
    }

    private record Nearest(Building building, double confidence) {
    }

    private Nearest nearestBuilding(double lat, double lon) {
        List<Building> buildings = buildingRepository.findAll();
        if (buildings.isEmpty()) {
            return new Nearest(null, 0.0);
        }
        Building best = null;
        double bestD = 1e18;
        for (Building b : buildings) {
            double d = Math.pow(b.getLatitude() - lat, 2) + Math.pow(b.getLongitude() - lon, 2);
            if (d < bestD) {
                bestD = d;
                best = b;
            }
        }
        if (best == null || Math.sqrt(bestD) > 0.02) {
            return new Nearest(null, 0.0);
        }
        double conf = Math.max(0.2, 1.0 - Math.sqrt(bestD) * 50);
        return new Nearest(best, Math.min(conf, 0.99));
    }

    public Map<String, Object> getBuilding(long buildingId) {
        Building b = buildingRepository.findById(buildingId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "建筑不存在"));
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", b.getId());
        m.put("name", b.getName());
        m.put("description", b.getDescription());
        m.put("latitude", b.getLatitude());
        m.put("longitude", b.getLongitude());
        m.put("cover_image_url", b.getCoverImageUrl());
        m.put("gallery_urls", b.getGalleryUrls() != null ? b.getGalleryUrls() : List.of());
        return m;
    }
}
