package com.company.logstreamer.push.application;

import com.company.logstreamer.common.ApiException;
import com.company.logstreamer.push.config.ApnsProperties;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;

@Component
@ConditionalOnProperty(prefix = "logstreamer.push.apns", name = "enabled", havingValue = "true")
public class AppleApnsPushTransport implements PushTransport {
    private static final Logger logger = LoggerFactory.getLogger(AppleApnsPushTransport.class);
    private final ApnsProperties properties;
    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final PrivateKey privateKey;

    private volatile String cachedJwt;
    private volatile Instant cachedJwtExpiresAt = Instant.EPOCH;

    public AppleApnsPushTransport(ApnsProperties properties, ObjectMapper objectMapper) {
        this.properties = properties;
        this.objectMapper = objectMapper;
        if (properties.isSendEnabled()) {
            validateProperties(properties);
            this.httpClient = HttpClient.newBuilder()
                    .version(HttpClient.Version.HTTP_2)
                    .connectTimeout(Duration.ofMillis(properties.getConnectTimeoutMs()))
                    .build();
            this.privateKey = loadPrivateKey(properties.getPrivateKeyPath());
        } else {
            this.httpClient = null;
            this.privateKey = null;
        }
    }

    @Override
    public PushTransportResult send(PushEnvelope envelope) {
        try {
            String payloadJson = objectMapper.writeValueAsString(envelope.payload());
            logger.info("APNs payload for device {}: {}", envelope.deviceToken(), payloadJson);
            if (!properties.isSendEnabled()) {
                Path simulatorFile = writeSimulatorPayload(envelope);
                logger.info("APNs send disabled; wrote simulator payload for device {} to {}", envelope.deviceToken(), simulatorFile);
                return new PushTransportResult(
                        "apns",
                        true,
                        202,
                        null,
                        "APNs delivery skipped by configuration",
                        simulatorFile.toString()
                );
            }
            HttpRequest.Builder requestBuilder = HttpRequest.newBuilder()
                    .uri(URI.create(properties.getBaseUrl() + "/3/device/" + envelope.deviceToken()))
                    .timeout(Duration.ofMillis(properties.getConnectTimeoutMs()))
                    .header("authorization", "bearer " + jwt())
                    .header("apns-topic", topicFor(envelope))
                    .header("apns-push-type", envelope.pushType())
                    .header("apns-priority", "5")
                    .header("content-type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(payloadJson, StandardCharsets.UTF_8));
            if (envelope.collapseId() != null && !envelope.collapseId().isBlank()) {
                requestBuilder.header("apns-collapse-id", envelope.collapseId());
            }
            HttpResponse<String> response = httpClient.send(requestBuilder.build(), HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            String apnsId = response.headers().firstValue("apns-id").orElse(null);
            return new PushTransportResult("apns", response.statusCode() == 200, response.statusCode(), apnsId, response.body(), null);
        } catch (JsonProcessingException exception) {
            throw new ApiException("APNS_PAYLOAD_SERIALIZATION_FAILED", exception.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        } catch (IOException exception) {
            throw new ApiException("APNS_IO_FAILED", exception.getMessage(), HttpStatus.BAD_GATEWAY);
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new ApiException("APNS_INTERRUPTED", exception.getMessage(), HttpStatus.BAD_GATEWAY);
        }
    }

    private Path writeSimulatorPayload(PushEnvelope envelope) throws IOException {
        Path outputDirectory = Path.of(properties.getSimulatorOutputDir()).toAbsolutePath().normalize();
        Files.createDirectories(outputDirectory);

        String command = commandName(envelope);
        String sessionId = sessionId(envelope);
        Path outputFile = outputDirectory.resolve(command + "-" + sessionId + ".apns");

        Map<String, Object> simulatorPayload = simulatorPayload(envelope);
        Files.writeString(
                outputFile,
                objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(simulatorPayload),
                StandardCharsets.UTF_8
        );
        return outputFile;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> simulatorPayload(PushEnvelope envelope) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("Simulator Target Bundle", topicFor(envelope));
        payload.put("aps", Map.of(
                "alert", Map.of(
                        "title", "Test Notification",
                        "body", "Hello from the simulator!"
                )
        ));
        payload.put("sound", "default");
        payload.put("badge", 1);
        payload.put("data", envelope.payload().get("data"));
        return payload;
    }

    @SuppressWarnings("unchecked")
    private String commandName(PushEnvelope envelope) {
        Object data = envelope.payload().get("data");
        if (data instanceof Map<?, ?> dataMap) {
            Object command = dataMap.get("command");
            if (command instanceof String commandValue && !commandValue.isBlank()) {
                return switch (commandValue) {
                    case "start_logging" -> "start";
                    case "stop_logging" -> "stop";
                    default -> commandValue.replaceAll("[^a-zA-Z0-9_-]", "_");
                };
            }
        }
        return "push";
    }

    @SuppressWarnings("unchecked")
    private String sessionId(PushEnvelope envelope) {
        Object data = envelope.payload().get("data");
        if (data instanceof Map<?, ?> dataMap) {
            Object sessionId = dataMap.get("sessionId");
            if (sessionId instanceof String sessionIdValue && !sessionIdValue.isBlank()) {
                return sessionIdValue;
            }
        }
        return envelope.collapseId() == null || envelope.collapseId().isBlank() ? "unknown-session" : envelope.collapseId();
    }

    private String topicFor(PushEnvelope envelope) {
        if (envelope.topic() != null && !envelope.topic().isBlank()) {
            return envelope.topic();
        }
        if (properties.getTopic() != null && !properties.getTopic().isBlank()) {
            return properties.getTopic();
        }
        throw new ApiException("APNS_TOPIC_MISSING", "Missing APNs topic for push request", HttpStatus.INTERNAL_SERVER_ERROR);
    }

    private String jwt() {
        Instant now = Instant.now();
        if (cachedJwt != null && cachedJwtExpiresAt.isAfter(now.plusSeconds(300))) {
            return cachedJwt;
        }

        Map<String, Object> header = Map.of(
                "alg", "ES256",
                "kid", properties.getKeyId()
        );
        Map<String, Object> claims = Map.of(
                "iss", properties.getTeamId(),
                "iat", now.getEpochSecond()
        );

        try {
            String encodedHeader = encodeJson(header);
            String encodedClaims = encodeJson(claims);
            String signingInput = encodedHeader + "." + encodedClaims;
            Signature signature = Signature.getInstance("SHA256withECDSAinP1363Format");
            signature.initSign(privateKey);
            signature.update(signingInput.getBytes(StandardCharsets.UTF_8));
            String encodedSignature = Base64.getUrlEncoder().withoutPadding().encodeToString(signature.sign());
            cachedJwt = signingInput + "." + encodedSignature;
            cachedJwtExpiresAt = now.plusSeconds(50 * 60L);
            return cachedJwt;
        } catch (GeneralSecurityException exception) {
            throw new ApiException("APNS_JWT_SIGNING_FAILED", exception.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private String encodeJson(Map<String, Object> value) {
        try {
            return Base64.getUrlEncoder().withoutPadding()
                    .encodeToString(objectMapper.writeValueAsBytes(value));
        } catch (JsonProcessingException exception) {
            throw new ApiException("APNS_JWT_SERIALIZATION_FAILED", exception.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private PrivateKey loadPrivateKey(String path) {
        try {
            ClassPathResource resource = new ClassPathResource(path);
            byte[] keyBytes = resource.getInputStream().readAllBytes();
            String pem = new String(keyBytes, StandardCharsets.UTF_8);
            String normalizedPem = pem.replace("-----BEGIN PRIVATE KEY-----", "")
                                      .replace("-----END PRIVATE KEY-----", "")
                                      .replaceAll("\\s+", "");
            byte[] decodedKey = Base64.getMimeDecoder().decode(normalizedPem);
            PKCS8EncodedKeySpec keySpec = new PKCS8EncodedKeySpec(decodedKey);
            return KeyFactory.getInstance("EC").generatePrivate(keySpec);
        } catch (IOException | GeneralSecurityException | IllegalArgumentException exception) {
            throw new ApiException("APNS_PRIVATE_KEY_INVALID", exception.getMessage(), HttpStatus.INTERNAL_SERVER_ERROR);
        }
    }

    private void validateProperties(ApnsProperties properties) {
        Map<String, String> required = new LinkedHashMap<>();
        required.put("teamId", properties.getTeamId());
        required.put("keyId", properties.getKeyId());
        required.put("privateKeyPath", properties.getPrivateKeyPath());

        required.forEach((name, value) -> {
            if (value == null || value.isBlank()) {
                throw new ApiException("APNS_CONFIG_MISSING", "Missing APNs config: " + name, HttpStatus.INTERNAL_SERVER_ERROR);
            }
        });
    }
}
