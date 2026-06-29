package com.company.logstreamer.session.api;

import com.company.logstreamer.session.domain.SessionStatus;

import java.time.Instant;

public record SessionCreateResponse(
        String sessionId,
        SessionStatus status,
        Instant createdAt
) {
}
