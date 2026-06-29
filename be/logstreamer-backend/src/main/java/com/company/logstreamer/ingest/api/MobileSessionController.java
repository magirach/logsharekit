package com.company.logstreamer.ingest.api;

import com.company.logstreamer.config.TokenService;
import com.company.logstreamer.ingest.application.EventIngestionService;
import com.company.logstreamer.session.application.SessionCommandService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/mobile/sessions/{sessionId}")
public class MobileSessionController {
    private final SessionCommandService sessionCommandService;
    private final EventIngestionService eventIngestionService;
    private final TokenService tokenService;

    public MobileSessionController(
            SessionCommandService sessionCommandService,
            EventIngestionService eventIngestionService,
            TokenService tokenService
    ) {
        this.sessionCommandService = sessionCommandService;
        this.eventIngestionService = eventIngestionService;
        this.tokenService = tokenService;
    }

    @PostMapping("/consent-shown")
    public ResponseEntity<Void> consentShown(
            @PathVariable String sessionId,
            @RequestHeader("Authorization") String authorization,
            @RequestBody ConsentShownRequest request
    ) {
        sessionCommandService.validateUploadToken(sessionId, tokenService.extractBearerToken(authorization));
        sessionCommandService.markConsentShown(sessionId, request.shownAt());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/cancel")
    public ResponseEntity<Void> cancel(
            @PathVariable String sessionId,
            @RequestHeader("Authorization") String authorization,
            @Valid @RequestBody CancelRequest request
    ) {
        sessionCommandService.validateUploadToken(sessionId, tokenService.extractBearerToken(authorization));
        sessionCommandService.markCancelled(sessionId, request.reason());
        return ResponseEntity.ok().build();
    }

    @PostMapping("/events")
    public ResponseEntity<EventBatchResponse> uploadEvents(
            @PathVariable String sessionId,
            @RequestHeader("Authorization") String authorization,
            @Valid @RequestBody EventBatchRequest request
    ) {
        sessionCommandService.validateUploadToken(sessionId, tokenService.extractBearerToken(authorization));
        return ResponseEntity.ok(eventIngestionService.ingest(sessionId, request));
    }
}
