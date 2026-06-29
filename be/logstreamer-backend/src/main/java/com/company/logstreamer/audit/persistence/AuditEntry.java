package com.company.logstreamer.audit.persistence;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

public record AuditEntry(
        UUID id,
        String sessionId,
        String actionType,
        String actor,
        Map<String, Object> details,
        Instant createdAt
) {
}
