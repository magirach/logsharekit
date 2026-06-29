package com.company.logstreamer.audit.persistence;

import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Repository
public class InMemoryAuditRepository {
    private final List<AuditEntry> entries = new ArrayList<>();

    public synchronized void append(String sessionId, String actionType, String actor, Map<String, Object> details) {
        entries.add(new AuditEntry(UUID.randomUUID(), sessionId, actionType, actor, details, Instant.now()));
    }

    public synchronized List<AuditEntry> findAll() {
        return List.copyOf(entries);
    }

    public synchronized List<AuditEntry> findBySessionId(String sessionId) {
        return entries.stream()
                .filter(entry -> entry.sessionId().equals(sessionId))
                .toList();
    }
}
