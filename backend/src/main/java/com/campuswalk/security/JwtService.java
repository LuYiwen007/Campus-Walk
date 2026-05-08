package com.campuswalk.security;

import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.campuswalk.config.AppProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;

@Service
@RequiredArgsConstructor
public class JwtService {

    private final AppProperties appProperties;

    public String createAccessToken(long userId) {
        Instant exp = Instant.now().plus(appProperties.getJwtExpireMinutes(), ChronoUnit.MINUTES);
        Algorithm algorithm = Algorithm.HMAC256(appProperties.getJwtSecret());
        return JWT.create()
                .withSubject(String.valueOf(userId))
                .withExpiresAt(Date.from(exp))
                .sign(algorithm);
    }

    public Long parseUserId(String token) {
        try {
            Algorithm algorithm = Algorithm.HMAC256(appProperties.getJwtSecret());
            JWTVerifier verifier = JWT.require(algorithm).build();
            DecodedJWT jwt = verifier.verify(token);
            String sub = jwt.getSubject();
            if (sub == null) {
                return null;
            }
            return Long.parseLong(sub);
        } catch (JWTVerificationException | NumberFormatException e) {
            return null;
        }
    }
}
