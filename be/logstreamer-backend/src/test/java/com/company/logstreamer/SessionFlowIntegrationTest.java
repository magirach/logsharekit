package com.company.logstreamer;

import com.company.logstreamer.audit.persistence.AuditEntry;
import com.company.logstreamer.audit.persistence.InMemoryAuditRepository;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.web.servlet.MockMvc;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.http.MediaType.APPLICATION_JSON;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = {
        "logstreamer.push.apns.simulator-output-dir=target/test-generated-apns"
})
@AutoConfigureMockMvc
@DirtiesContext(classMode = DirtiesContext.ClassMode.BEFORE_EACH_TEST_METHOD)
class SessionFlowIntegrationTest {
    private static final Path SIMULATOR_OUTPUT_DIR = Path.of("target/test-generated-apns");

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private InMemoryAuditRepository auditRepository;

    @BeforeEach
    void clearSimulatorOutputDirectory() throws IOException {
        if (!Files.exists(SIMULATOR_OUTPUT_DIR)) {
            return;
        }
        try (var paths = Files.walk(SIMULATOR_OUTPUT_DIR)) {
            paths.sorted(Comparator.reverseOrder())
                    .filter(path -> !path.equals(SIMULATOR_OUTPUT_DIR))
                    .forEach(path -> {
                        try {
                            Files.deleteIfExists(path);
                        } catch (IOException exception) {
                            throw new RuntimeException(exception);
                        }
                    });
        }
    }

    @Test
    void sessionCanProgressFromCreateToIngestionAndSearch() throws Exception {
        String createPayload = """
                {
                  "appId": "ios-app",
                  "environment": "internal",
                  "bundleIdentifier": "com.example.logstreamer.podsexample",
                  "apnsToken": "apns-token-123",
                  "userId": "user-123",
                  "logs": "network,crash,logs",
                  "stopPolicy": {
                    "expiryMinutes": 30
                  },
                  "retentionHours": 24
                }
                """;

        String createResponse = mockMvc.perform(post("/api/v1/sessions")
                        .contentType(APPLICATION_JSON)
                        .content(createPayload))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("PENDING"))
                .andReturn()
                .getResponse()
                .getContentAsString();

        JsonNode createdSession = objectMapper.readTree(createResponse);
        String sessionId = createdSession.get("sessionId").asText();
        String token = uploadTokenFor(sessionId);

        AuditEntry startPushEntry = auditRepository.findBySessionId(sessionId).stream()
                .filter(entry -> entry.actionType().equals("START_PUSH_SENT"))
                .findFirst()
                .orElseThrow();
        assertThat(startPushEntry.details().get("apnsToken")).isEqualTo("apns-token-123");
        assertThat(startPushEntry.details().get("bundleIdentifier")).isEqualTo("com.example.logstreamer.podsexample");
        assertThat(startPushEntry.details().get("data")).isInstanceOfAny(java.util.Map.class);
        JsonNode startPushFile = simulatorPayloadFor(startPushEntry);
        assertThat(startPushFile.get("Simulator Target Bundle").asText()).isEqualTo("com.example.logstreamer.podsexample");
        assertThat(startPushFile.path("data").path("command").asText()).isEqualTo("start_logging");
        assertThat(startPushFile.path("data").path("sessionId").asText()).isEqualTo(sessionId);

