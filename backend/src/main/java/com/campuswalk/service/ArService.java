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
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Slf4j
@Service
@RequiredArgsConstructor
public class ArService {

    private static final double CANDIDATE_MAX_DEG = 0.012;
    private static final int MAX_CANDIDATES = 15;

    private final RouteVariantRepository routeVariantRepository;
    private final RouteBatchRepository routeBatchRepository;
    private final ConversationService conversationService;
    private final ARSessionRepository arSessionRepository;
    private final ARRecognitionEventRepository arRecognitionEventRepository;
    private final BuildingRepository buildingRepository;
    private final LlmRouteService llmRouteService;
    private final ObjectMapper objectMapper;

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
    public Map<String, Object> recognize(User user, Long sessionId, double latitude, double longitude, double heading,
                                           String imageBase64, String imageMimeType) {
        String img = imageBase64 != null ? imageBase64.strip() : "";
        if (!img.isEmpty() && img.length() > 8_000_000) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "图片 Base64 过大");
        }

        Nearest geo = nearestBuilding(latitude, longitude);
        List<Building> candidates = buildingsNearSorted(latitude, longitude, CANDIDATE_MAX_DEG, MAX_CANDIDATES);

        Nearest chosen = geo;
        String matchNote = geo.building() != null ? "后端根据坐标匹配最近建筑" : "未找到附近建筑";
        Map<String, Object> rawMeta = new LinkedHashMap<>();
        rawMeta.put("source", "nearest_geospatial");

        if (!img.isEmpty() && !candidates.isEmpty()) {
            Optional<VisionPick> pick = tryVisionPick(latitude, longitude, img, imageMimeType, candidates);
            if (pick.isPresent()) {
                VisionPick vp = pick.get();
                rawMeta.put("source", "vision_compatible_chat");
                rawMeta.put("vision_note", vp.note());
                rawMeta.put("vision_confidence", vp.confidence());
                if (vp.building() != null) {
                    chosen = new Nearest(vp.building(), Math.max(geo.confidence(), vp.confidence()));
                    matchNote = "视觉模型结合候选库识别：" + (vp.note() != null && !vp.note().isBlank() ? vp.note() : "已匹配建筑");
                } else {
                    matchNote = vp.note() != null && !vp.note().isBlank()
                            ? "视觉分析：" + vp.note()
                            : (geo.building() != null ? matchNote : "视觉未锁定建筑，已尝试坐标最近候选");
                }
            } else {
                rawMeta.put("vision", "failed_or_empty");
            }
        } else if (!img.isEmpty()) {
            rawMeta.put("vision", "skipped_no_candidates");
            matchNote = geo.building() != null ? matchNote : "附近无建筑候选，请靠近校园建筑后重试";
        }

        final Nearest outNearest = chosen;
        final String outNote = matchNote;
        final Map<String, Object> outRaw = rawMeta;

        Map<String, Object> overlay = null;
        if (outNearest.building() != null) {
            Building b = outNearest.building();
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
                    ev.setBuildingId(outNearest.building() != null ? outNearest.building().getId() : null);
                    ev.setConfidence(outNearest.confidence());
                    ev.setClientLat(latitude);
                    ev.setClientLon(longitude);
                    ev.setClientHeading(heading);
                    ev.setRawResponse(outRaw);
                    arRecognitionEventRepository.save(ev);
                }
            });
        }
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("building", overlay);
        data.put("confidence", outNearest.confidence());
        data.put("match_note", outNearest.building() != null ? outNote : "未找到附近建筑");
        return data;
    }

    private record VisionPick(Building building, double confidence, String note) {
    }

    private Optional<VisionPick> tryVisionPick(double lat, double lon, String imgB64, String imageMimeType,
                                               List<Building> candidates) {
        try {
            List<Map<String, Object>> candJson = new ArrayList<>();
            for (Building b : candidates) {
                Map<String, Object> row = new LinkedHashMap<>();
                row.put("id", b.getId());
                row.put("name", b.getName());
                row.put("description", b.getDescription() != null ? b.getDescription() : "");
                row.put("latitude", b.getLatitude());
                row.put("longitude", b.getLongitude());
                candJson.add(row);
            }
            String userPrompt = """
                    用户当前位置纬度=%f，经度=%f。照片为朝向前方场景。
                    下列 JSON 数组为附近候选建筑（id 必须从中选择或填 null），仅输出一个 JSON 对象，键：building_id（整数或 null）、confidence（0-1）、note（中文短句）。
                    候选：%s
                    """.formatted(lat, lon, objectMapper.writeValueAsString(candJson));
            String sys = llmRouteService.arVisionSystemPromptOrDefault();
            LlmRouteService.UserImageAttachment att = new LlmRouteService.UserImageAttachment(
                    imageMimeType != null && !imageMimeType.isBlank() ? imageMimeType : "image/jpeg", imgB64);
            Optional<String> raw = llmRouteService.compatibleVisionPlainText(sys, userPrompt, att);
            if (raw.isEmpty()) {
                return Optional.empty();
            }
            String rawText = raw.get();
            JsonNode obj = extractJsonObject(rawText);
            if (obj == null || !obj.isObject()) {
                log.warn("ar vision: parse json failed: {}", rawText.length() > 400 ? rawText.substring(0, 400) + "..." : rawText);
                return Optional.empty();
            }
            double conf = obj.path("confidence").isNumber() ? obj.path("confidence").asDouble(0.3) : 0.3;
            String note = obj.path("note").asText("");
            if (obj.get("building_id") == null || obj.get("building_id").isNull()) {
                return Optional.of(new VisionPick(null, conf, note));
            }
            long bid = obj.path("building_id").asLong(-1);
            if (bid <= 0) {
                return Optional.of(new VisionPick(null, conf, note));
            }
            Building matched = candidates.stream().filter(b -> b.getId().equals(bid)).findFirst().orElse(null);
            if (matched == null) {
                return Optional.of(new VisionPick(null, conf, note + "（building_id 不在候选中）"));
            }
            return Optional.of(new VisionPick(matched, conf, note));
        } catch (Exception e) {
            log.warn("ar vision: {}", e.toString());
            return Optional.empty();
        }
    }

    private JsonNode extractJsonObject(String text) throws Exception {
        String t = text.strip();
        int start = t.indexOf('{');
        int end = t.lastIndexOf('}');
        if (start < 0 || end <= start) {
            return null;
        }
        return objectMapper.readTree(t.substring(start, end + 1));
    }

    private List<Building> buildingsNearSorted(double lat, double lon, double maxDeg, int limit) {
        List<Building> all = buildingRepository.findAll();
        record D(Building b, double d2) {
        }
        List<D> scored = new ArrayList<>();
        for (Building b : all) {
            double dLat = b.getLatitude() - lat;
            double dLon = b.getLongitude() - lon;
            double d2 = dLat * dLat + dLon * dLon;
            if (d2 <= maxDeg * maxDeg) {
                scored.add(new D(b, d2));
            }
        }
        scored.sort(Comparator.comparingDouble(D::d2));
        List<Building> out = new ArrayList<>();
        for (int i = 0; i < scored.size() && i < limit; i++) {
            out.add(scored.get(i).b());
        }
        return out;
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
