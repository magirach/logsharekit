package com.company.logstreamer.session.application;

import com.company.logstreamer.audit.persistence.InMemoryAuditRepository;
import com.company.logstreamer.common.ApiException;
import com.company.logstreamer.config.TokenService;
import com.company.logstreamer.push.application.PushDispatchService;
import com.company.logstreamer.session.api.CreateSessionRequest;
import com.company.logstreamer.session.api.SessionCreateResponse;
import com.company.logstreamer.session.api.SessionResponse;
import com.company.logstreamer.session.domain.LogSession;
import com.company.logstreamer.session.domain.RequestedLogTypes;
import com.company.logstreamer.session.domain.SessionStatus;
import com.company.logstreamer.session.domain.StopPolicy;
import com.company.logstreamer.session.persistence.InMemorySessionRepository;
import com.company.logstreamer.stream.sse.SessionStreamService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class SessionCommandService {
    private final InMemorySessionRepository sessionRepository;
    private final InMemoryAuditRepository auditRepository;
    private final PushDispatchService pushDispatchService;
    private final TokenService tokenService;
    private final SessionStreamService streamService;
    private final int defaultRetentionHours;

    public SessionCommandService(
            InMemorySessionRepository sessionRepository,
            InMemoryAuditRepository auditRepository,
            PushDispatchService pushDispatchService,
            TokenService tokenService,
            SessionStreamService streamService,
            @Value("${logstreamer.session.default-retention-hours:24}") int defaultRetentionHours
    ) {
        this.sessionRepository = sessionRepository;
        this.auditRepository = auditRepository;
        this.pushDispatchService = pushDispatchService;
        this.tokenService = tokenService;
        this.streamService = streamService;
        this.defaultRetentionHours = defaultRetentionHours;
    }

    public SessionCreateResponse createSession(CreateSessionRequest request) {
        String sessionId = "sess_" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        String uploadToken = tokenService.generateOpaqueToken();
        StopPolicy stopPolicy = request.stopPolicy();
        List<String> requestedLogs = RequestedLogTypes.normalize(request.logs());
        LogSession session = new LogSession(
                UUID.randomUUID(),
                sessionId,
                request.appId(),
                request.environment(),
                request.bundleIdentifier(),
                request.apnsToken(),
                null,
                null,
                request.userId(),
                requestedLogs,
                stopPolicy,
                request.retentionHours(),
                "operator",
                tokenService.hash(uploadToken),
                Instant.now().plusSeconds((long) stopPolicy.safeExpiryMinutes() * 60)
        );
        sessionRepository.save(session);
        Map<String, Object> auditDetails = new LinkedHashMap<>();
        auditDetails.put("appId", request.appId());
        auditDetails.put("environment", request.environment());
        auditDetails.put("bundleIdentifier", request.bundleIdentifier());
        auditDetails.put("apnsToken", request.apnsToken());
        auditDetails.put("userId", request.userId());
        auditDetails.put("logs", requestedLogs);
        auditDetails.put("stopPolicy", stopPolicy);
        auditDetails.put("retentionHours", request.retentionHours());
        auditDetails.put("uploadToken", uploadToken);
        if (request.logPath() != null) {
            auditDetails.put("logPath", request.logPath());
        }
        auditRepository.append(sessionId, "SESSION_CREATED", "operator", auditDetails);
        try {
            pushDispatchService.sendStartPush(session, uploadToken);
        } catch (RuntimeException exception) {
            session.markFailed();
            sessionRepository.save(session);
            Map<String, Object> failureDetails = new LinkedHashMap<>();
            failureDetails.put("reason", exception.getMessage());
            auditRepository.append(sessionId, "SESSION_FAILED", "system", failureDetails);
            streamService.publishStatus(sessionId, SessionResponse.from(session));
            throw exception;
        }
        streamService.publishStatus(sessionId, SessionResponse.from(session));
        return new SessionCreateResponse(sessionId, session.getStatus(), session.getCreatedAt());
    }

    public SessionResponse getSession(String sessionId) {
        return SessionResponse.from(requireSession(sessionId));
    }

    public List<SessionResponse> listSessions(String status, boolean activeOnly) {
        return sessionRepository.findAll().stream()
                .filter(session -> !activeOnly || session.getStatus() == SessionStatus.ACTIVE)
                .filter(session -> status == null || session.getStatus().name().equalsIgnoreCase(status))
                .map(SessionResponse::from)
                .toList();
    }

    public SessionResponse stopSession(String sessionId) {
        LogSession session = requireSession(sessionId);
        pushDispatchService.sendStopPush(session);
        session.markCompleted();
        auditRepository.append(sessionId, "SESSION_STOPPED", "operator", Map.of("source", "manual"));
        sessionRepository.save(session);
        SessionResponse response = SessionResponse.from(session);
        streamService.publishStatus(sessionId, response);
        return response;
    }

    public SessionResponse resendPush(String sessionId) {
        LogSession session = requireSession(sessionId);
        if (session.isTerminal()) {
            throw new ApiException("SESSION_ALREADY_TERMINAL", "Cannot resend a terminal session", HttpStatus.CONFLICT);
        }
        session.incrementResendCount();
        if (session.getStatus() == SessionStatus.ACTIVE || session.getStatus() == SessionStatus.PAUSED) {
            pushDispatchService.sendStopPush(session);
        } else {
            String uploadToken = tokenService.generateOpaqueToken();
            session.rotateUploadToken(
                    tokenService.hash(uploadToken),
                    Instant.now().plusSeconds((long) session.getStopPolicy().safeExpiryMinutes() * 60)
            );
            pushDispatchService.sendStartPush(session, uploadToken);
        }
        auditRepository.append(sessionId, "PUSH_RESENT", "operator", Map.of("status", session.getStatus().name()));
        sessionRepository.save(session);
        SessionResponse response = SessionResponse.from(session);
        streamService.publishStatus(sessionId, response);
        return response;
    }

    public LogSession markConsentShown(String sessionId, Instant shownAt) {
        LogSession session = requireSession(sessionId);
        session.markConsentShown(shownAt == null ? Instant.now() : shownAt);
        auditRepository.append(sessionId, "CONSENT_SHOWN", "mobile", Map.of("shownAt", session.getConsentShownAt()));
        sessionRepository.save(session);
        streamService.publishStatus(sessionId, SessionResponse.from(session));
        return session;
    }

    public LogSession markCancelled(String sessionId, String reason) {
        LogSession session = requireSession(sessionId);
        session.markCancelled();
        auditRepository.append(sessionId, "SESSION_CANCELLED", "mobile", Map.of("reason", reason));
        sessionRepository.save(session);
        streamService.publishStatus(sessionId, SessionResponse.from(session));
        return session;
    }

    public LogSession markActiveAndTouch(String sessionId, Instant activityAt) {
        LogSession session = requireSession(sessionId);
        session.markActive(activityAt);
        sessionRepository.save(session);
        streamService.publishStatus(sessionId, SessionResponse.from(session));
        return session;
    }

    public LogSession touch(String sessionId, Instant activityAt) {
        LogSession session = requireSession(sessionId);
        session.touch(activityAt);
        sessionRepository.save(session);
        return session;
    }

    public LogSession validateUploadToken(String sessionId, String rawToken) {
        LogSession session = requireSession(sessionId);
        if (session.getUploadTokenExpiresAt().isBefore(Instant.now())) {
            throw new ApiException("INVALID_UPLOAD_TOKEN", "Upload token expired", HttpStatus.UNAUTHORIZED);
        }
        if (!session.getUploadTokenHash().equals(tokenService.hash(rawToken))) {
            throw new ApiException("INVALID_UPLOAD_TOKEN", "Upload token mismatch", HttpStatus.UNAUTHORIZED);
        }
        return session;
    }

    @Scheduled(fixedDelayString = "${logstreamer.session.expiry-check-ms:60000}")
    public void expireSessions() {
        sessionRepository.findAll().stream()
                .filter(session -> !session.isTerminal())
                .filter(session -> !session.expiryTime().isAfter(Instant.now()))
                .forEach(session -> {
                    session.markExpired();
                    sessionRepository.save(session);
                    auditRepository.append(session.getSessionId(), "SESSION_EXPIRED", "system", Map.of());
                    streamService.publishStatus(session.getSessionId(), SessionResponse.from(session));
                });
    }

    private LogSession requireSession(String sessionId) {
        return sessionRepository.findBySessionId(sessionId)
                .orElseThrow(() -> new ApiException("SESSION_NOT_FOUND", "Session not found: " + sessionId, HttpStatus.NOT_FOUND));
    }
}
