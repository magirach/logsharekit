package com.company.logstreamer.stream.sse;

import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThat;

class SessionStreamServiceTest {

    @Test
    void publishHeartbeatDropsBrokenEmitterWithoutFailingCaller() {
        SessionStreamService service = new SessionStreamService(1_000L);
        service.addEmitter("sess_1", new BrokenEmitter());

        assertThatCode(() -> service.publishHeartbeat("sess_1"))
                .doesNotThrowAnyException();
        assertThat(service.emitterCount("sess_1")).isZero();
    }

    private static final class BrokenEmitter extends SseEmitter {
        BrokenEmitter() {
            super(1_000L);
        }

        @Override
        public synchronized void send(SseEventBuilder builder) {
            throw new IllegalStateException("async context already failed");
        }
    }
}
