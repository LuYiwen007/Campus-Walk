package com.campuswalk.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@Entity
@Table(name = "route_batches")
public class RouteBatch {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "conversation_id", nullable = false)
    private Long conversationId;

    @Column(name = "user_message_id")
    private Long userMessageId;

    @Column(name = "assistant_message_id")
    private Long assistantMessageId;

    @Column(name = "created_at")
    private Instant createdAt = Instant.now();
}
