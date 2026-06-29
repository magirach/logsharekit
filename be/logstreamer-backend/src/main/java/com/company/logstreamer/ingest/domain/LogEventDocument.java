package com.company.logstreamer.ingest.domain;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.Instant;
import java.util.Map;

public record LogEventDocument(
        String eventId,
        String sessionId,
        String appId,
        Instant timestamp,
        Instant ingestedAt,
        @JsonProperty("type")
        String eventType,
        String level,
        String component,
        String message,
        Map<String, String> metadata,
        Object payload
) {
}
