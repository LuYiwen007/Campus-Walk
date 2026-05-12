package com.campuswalk.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.util.ArrayList;
import java.util.List;

@Getter
@Setter
@Entity
@Table(name = "route_variants", uniqueConstraints = {
        @UniqueConstraint(name = "ix_route_variants_batch_number", columnNames = {"batch_id", "route_number"})
})
public class RouteVariant {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "batch_id", nullable = false)
    private Long batchId;

    @Column(name = "route_number", nullable = false)
    private Integer routeNumber;

    @Column(name = "start_label", nullable = false, length = 255)
    private String startLabel;

    @Column(name = "end_label", nullable = false, length = 255)
    private String endLabel;

    @Column(name = "scenic_spot_count")
    private int scenicSpotCount = 0;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "scenic_spot_examples", columnDefinition = "json")
    private List<String> scenicSpotExamples = new ArrayList<>();

    @Column(name = "estimated_duration_seconds")
    private int estimatedDurationSeconds = 0;

    @Column(name = "estimated_distance_meters")
    private int estimatedDistanceMeters = 0;

    @Column(columnDefinition = "TEXT")
    private String description = "";

    /**
     * 有序途经点（起点 → 途经 → 终点），坐标由后端高德 Web 地理编码写入。
     */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "waypoints", columnDefinition = "json")
    private List<NavigationWaypoint> waypoints = new ArrayList<>();
}
