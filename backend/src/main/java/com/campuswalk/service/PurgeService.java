package com.campuswalk.service;

import com.campuswalk.config.AppProperties;
import com.campuswalk.repository.ChatMessageRepository;
import com.campuswalk.repository.RouteBatchRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class PurgeService {

    private final AppProperties appProperties;
    private final RouteBatchRepository routeBatchRepository;
    private final ChatMessageRepository chatMessageRepository;

    @Transactional
    public void purgeExpired() {
        Instant cutoff = Instant.now().minus(appProperties.getMessageRetentionDays(), ChronoUnit.DAYS);
        int rb = routeBatchRepository.deleteOlderThan(cutoff);
        int qm = chatMessageRepository.deleteOlderThan(cutoff);
        log.info("purge: route_batches={} chat_messages={} cutoff={}", rb, qm, cutoff);
    }
}
