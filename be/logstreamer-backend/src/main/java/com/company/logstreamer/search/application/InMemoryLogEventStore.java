package com.company.logstreamer.search.application;

import com.company.logstreamer.ingest.domain.LogEventDocument;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

@Component
public class InMemoryLogEventStore {
    private final ConcurrentHashMap<String, CopyOnWriteArrayList<LogEventDocument>> eventsBySession = new ConcurrentHashMap<>();

    public void append(String sessionId, List<LogEventDocument> events) {
        eventsBySession.computeIfAbsent(sessionId, ignored -> new CopyOnWriteArrayList<>()).addAll(events);
    }

    public List<LogEventDocument> findBySessionId(String sessionId, Instant from, Instant to, Integer limit) {
        return eventsBySession.getOrDefault(sessionId, new CopyOnWriteArrayList<LogEventDocument>())
                .stream()
                .filter(event -> from == null || !event.timestamp().isBefore(from))
                .filter(event -> to == null || !event.timestamp().isAfter(to))
                .sorted(Comparator.comparing(LogEventDocument::timestamp))
                .limit(limit == null ? 500 : limit)
                .toList();
    }

    public void purgeOlderThan(Instant threshold) {
        eventsBySession.replaceAll((sessionId, events) -> {
            CopyOnWriteArrayList<LogEventDocument> filtered = new CopyOnWriteArrayList<>();
            events.stream()
                    .filter(event -> !event.ingestedAt().isBefore(threshold))
                    .forEach(filtered::add);
            return filtered;
        });
    }
}
