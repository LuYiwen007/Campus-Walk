package com.campuswalk.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Getter
@Setter
@Entity
@Table(name = "buildings")
public class Building {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 255)
    private String name;

    @Column(columnDefinition = "TEXT")
    private String description = "";

    private double latitude;

    private double longitude;

    @Column(length = 512)
    private String address = "";

    @Column(name = "cover_image_url", length = 1024)
    private String coverImageUrl = "";

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "gallery_urls", columnDefinition = "json")
    private List<String> galleryUrls = new ArrayList<>();

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "recognition_hint", columnDefinition = "json")
    private Map<String, Object> recognitionHint = new HashMap<>();

    @Column(name = "created_at")
    private Instant createdAt = Instant.now();

    @Column(name = "updated_at")
    private Instant updatedAt = Instant.now();
}
