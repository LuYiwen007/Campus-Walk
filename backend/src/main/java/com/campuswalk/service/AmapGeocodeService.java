package com.campuswalk.service;

import com.campuswalk.config.AppProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Optional;

/**
 * 高德 Web 地理编码（服务端），用于将途经点地名转为经纬度并持久化。
 * 文档：https://lbs.amap.com/api/webservice/guide/api/georegeo
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AmapGeocodeService {

    private static final HttpClient HTTP = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    private final AppProperties appProperties;
    private final ObjectMapper objectMapper;

    public record LatLng(double latitude, double longitude) {}

    /**
     * @param address 地点名称（可与城市组合）
     */
    public Optional<LatLng> geocode(String address) {
        String key = appProperties.getAmapRestKey();
        if (key == null || key.isBlank()) {
            log.debug("amap: AMAP_REST_KEY 未配置，跳过地理编码");
            return Optional.empty();
        }
        String city = appProperties.getAmapGeocodeCity() != null ? appProperties.getAmapGeocodeCity().strip() : "";
        String q = address != null ? address.strip() : "";
        if (q.isEmpty()) {
            return Optional.empty();
        }
        try {
            String addrParam = URLEncoder.encode(q, StandardCharsets.UTF_8);
            String cityParam = URLEncoder.encode(city, StandardCharsets.UTF_8);
            String url = "https://restapi.amap.com/v3/geocode/geo?key=" + URLEncoder.encode(key.strip(), StandardCharsets.UTF_8)
                    + "&address=" + addrParam
                    + "&city=" + cityParam;
            HttpRequest req = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(15))
                    .GET()
                    .build();
            HttpResponse<String> resp = HTTP.send(req, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            if (resp.statusCode() != 200) {
                log.warn("amap geocode HTTP {} for {}", resp.statusCode(), q);
                return Optional.empty();
            }
            JsonNode root = objectMapper.readTree(resp.body());
            if (!"1".equals(root.path("status").asText())) {
                log.warn("amap geocode status!=1 for {}: {}", q, truncate(resp.body(), 300));
                return Optional.empty();
            }
            JsonNode codes = root.path("geocodes");
            if (!codes.isArray() || codes.isEmpty()) {
                return Optional.empty();
            }
            String loc = codes.get(0).path("location").asText(null);
            if (loc == null || loc.isBlank()) {
                return Optional.empty();
            }
            String[] parts = loc.split(",");
            if (parts.length != 2) {
                return Optional.empty();
            }
            double lng = Double.parseDouble(parts[0].trim());
            double lat = Double.parseDouble(parts[1].trim());
            return Optional.of(new LatLng(lat, lng));
        } catch (Exception e) {
            log.warn("amap geocode failed for {}: {}", q, e.getMessage());
            return Optional.empty();
        }
    }

    private static String truncate(String s, int max) {
        if (s == null) {
            return "";
        }
        return s.length() <= max ? s : s.substring(0, max) + "...";
    }
}
