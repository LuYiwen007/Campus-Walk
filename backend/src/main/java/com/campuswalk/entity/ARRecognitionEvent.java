package com.campuswalk.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

@Getter
@Setter
@Entity
@Table(name = "ar_recognition_events")
public class ARRecognitionEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "session_id", nullable = false)
    private Long sessionId;

    @Column(name = "building_id")
    private Long buildingId;

    private double confidence = 0.0;

    @Column(name = "client_lat")
    private double clientLat = 0.0;

    @Column(name = "client_lon")
    private double clientLon = 0.0;

    @Column(name = "client_heading")
    private double clientHeading = 0.0;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "raw_response", columnDefinition = "json")
    private Map<String, Object> rawResponse = new HashMap<>();

    @Column(name = "created_at")
    private Instant createdAt = Instant.now();
}
