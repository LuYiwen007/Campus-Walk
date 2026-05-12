package com.campuswalk.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

/**
 * 导航会话：进度仅存后端，客户端仅缓存当前会话 id 与展示用数据。
 */
@Getter
@Setter
@Entity
@Table(name = "navigation_sessions")
public class NavigationSession {

    public static final String STATUS_IN_PROGRESS = "IN_PROGRESS";
    public static final String STATUS_COMPLETED = "COMPLETED";
    public static final String STATUS_CANCELLED = "CANCELLED";

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "route_variant_id", nullable = false)
    private Long routeVariantId;

    /**
     * 当前步行段索引：第 k 段表示从途经点 k 到 k+1（0-based）。首段若需「先走到起点」由客户端在接近起点后仍报告为 0 直至开始 0→1。
     */
    @Column(name = "active_leg_index", nullable = false)
    private int activeLegIndex = 0;

    @Column(nullable = false, length = 32)
    private String status = STATUS_IN_PROGRESS;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt = Instant.now();
}
