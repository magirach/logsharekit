package com.company.logstreamer.ingest.application;

import com.company.logstreamer.ingest.api.EventBatchRequest;
import com.company.logstreamer.ingest.api.EventBatchResponse;
import com.company.logstreamer.ingest.api.IngestEventRequest;
import com.company.logstreamer.ingest.domain.LogEventDocument;
import com.company.logstreamer.search.application.InMemoryLogEventStore;
import com.company.logstreamer.session.domain.LogSession;
import com.company.logstreamer.session.domain.SessionStatus;
import com.company.logstreamer.session.application.SessionCommandService;
import com.company.logstreamer.stream.sse.SessionStreamService;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

@Service
public class EventIngestionService {
    private final SessionCommandService sessionCommandService;
    private final InMemoryLogEventStore logEventStore;
    private final SessionStreamService streamService;

    public EventIngestionService(
            SessionCommandService sessionCommandService,
            InMemoryLogEventStore logEventStore,
            SessionStreamService streamService
    ) {
        this.sessionCommandService = sessionCommandService;
        this.logEventStore = logEventStore;
        this.streamService = streamService;
    }

    public EventBatchResponse ingest(String sessionId, EventBatchRequest request) {
        LogSession session = sessionCommandService.markActiveAndTouch(sessionId, Instant.now());
        if (session.getStatus() == SessionStatus.COMPLETED || session.getStatus() == SessionStatus.CANCELLED || session.getStatus() == SessionStatus.EXPIRED) {
            return new EventBatchResponse(0, request.events().size(), session.getStatus().name());
        }

        List<LogEventDocument> documents = request.events().stream()
                .map(event -> toDocument(session, event))
                .toList();
        logEventStore.append(sessionId, documents);
        streamService.publishLogEvents(sessionId, documents);
        streamService.publishHeartbeat(sessionId);
        return new EventBatchResponse(documents.size(), 0, session.getStatus().name());
    }

    private LogEventDocument toDocument(LogSession session, IngestEventRequest event) {
        return new LogEventDocument(
                event.eventId(),
                session.getSessionId(),
                session.getAppId(),
                event.timestamp() == null ? Instant.now() : event.timestamp(),
                Instant.now(),
                event.type(),
                event.level(),
                event.component(),
                event.message(),
                event.metadata() == null ? java.util.Map.of() : event.metadata(),
                event.payload()
        );
    }
}
