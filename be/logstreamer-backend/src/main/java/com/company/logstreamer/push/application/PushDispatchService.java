package com.company.logstreamer.push.application;

import com.company.logstreamer.audit.persistence.InMemoryAuditRepository;
import com.company.logstreamer.common.ApiException;
import com.company.logstreamer.session.domain.LogSession;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class PushDispatchService {
    private final InMemoryAuditRepository auditRepository;
    private final PushTransport pushTransport;
    private final String uploadBaseUrl;

    public PushDispatchService(
            InMemoryAuditRepository auditRepository,
            PushTransport pushTransport,
            @Value("${logstreamer.session.upload-base-url:http://localhost:8080}") String uploadBaseUrl
    ) {
        this.auditRepository = auditRepository;
        this.pushTransport = pushTransport;
        this.uploadBaseUrl = uploadBaseUrl;
    }

    public Map<String, Object> sendStartPush(LogSession session, String uploadToken) {
        var data = new LinkedHashMap<String, Object>();
        data.put("command", "start_logging");
        data.put("sessionId", session.getSessionId());
        data.put("appId", session.getAppId());
        data.put("environment", session.getEnvironment());
        data.put("userId", session.getUserId());
        data.put("logs", session.getLogs());
        data.put("stopPolicy", session.getStopPolicy());
        data.put("retentionHours", session.getRetentionHours());
        data.put("uploadToken", uploadToken);
        data.put("baseUrl", uploadBaseUrl);

        var pushRequest = new LinkedHashMap<String, Object>();
        pushRequest.put("bundleIdentifier", session.getBundleIdentifier());
        pushRequest.put("apnsToken", session.getApnsToken());
        pushRequest.put("aps", Map.of("content-available", 1));
        pushRequest.put("data", data);
        PushTransportResult result = pushTransport.send(new PushEnvelope(
                session.getApnsToken(),
                session.getBundleIdentifier(),
                Map.of(
                        "aps", Map.of("content-available", 1),
                        "data", data
                ),
                "background",
                session.getSessionId()
        ));
        var auditDetails = withTransportMetadata(pushRequest, result);
        auditRepository.append(session.getSessionId(), "START_PUSH_SENT", "system", auditDetails);
        ensureAccepted(result, session.getSessionId(), "start");
        return auditDetails;
    }

    public Map<String, Object> sendStopPush(LogSession session) {
        var data = Map.<String, Object>of(
                "command", "stop_logging",
                "sessionId", session.getSessionId()
        );
        var pushRequest = new LinkedHashMap<String, Object>();
        pushRequest.put("bundleIdentifier", session.getBundleIdentifier());
        pushRequest.put("apnsToken", session.getApnsToken());
        pushRequest.put("aps", Map.of("content-available", 1));
        pushRequest.put("data", data);
        PushTransportResult result = pushTransport.send(new PushEnvelope(
                session.getApnsToken(),
                session.getBundleIdentifier(),
                Map.of(
                        "aps", Map.of("content-available", 1),
                        "data", data
                ),
                "background",
                session.getSessionId()
        ));
        var auditDetails = withTransportMetadata(pushRequest, result);
        auditRepository.append(session.getSessionId(), "STOP_PUSH_SENT", "system", auditDetails);
        ensureAccepted(result, session.getSessionId(), "stop");
        return auditDetails;
    }

    private Map<String, Object> withTransportMetadata(Map<String, Object> request, PushTransportResult result) {
        var details = new LinkedHashMap<String, Object>(request);
        details.put("provider", result.provider());
        details.put("accepted", result.accepted());
        details.put("statusCode", result.statusCode());
        details.put("apnsId", result.apnsId());
        details.put("responseBody", result.responseBody());
        if (result.simulatorFilePath() != null) {
            details.put("simulatorFilePath", result.simulatorFilePath());
        }
        return details;
    }

    private void ensureAccepted(PushTransportResult result, String sessionId, String command) {
        if (!result.accepted()) {
            throw new ApiException(
                    "APNS_SEND_FAILED",
                    "APNs rejected " + command + " push for session " + sessionId + " with status " + result.statusCode(),
                    HttpStatus.BAD_GATEWAY
            );
        }
    }
}
