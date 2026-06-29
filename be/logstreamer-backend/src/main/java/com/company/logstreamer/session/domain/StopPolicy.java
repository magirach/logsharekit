package com.company.logstreamer.session.domain;

import com.fasterxml.jackson.annotation.JsonAlias;

public record StopPolicy(
        @JsonAlias("expiryMinutes")
        Integer expiresAfterMinutes,
        Integer maxEvents,
        Long maxBytes
) {
    public int safeExpiryMinutes() {
        return expiresAfterMinutes == null || expiresAfterMinutes <= 0 ? 15 : expiresAfterMinutes;
    }
}
