package com.company.logstreamer.ingest.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.time.Instant;
import java.util.List;

public record EventBatchRequest(
        Instant sentAt,
        @NotEmpty List<@Valid IngestEventRequest> events
) {
}
