package com.company.logstreamer.push.application;

public record PushTransportResult(
        String provider,
        boolean accepted,
        int statusCode,
        String apnsId,
        String responseBody,
        String simulatorFilePath
) {
}
