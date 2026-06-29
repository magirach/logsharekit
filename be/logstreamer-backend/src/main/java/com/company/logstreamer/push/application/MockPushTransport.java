package com.company.logstreamer.push.application;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "logstreamer.push.apns", name = "enabled", havingValue = "false", matchIfMissing = true)
public class MockPushTransport implements PushTransport {
    @Override
    public PushTransportResult send(PushEnvelope envelope) {
        return new PushTransportResult("mock", true, 200, "mock-" + envelope.collapseId(), "Push recorded locally", null);
    }
}
