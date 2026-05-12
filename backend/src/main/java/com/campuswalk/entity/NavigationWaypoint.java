package com.campuswalk.entity;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/**
 * 分段导航途经点（持久化在 route_variants.waypoints JSON 中，由后端高德地理编码填充坐标）。
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class NavigationWaypoint {
    private int order;
    private String label;
    private Double latitude;
    private Double longitude;
}
