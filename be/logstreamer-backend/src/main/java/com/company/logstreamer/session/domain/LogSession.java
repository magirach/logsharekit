package com.company.logstreamer.session.domain;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

public class LogSession {
    private final UUID id;
    private final String sessionId;
    private final String appId;
    private final String environment;
    private final String bundleIdentifier;
    private final String apnsToken;
    private final String deviceId;
    private final String installationId;
    private final String userId;
    private final List<String> logs;
    private final StopPolicy stopPolicy;
    private final int retentionHours;
    private final String createdBy;
    private String uploadTokenHash;
    private Instant uploadTokenExpiresAt;

    private SessionStatus status;
    private ConsentStatus consentStatus;
    private final Instant createdAt;
    private Instant consentShownAt;
    private Instant activatedAt;
    private Instant endedAt;
    private Instant lastClientActivityAt;
    private int resendCount;

    public LogSession(
            UUID id,
            String sessionId,
            String appId,
            String environment,
            String bundleIdentifier,
            String apnsToken,
            String deviceId,
            String installationId,
            String userId,
            List<String> logs,
            StopPolicy stopPolicy,
            int retentionHours,
            String createdBy,
            String uploadTokenHash,
            Instant uploadTokenExpiresAt
    ) {
        this.id = id;
        this.sessionId = sessionId;
        this.appId = appId;
        this.environment = environment;
        this.bundleIdentifier = bundleIdentifier;
        this.apnsToken = apnsToken;
        this.deviceId = deviceId;
        this.installationId = installationId;
        this.userId = userId;
        this.logs = List.copyOf(logs);
        this.stopPolicy = stopPolicy;
        this.retentionHours = retentionHours;
        this.createdBy = createdBy;
        this.uploadTokenHash = uploadTokenHash;
        this.uploadTokenExpiresAt = uploadTokenExpiresAt;
        this.status = SessionStatus.PENDING;
        this.consentStatus = ConsentStatus.UNKNOWN;
        this.createdAt = Instant.now();
    }

    public void markConsentShown(Instant shownAt) {
        if (isTerminal()) {
            return;
        }
        this.consentStatus = ConsentStatus.SHOWN;
        this.status = SessionStatus.CONSENT_REQUESTED;
        this.consentShownAt = shownAt;
    }

    public void markCancelled() {
        if (isTerminal()) {
            return;
        }
        this.consentStatus = ConsentStatus.DENIED;
        this.status = SessionStatus.CANCELLED;
        this.endedAt = Instant.now();
    }

    public void markActive(Instant activityAt) {
        if (isTerminal()) {
            return;
        }
        this.consentStatus = ConsentStatus.ACCEPTED;
        this.status = SessionStatus.ACTIVE;
        this.activatedAt = activatedAt == null ? activityAt : activatedAt;
        this.lastClientActivityAt = activityAt;
    }

    public void markCompleted() {
        if (isTerminal()) {
            return;
        }
        this.status = SessionStatus.COMPLETED;
        this.endedAt = Instant.now();
    }

    public void markExpired() {
        if (isTerminal()) {
            return;
        }
        this.status = SessionStatus.EXPIRED;
        this.endedAt = Instant.now();
    }

    public void markFailed() {
        if (isTerminal()) {
            return;
        }
        this.status = SessionStatus.FAILED;
        this.endedAt = Instant.now();
    }

    public void touch(Instant activityAt) {
        this.lastClientActivityAt = activityAt;
    }

    public void incrementResendCount() {
        this.resendCount += 1;
    }

    public void rotateUploadToken(String uploadTokenHash, Instant uploadTokenExpiresAt) {
        this.uploadTokenHash = uploadTokenHash;
        this.uploadTokenExpiresAt = uploadTokenExpiresAt;
    }

    public boolean isTerminal() {
        return status == SessionStatus.CANCELLED
                || status == SessionStatus.COMPLETED
                || status == SessionStatus.EXPIRED
                || status == SessionStatus.FAILED;
    }

    public Instant expiryTime() {
        return createdAt.plusSeconds((long) stopPolicy.safeExpiryMinutes() * 60);
    }

    public UUID getId() { return id; }
    public String getSessionId() { return sessionId; }
    public String getAppId() { return appId; }
    public String getEnvironment() { return environment; }
    public String getBundleIdentifier() { return bundleIdentifier; }
    public String getApnsToken() { return apnsToken; }
    public String getDeviceId() { return deviceId; }
    public String getInstallationId() { return installationId; }
    public String getUserId() { return userId; }
    public List<String> getLogs() { return logs; }
    public StopPolicy getStopPolicy() { return stopPolicy; }
    public int getRetentionHours() { return retentionHours; }
    public String getCreatedBy() { return createdBy; }
    public String getUploadTokenHash() { return uploadTokenHash; }
    public Instant getUploadTokenExpiresAt() { return uploadTokenExpiresAt; }
    public SessionStatus getStatus() { return status; }
    public ConsentStatus getConsentStatus() { return consentStatus; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getConsentShownAt() { return consentShownAt; }
    public Instant getActivatedAt() { return activatedAt; }
    public Instant getEndedAt() { return endedAt; }
    public Instant getLastClientActivityAt() { return lastClientActivityAt; }
    public int getResendCount() { return resendCount; }
}
