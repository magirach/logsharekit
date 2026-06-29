package com.company.logstreamer.ingest.api;

import jakarta.validation.constraints.NotBlank;

import java.time.Instant;
import java.util.Map;

public record IngestEventRequest(
        @NotBlank String eventId,
        Instant timestamp,
        @NotBlank String type,
        String level,
        @NotBlank String component,
        String message,
        Map<String, String> metadata,
        Object payload
) {
}
