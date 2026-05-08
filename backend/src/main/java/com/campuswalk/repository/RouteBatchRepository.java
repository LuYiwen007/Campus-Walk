package com.campuswalk.repository;

import com.campuswalk.entity.RouteBatch;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface RouteBatchRepository extends JpaRepository<RouteBatch, Long> {
    List<RouteBatch> findByConversationIdOrderByIdDesc(Long conversationId);

    Optional<RouteBatch> findByAssistantMessageId(Long assistantMessageId);

    default Optional<RouteBatch> findLatestByConversationId(Long conversationId) {
        List<RouteBatch> list = findByConversationIdOrderByIdDesc(conversationId);
        return list.isEmpty() ? Optional.empty() : Optional.of(list.get(0));
    }

    @Modifying
    @Query("delete from RouteBatch b where b.createdAt < :cutoff")
    int deleteOlderThan(@Param("cutoff") Instant cutoff);
}
