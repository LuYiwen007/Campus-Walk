package com.campuswalk.repository;

import com.campuswalk.entity.ChatMessage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;

public interface ChatMessageRepository extends JpaRepository<ChatMessage, Long> {
    List<ChatMessage> findByConversationIdOrderBySentAtAscIdAsc(Long conversationId);

    @Modifying
    @Query("delete from ChatMessage m where m.sentAt < :cutoff")
    int deleteOlderThan(@Param("cutoff") Instant cutoff);
}
