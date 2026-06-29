# Backend

Spring Boot scaffold for the Mobile Log Streamer phase 1 backend.

## What is implemented

- session creation and listing
- manual stop and resend actions
- mobile consent shown and cancel callbacks
- event ingestion
- session status updates
- in-memory log search by `sessionId`
- SSE live stream endpoint
- scheduled session expiry
- in-memory audit trail

## Current storage model

This scaffold uses in-memory repositories so it can run without PostgreSQL or OpenSearch.

Next production step:

- replace session and audit repositories with PostgreSQL
- replace in-memory log store with OpenSearch
- move APNs credentials into secure secret storage and add retry / dead-letter handling

## Run

```bash
cd be/logstreamer-backend
mvn spring-boot:run
```

## Main endpoints

- `POST /api/v1/sessions`
- `GET /api/v1/sessions`
- `GET /api/v1/sessions/{sessionId}`
- `POST /api/v1/sessions/{sessionId}/stop`
- `POST /api/v1/sessions/{sessionId}/resend`
- `POST /api/v1/mobile/sessions/{sessionId}/consent-shown`
- `POST /api/v1/mobile/sessions/{sessionId}/cancel`
- `POST /api/v1/mobile/sessions/{sessionId}/events`
- `GET /api/v1/sessions/{sessionId}/logs`
- `GET /api/v1/sessions/{sessionId}/stream`

### Create session request

`POST /api/v1/sessions` now requires:

- `appId`
- `environment`
- `bundleIdentifier`
- `apnsToken`
- `userId`
- `logs` as a comma-separated string using only `network`, `crash`, `logs`
- `stopPolicy`
- `retentionHours`

Example:

```json
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
```

On create, the backend now dispatches a start push through the configured push transport. By default local/dev uses the mock transport. When APNs is enabled, the backend sends an HTTP/2 request to Apple with token-based authentication and records the request plus transport result in the audit trail.

When APNs is enabled but `logstreamer.push.apns.send-enabled=false`, the backend writes simulator-ready `.apns` payload files instead of sending them to Apple. It emits one file for session start and one for session stop in `generated-apns/` by default, with names like `start-<sessionId>.apns` and `stop-<sessionId>.apns`.

### Enable real APNs

Set these values before starting the backend:

- `logstreamer.push.apns.enabled=true`
- `LOGSTREAMER_APNS_TEAM_ID=<apple-team-id>`
- `LOGSTREAMER_APNS_KEY_ID=<apns-auth-key-id>`
- `LOGSTREAMER_APNS_PRIVATE_KEY_PEM=<contents of the .p8 key>`

Defaults:

- `base-url=https://api.sandbox.push.apple.com`
- `simulator-output-dir=generated-apns`
- push type: `background`
- priority: `5`

For production APNs, override `logstreamer.push.apns.base-url` to `https://api.push.apple.com`.

For simulator testing, use the same bundle id you entered when creating the session and then trigger the generated file with:

```bash
xcrun simctl push booted <bundle-id> generated-apns/start-<sessionId>.apns
xcrun simctl push booted <bundle-id> generated-apns/stop-<sessionId>.apns
```

## Postman

Import these files into Postman for local testing:

- `postman/logstreamer-local.postman_collection.json`
- `postman/logstreamer-local.postman_environment.json`

Recommended local test order:

1. `Health`
2. `Create Session`
3. `Get Upload Token`
4. `Consent Shown`
5. `Upload App Logs`
6. `Search Logs`
7. `Stop Session`

Local-only debug helper:

- `GET /api/v1/debug/sessions/{sessionId}/upload-token`

This endpoint exists only for local testing support and should be disabled outside local/dev by setting `logstreamer.debug.enabled=false`.
