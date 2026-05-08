package com.campuswalk.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "community_posts")
public class CommunityPost {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 255)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String body = "";

    @Column(name = "cover_image_url", length = 1024)
    private String coverImageUrl = "";

    @Column(name = "author_display_name", length = 128)
    private String authorDisplayName = "";

    @Column(name = "author_avatar_url", length = 1024)
    private String authorAvatarUrl = "";

    @Column(name = "likes_count")
    private int likesCount = 0;

    @Column(name = "created_at")
    private Instant createdAt = Instant.now();
}
