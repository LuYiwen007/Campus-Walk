package com.campuswalk.repository;

import com.campuswalk.entity.RouteVariant;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface RouteVariantRepository extends JpaRepository<RouteVariant, Long> {
    List<RouteVariant> findByBatchIdOrderByRouteNumber(Long batchId);
}
