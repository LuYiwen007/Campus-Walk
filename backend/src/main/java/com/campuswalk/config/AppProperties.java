package com.campuswalk.config;

import lombok.Getter;
import lombok.Setter;
import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.Arrays;
import java.util.List;

@Getter
@Setter
@ConfigurationProperties(prefix = "app")
public class AppProperties {

    private String jwtSecret = "dev-change-on-server";
    private String jwtAlgorithm = "HS256";
    private long jwtExpireMinutes = 10080;
    /** 逗号分隔，与 Python CORS_ORIGINS 一致 */
    private String corsOrigins = "http://localhost:3000,http://127.0.0.1:3000";
    private boolean seedOnStartup = true;
    private int messageRetentionDays = 10;
    private boolean useMockLlm = true;
    private String dashscopeApiKey = "";

    public List<String> corsOriginList() {
        return Arrays.stream(corsOrigins.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toList();
    }
}
