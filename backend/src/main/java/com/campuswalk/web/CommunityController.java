package com.campuswalk.web;

import com.campuswalk.entity.CommunityPost;
import com.campuswalk.repository.CommunityPostRepository;
import com.campuswalk.service.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class CommunityController {

    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_INSTANT;

    private final CurrentUserService currentUserService;
    private final CommunityPostRepository communityPostRepository;

    @GetMapping("/community/posts")
    public ApiResponse<List<Map<String, Object>>> listPosts() {
        currentUserService.requireCurrentUser();
        List<CommunityPost> rows = communityPostRepository.findAllByOrderByIdDesc(PageRequest.of(0, 50));
        return ApiResponse.ok(rows.stream().map(this::toVo).toList());
    }

    private Map<String, Object> toVo(CommunityPost p) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", p.getId());
        m.put("title", p.getTitle());
        m.put("body", p.getBody());
        m.put("cover_image_url", p.getCoverImageUrl());
        m.put("author_display_name", p.getAuthorDisplayName());
        m.put("author_avatar_url", p.getAuthorAvatarUrl());
        m.put("likes_count", p.getLikesCount());
        m.put("created_at", ISO.format(p.getCreatedAt()));
        return m;
    }
}
