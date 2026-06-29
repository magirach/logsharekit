package com.company.logstreamer.ingest.api;

public record EventBatchResponse(
        int accepted,
        int rejected,
        String status
) {
}
