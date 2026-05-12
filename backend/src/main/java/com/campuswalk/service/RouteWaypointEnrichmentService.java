package com.campuswalk.service;

import com.campuswalk.entity.NavigationWaypoint;
import com.campuswalk.entity.RouteVariant;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/**
 * 根据路线变体的起终点与途经点名，生成有序途经点并调用高德地理编码写入坐标。
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RouteWaypointEnrichmentService {

    private final AmapGeocodeService amapGeocodeService;

    /**
     * 填充 {@link RouteVariant#setWaypoints(List)}（内存中，调用方负责 save）。
     */
    public void attachWaypoints(RouteVariant v) {
        List<String> chain = buildLabelChain(v);
        List<NavigationWaypoint> wps = new ArrayList<>();
        int order = 0;
        for (String label : chain) {
            var ll = amapGeocodeService.geocode(label);
            if (ll.isPresent()) {
                wps.add(new NavigationWaypoint(order++, label, ll.get().latitude(), ll.get().longitude()));
            } else {
                wps.add(new NavigationWaypoint(order++, label, null, null));
            }
        }
        v.setWaypoints(wps);
    }

    private List<String> buildLabelChain(RouteVariant v) {
        List<String> raw = new ArrayList<>();
        raw.add(v.getStartLabel());
        if (v.getScenicSpotExamples() != null) {
            for (String s : v.getScenicSpotExamples()) {
                if (s != null && !s.isBlank()) {
                    raw.add(s.strip());
                }
            }
        }
        raw.add(v.getEndLabel());
        // 去重且保序
        List<String> out = new ArrayList<>();
        Set<String> seen = new LinkedHashSet<>();
        for (String s : raw) {
            if (s == null || s.isBlank()) {
                continue;
            }
            String t = s.strip();
            if (seen.add(t)) {
                out.add(t);
            }
        }
        return out;
    }
}