        mockMvc.perform(post("/api/v1/mobile/sessions/{sessionId}/consent-shown", sessionId)
                        .header("Authorization", bearer(token))
                        .contentType(APPLICATION_JSON)
                        .content("{\"shownAt\":\"2026-06-28T10:00:00Z\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/mobile/sessions/{sessionId}/events", sessionId)
                        .header("Authorization", bearer(token))
                        .contentType(APPLICATION_JSON)
                        .content("""
                                {
                                  "sentAt": "2026-06-28T10:01:00Z",
                                  "events": [
                                    {
                                      "eventId": "evt-1",
                                      "timestamp": "2026-06-28T10:00:30Z",
                                      "type": "app_log",
                                      "level": "INFO",
                                      "component": "HomeScreen",
                                      "message": "Screen loaded",
                                      "metadata": {
                                        "session": "foreground"
                                      },
                                      "payload": {
                                        "message": "Screen loaded"
                                      }
                                    }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accepted").value(1))
                .andExpect(jsonPath("$.rejected").value(0))
                .andExpect(jsonPath("$.status").value("ACTIVE"));

        mockMvc.perform(get("/api/v1/sessions/{sessionId}", sessionId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.consentStatus").value("ACCEPTED"))
                .andExpect(jsonPath("$.bundleIdentifier").value("com.example.logstreamer.podsexample"))
                .andExpect(jsonPath("$.logs[0]").value("network"))
                .andExpect(jsonPath("$.logs[1]").value("crash"))
                .andExpect(jsonPath("$.logs[2]").value("logs"));

        mockMvc.perform(get("/api/v1/sessions/{sessionId}/logs", sessionId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].eventId").value("evt-1"))
                .andExpect(jsonPath("$[0].type").value("app_log"))
                .andExpect(jsonPath("$[0].component").value("HomeScreen"));

        mockMvc.perform(post("/api/v1/sessions/{sessionId}/stop", sessionId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"));

        AuditEntry stopPushEntry = auditRepository.findBySessionId(sessionId).stream()
                .filter(entry -> entry.actionType().equals("STOP_PUSH_SENT"))
                .findFirst()
                .orElseThrow();
        JsonNode stopPushFile = simulatorPayloadFor(stopPushEntry);
        assertThat(stopPushFile.get("Simulator Target Bundle").asText()).isEqualTo("com.example.logstreamer.podsexample");
        assertThat(stopPushFile.path("data").path("command").asText()).isEqualTo("stop_logging");
        assertThat(stopPushFile.path("data").path("sessionId").asText()).isEqualTo(sessionId);

        mockMvc.perform(post("/api/v1/mobile/sessions/{sessionId}/events", sessionId)
                        .header("Authorization", bearer(token))
                        .contentType(APPLICATION_JSON)
                        .content("""
                                {
                                  "events": [
                                    {
                                      "eventId": "evt-2",
                                      "type": "app_log",
                                      "component": "HomeScreen"
                                    }
                                  ]
                                }
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accepted").value(0))
                .andExpect(jsonPath("$.rejected").value(1))
                .andExpect(jsonPath("$.status").value("COMPLETED"));
    }

    @Test
    void uploadRequiresValidBearerToken() throws Exception {
        String sessionId = createSessionAndReturnId();

        mockMvc.perform(post("/api/v1/mobile/sessions/{sessionId}/events", sessionId)
                        .header("Authorization", "Bearer invalid-token")
                        .contentType(APPLICATION_JSON)
                        .content("""
                                {
                                  "events": [
                                    {
                                      "eventId": "evt-1",
                                      "type": "app_log",
                                      "component": "Bootstrap"
                                    }
                                  ]
                                }
                                """))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_UPLOAD_TOKEN"));
    }

    private String createSessionAndReturnId() throws Exception {
        String response = mockMvc.perform(post("/api/v1/sessions")
                        .contentType(APPLICATION_JSON)
                        .content("""
                                {
                                  "appId": "ios-app",
                                  "environment": "internal",
                                  "bundleIdentifier": "com.example.logstreamer.podsexample",
                                  "apnsToken": "apns-token-123",
                                  "userId": "user-123",
                                  "logs": "logs",
                                  "stopPolicy": {
                                    "expiryMinutes": 30
                                  },
                                  "retentionHours": 24
                                }
                                """))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        return objectMapper.readTree(response).get("sessionId").asText();
    }

    private String uploadTokenFor(String sessionId) throws Exception {
        String response = mockMvc.perform(get("/api/v1/debug/sessions/{sessionId}/upload-token", sessionId))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        JsonNode node = objectMapper.readTree(response);
        JsonNode token = node.get("uploadToken");
        assertThat(token).isNotNull();
        return token.asText();
    }

    private String bearer(String token) {
        return "Bearer " + token;
    }

    private JsonNode simulatorPayloadFor(AuditEntry entry) throws IOException {
        Object simulatorFilePath = entry.details().get("simulatorFilePath");
        assertThat(simulatorFilePath).isInstanceOf(String.class);
        Path filePath = Path.of((String) simulatorFilePath);
        assertThat(filePath).exists();
        return objectMapper.readTree(Files.readString(filePath));
    }
}
