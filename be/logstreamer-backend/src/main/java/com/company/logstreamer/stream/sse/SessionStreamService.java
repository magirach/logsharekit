package com.company.logstreamer.stream.sse;

import com.company.logstreamer.ingest.domain.LogEventDocument;
import com.company.logstreamer.session.api.SessionResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

@Service
public class SessionStreamService {
    private static final Logger logger = LoggerFactory.getLogger(SessionStreamService.class);
    private final long timeoutMs;
    private final ConcurrentHashMap<String, CopyOnWriteArrayList<SseEmitter>> emittersBySession = new ConcurrentHashMap<>();

    public SessionStreamService(@Value("${logstreamer.sse.timeout-ms:1800000}") long timeoutMs) {
        this.timeoutMs = timeoutMs;
    }

    public SseEmitter subscribe(String sessionId) {
        var emitter = new SseEmitter(timeoutMs);
        addEmitter(sessionId, emitter);
        emitter.onCompletion(() -> remove(sessionId, emitter));
        emitter.onTimeout(() -> remove(sessionId, emitter));
        emitter.onError(ignored -> remove(sessionId, emitter));
        return emitter;
    }

    public void publishStatus(String sessionId, SessionResponse response) {
        publish(sessionId, "session_status", response);
    }

    public void publishLogEvents(String sessionId, List<LogEventDocument> events) {
        events.forEach(event -> publish(sessionId, "log_event", event));
    }

    public void publishHeartbeat(String sessionId) {
        publish(sessionId, "heartbeat", Map.of("sessionId", sessionId));
    }

    private void publish(String sessionId, String eventName, Object payload) {
        var emitters = emittersBySession.get(sessionId);
        if (emitters == null) {
            return;
        }
        emitters.forEach(emitter -> {
            try {
                emitter.send(SseEmitter.event().name(eventName).data(payload));
            } catch (Exception exception) {
                logger.debug("Dropping failed SSE emitter for session {} on event {}", sessionId, eventName, exception);
                remove(sessionId, emitter);
            }
        });
    }

    void addEmitter(String sessionId, SseEmitter emitter) {
        emittersBySession.computeIfAbsent(sessionId, ignored -> new CopyOnWriteArrayList<>()).add(emitter);
    }

    int emitterCount(String sessionId) {
        var emitters = emittersBySession.get(sessionId);
        return emitters == null ? 0 : emitters.size();
    }

    private void remove(String sessionId, SseEmitter emitter) {
        var emitters = emittersBySession.get(sessionId);
        if (emitters != null) {
            emitters.remove(emitter);
            if (emitters.isEmpty()) {
                emittersBySession.remove(sessionId, emitters);
            }
        }
    }
}
