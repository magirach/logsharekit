package com.company.logstreamer.session.api;

import com.company.logstreamer.session.application.SessionCommandService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/sessions")
public class SessionController {
    private final SessionCommandService sessionCommandService;

    public SessionController(SessionCommandService sessionCommandService) {
        this.sessionCommandService = sessionCommandService;
    }

    @PostMapping
    public ResponseEntity<SessionCreateResponse> createSession(@Valid @RequestBody CreateSessionRequest request) {
        return ResponseEntity.ok(sessionCommandService.createSession(request));
    }

    @GetMapping
    public ResponseEntity<List<SessionResponse>> listSessions(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "false") boolean activeOnly
    ) {
        return ResponseEntity.ok(sessionCommandService.listSessions(status, activeOnly));
    }

    @GetMapping("/{sessionId}")
    public ResponseEntity<SessionResponse> getSession(@PathVariable String sessionId) {
        return ResponseEntity.ok(sessionCommandService.getSession(sessionId));
    }

    @PostMapping("/{sessionId}/stop")
    public ResponseEntity<SessionResponse> stopSession(@PathVariable String sessionId) {
        return ResponseEntity.ok(sessionCommandService.stopSession(sessionId));
    }

    @PostMapping("/{sessionId}/resend")
    public ResponseEntity<SessionResponse> resendPush(@PathVariable String sessionId) {
        return ResponseEntity.ok(sessionCommandService.resendPush(sessionId));
    }
}
