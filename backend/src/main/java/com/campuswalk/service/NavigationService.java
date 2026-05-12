package com.campuswalk.service;

import com.campuswalk.entity.NavigationSession;
import com.campuswalk.entity.NavigationWaypoint;
import com.campuswalk.entity.RouteBatch;
import com.campuswalk.entity.RouteVariant;
import com.campuswalk.entity.User;
import com.campuswalk.entity.Conversation;
import com.campuswalk.repository.ConversationRepository;
import com.campuswalk.repository.NavigationSessionRepository;
import com.campuswalk.repository.RouteBatchRepository;
import com.campuswalk.repository.RouteVariantRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class NavigationService {

    private final RouteVariantRepository routeVariantRepository;
    private final RouteBatchRepository routeBatchRepository;
    private final ConversationRepository conversationRepository;
    private final NavigationSessionRepository navigationSessionRepository;
    private final RouteWaypointEnrichmentService routeWaypointEnrichmentService;

    @Transactional
    public Map<String, Object> createSession(User user, long variantId) {
        RouteVariant v = routeVariantRepository.findById(variantId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "路线不存在"));
        RouteBatch batch = routeBatchRepository.findById(v.getBatchId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "批次不存在"));
        requireVariantOwned(user, batch.getConversationId());

        if (v.getWaypoints() == null || v.getWaypoints().isEmpty()) {
            routeWaypointEnrichmentService.attachWaypoints(v);
            v = routeVariantRepository.save(v);
        } else {
            boolean missingCoord = v.getWaypoints().stream()
                    .anyMatch(w -> w.getLatitude() == null || w.getLongitude() == null);
            if (missingCoord) {
                routeWaypointEnrichmentService.attachWaypoints(v);
                v = routeVariantRepository.save(v);
            }
        }

        NavigationSession session = new NavigationSession();
        session.setUserId(user.getId());
        session.setRouteVariantId(v.getId());
        session.setActiveLegIndex(0);
        session.setStatus(NavigationSession.STATUS_IN_PROGRESS);
        session.setCreatedAt(Instant.now());
        session.setUpdatedAt(Instant.now());
        session = navigationSessionRepository.save(session);

        return sessionToVo(session, v);
    }

    @Transactional
    public Map<String, Object> updateSession(User user, long sessionId, Integer activeLegIndex, String status) {
        NavigationSession s = navigationSessionRepository.findById(sessionId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "导航会话不存在"));
        if (!s.getUserId().equals(user.getId())) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "导航会话不存在");
        }
        RouteVariant v = routeVariantRepository.findById(s.getRouteVariantId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "路线不存在"));

        if (activeLegIndex != null) {
            s.setActiveLegIndex(Math.max(0, activeLegIndex));
        }
        if (status != null && !status.isBlank()) {
            String st = status.trim().toUpperCase();
            if (NavigationSession.STATUS_COMPLETED.equals(st)
                    || NavigationSession.STATUS_CANCELLED.equals(st)
                    || NavigationSession.STATUS_IN_PROGRESS.equals(st)) {
                s.setStatus(st);
            }
        }
        s.setUpdatedAt(Instant.now());
        navigationSessionRepository.save(s);
        return sessionToVo(s, v);
    }

    private void requireVariantOwned(User user, long conversationId) {
        Conversation c = conversationRepository.findById(conversationId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "会话不存在"));
        if (!c.getUserId().equals(user.getId())) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "会话不存在");
        }
    }

    private Map<String, Object> sessionToVo(NavigationSession s, RouteVariant v) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", s.getId());
        m.put("route_variant_id", s.getRouteVariantId());
        m.put("active_leg_index", s.getActiveLegIndex());
        m.put("status", s.getStatus());
        m.put("created_at", s.getCreatedAt().toString());
        m.put("updated_at", s.getUpdatedAt().toString());
        m.put("waypoints", waypointsToVo(v.getWaypoints()));
        return m;
    }

    private List<Map<String, Object>> waypointsToVo(List<NavigationWaypoint> wps) {
        if (wps == null) {
            return List.of();
        }
        return wps.stream().map(w -> {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("order", w.getOrder());
            m.put("label", w.getLabel());
            if (w.getLatitude() != null) {
                m.put("latitude", w.getLatitude());
            }
            if (w.getLongitude() != null) {
                m.put("longitude", w.getLongitude());
            }
            return m;
        }).toList();
    }
}
