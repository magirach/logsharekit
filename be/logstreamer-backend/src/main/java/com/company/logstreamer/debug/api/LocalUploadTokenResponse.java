package com.company.logstreamer.debug.api;

import java.time.Instant;

public record LocalUploadTokenResponse(
        String sessionId,
        String uploadToken,
        Instant expiresAt
) {
}
