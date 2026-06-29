package com.company.logstreamer.session.api;

import com.company.logstreamer.session.domain.ConsentStatus;
import com.company.logstreamer.session.domain.LogSession;
import com.company.logstreamer.session.domain.SessionStatus;
import com.company.logstreamer.session.domain.StopPolicy;

import java.time.Instant;
import java.util.List;

public record SessionResponse(
        String sessionId,
        String appId,
        String environment,
        String bundleIdentifier,
        String userId,
        List<String> logs,
        SessionStatus status,
        ConsentStatus consentStatus,
        StopPolicy stopPolicy,
        Integer retentionHours,
        Instant createdAt,
        Instant consentShownAt,
        Instant activatedAt,
        Instant endedAt,
        Instant lastClientActivityAt,
        Integer resendCount
) {
    public static SessionResponse from(LogSession session) {
        return new SessionResponse(
                session.getSessionId(),
                session.getAppId(),
                session.getEnvironment(),
                session.getBundleIdentifier(),
                session.getUserId(),
                session.getLogs(),
                session.getStatus(),
                session.getConsentStatus(),
                session.getStopPolicy(),
                session.getRetentionHours(),
                session.getCreatedAt(),
                session.getConsentShownAt(),
                session.getActivatedAt(),
                session.getEndedAt(),
                session.getLastClientActivityAt(),
                session.getResendCount()
        );
    }
}
