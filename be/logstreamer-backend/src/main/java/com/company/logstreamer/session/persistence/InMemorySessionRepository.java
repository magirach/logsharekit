package com.company.logstreamer.session.persistence;

import com.company.logstreamer.session.domain.LogSession;
import com.company.logstreamer.session.domain.SessionStatus;
import org.springframework.stereotype.Repository;

import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

@Repository
public class InMemorySessionRepository {
    private final ConcurrentHashMap<String, LogSession> sessions = new ConcurrentHashMap<>();

    public LogSession save(LogSession session) {
        sessions.put(session.getSessionId(), session);
        return session;
    }

    public Optional<LogSession> findBySessionId(String sessionId) {
        return Optional.ofNullable(sessions.get(sessionId));
    }

    public List<LogSession> findAll() {
        return sessions.values().stream()
                .sorted(Comparator.comparing(LogSession::getCreatedAt).reversed())
                .toList();
    }

    public List<LogSession> findByStatus(SessionStatus status) {
        return findAll().stream().filter(session -> session.getStatus() == status).toList();
    }
}
