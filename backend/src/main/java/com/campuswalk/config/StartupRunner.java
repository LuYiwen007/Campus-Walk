package com.campuswalk.config;

import com.campuswalk.service.PurgeService;
import com.campuswalk.service.SeedService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@Order(1)
@RequiredArgsConstructor
public class StartupRunner implements ApplicationRunner {

    private final PurgeService purgeService;
    private final SeedService seedService;

    @Override
    public void run(ApplicationArguments args) {
        try {
            purgeService.purgeExpired();
        } catch (Exception e) {
            log.error("startup purge failed", e);
            throw e;
        }
        try {
            seedService.seedIfNeeded();
        } catch (Exception e) {
            log.error("startup seed failed", e);
            throw e;
        }
    }
}
