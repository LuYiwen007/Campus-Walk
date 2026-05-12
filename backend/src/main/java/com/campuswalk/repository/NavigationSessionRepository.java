package com.campuswalk.repository;

import com.campuswalk.entity.NavigationSession;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NavigationSessionRepository extends JpaRepository<NavigationSession, Long> {

    List<NavigationSession> findByUserIdAndRouteVariantIdOrderByIdDesc(Long userId, Long routeVariantId);
}
