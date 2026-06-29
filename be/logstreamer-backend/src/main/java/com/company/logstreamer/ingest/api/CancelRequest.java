package com.company.logstreamer.ingest.api;

import jakarta.validation.constraints.NotBlank;

import java.time.Instant;

public record CancelRequest(Instant cancelledAt, @NotBlank String reason) {
}
