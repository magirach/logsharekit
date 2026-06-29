package com.company.logstreamer.search.api;

import com.company.logstreamer.search.application.InMemoryLogEventStore;
import com.company.logstreamer.stream.sse.SessionStreamService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import java.time.Instant;

@RestController
@RequestMapping("/api/v1/sessions/{sessionId}")
public class SessionSearchController {
    private final InMemoryLogEventStore logEventStore;
    private final SessionStreamService streamService;

    public SessionSearchController(InMemoryLogEventStore logEventStore, SessionStreamService streamService) {
        this.logEventStore = logEventStore;
        this.streamService = streamService;
    }

    @GetMapping("/logs")
    public ResponseEntity<?> getLogs(
            @PathVariable String sessionId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(required = false) Integer limit
    ) {
        return ResponseEntity.ok(logEventStore.findBySessionId(sessionId, from, to, limit));
    }

    @GetMapping(path = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter stream(@PathVariable String sessionId) {
        return streamService.subscribe(sessionId);
    }
}
