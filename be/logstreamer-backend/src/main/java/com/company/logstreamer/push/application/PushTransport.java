package com.company.logstreamer.push.application;

public interface PushTransport {
    PushTransportResult send(PushEnvelope envelope);
}
