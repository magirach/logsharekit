package com.company.logstreamer.debug.api;

import com.company.logstreamer.audit.persistence.AuditEntry;
import com.company.logstreamer.audit.persistence.InMemoryAuditRepository;
import com.company.logstreamer.common.ApiException;
import com.company.logstreamer.session.persistence.InMemorySessionRepository;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/v1/debug/sessions")
@ConditionalOnProperty(prefix = "logstreamer.debug", name = "enabled", havingValue = "true")
public class DebugSessionController {
    private final InMemoryAuditRepository auditRepository;
    private final InMemorySessionRepository sessionRepository;

    public DebugSessionController(
            InMemoryAuditRepository auditRepository,
            InMemorySessionRepository sessionRepository
    ) {
        this.auditRepository = auditRepository;
        this.sessionRepository = sessionRepository;
    }

    @GetMapping("/{sessionId}/upload-token")
    public ResponseEntity<LocalUploadTokenResponse> getUploadToken(@PathVariable String sessionId) {
        var session = sessionRepository.findBySessionId(sessionId)
                .orElseThrow(() -> new ApiException("SESSION_NOT_FOUND", "Session not found: " + sessionId, HttpStatus.NOT_FOUND));

        String token = extractLatestUploadToken(sessionId)
                .orElseThrow(() -> new ApiException(
                        "UPLOAD_TOKEN_NOT_FOUND",
                        "Upload token not available for session: " + sessionId,
                        HttpStatus.NOT_FOUND
                ));

        return ResponseEntity.ok(new LocalUploadTokenResponse(
                sessionId,
                token,
                session.getUploadTokenExpiresAt()
        ));
    }

    private Optional<String> extractLatestUploadToken(String sessionId) {
        var entries = auditRepository.findBySessionId(sessionId);
        for (int index = entries.size() - 1; index >= 0; index -= 1) {
            AuditEntry entry = entries.get(index);
            if (entry.actionType().equals("START_PUSH_SENT")) {
                Object data = entry.details().get("data");
                if (data instanceof Map<?, ?> dataMap) {
                    Object rawToken = dataMap.get("uploadToken");
                    if (rawToken instanceof String token && !token.isBlank()) {
                        return Optional.of(token);
                    }
                }
            }
            if (entry.actionType().equals("SESSION_CREATED")) {
                Object rawToken = entry.details().get("uploadToken");
                if (rawToken instanceof String token && !token.isBlank()) {
                    return Optional.of(token);
                }
            }
        }
        return Optional.empty();
    }
}
