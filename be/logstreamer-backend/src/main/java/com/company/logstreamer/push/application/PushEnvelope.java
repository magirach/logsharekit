package com.company.logstreamer.push.application;

import java.util.Map;

public record PushEnvelope(
        String deviceToken,
        String topic,
        Map<String, Object> payload,
        String pushType,
        String collapseId
) {
}
