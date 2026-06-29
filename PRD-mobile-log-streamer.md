# Product Requirements Document

## Title
Mobile Log Streamer Phase 1 Product Requirements Document

## Document Status
Draft based on approved phase 1 BRD

## Prepared On
June 28, 2026

## Source Document
This PRD is derived from [BRD-mobile-log-streamer.md](/Users/atiqaakif/Documents/logs_stream/BRD-mobile-log-streamer.md) and reflects only agreed phase 1 scope.

## Product Summary
Mobile Log Streamer is a phase 1 internal product capability that enables on-demand remote collection of iOS application logs from production or test devices. The product is activated by backend push notification, asks the end user for consent, starts streaming logs while the app is in foreground, and sends those logs to a central searchable server with a simple internal live-view UI.

The product is intended to reduce investigation time for mobile incidents without requiring permanent verbose logging or direct physical access to the device.

## Product Goal
Enable internal teams to remotely activate iOS app log streaming for a single device session, collect enough logs to diagnose an issue, and stop collection safely with user consent and searchable operational visibility.

## Problem
When mobile production issues happen, engineers and support teams often lack device-side logs. Because iOS applications run inside sandboxed environments, logs are not easy to retrieve remotely. Existing options are manual, incomplete, or too slow for active issue investigation.

## Target Users

### Primary Users

- Support engineers investigating active user issues
- Mobile developers debugging production defects
- SRE or platform teams monitoring issue response
- QA teams validating issues during internal testing

### Secondary Users

- Product managers tracking readiness and rollout risk
- Security and compliance teams reviewing consent and log handling

## User Personas

### Persona 1: Support Engineer
Needs a fast way to trigger logging for a user facing a live issue and inspect logs in real time without waiting for a special build or manual export.

### Persona 2: Mobile Developer
Needs correlated app and network logs tied to a known session so root cause analysis can be done quickly.

### Persona 3: QA Engineer
Needs controlled logging on internal devices to validate issue reproduction and confirm fixes before wider rollout.

### Persona 4: End User
Needs a clear consent prompt explaining that diagnostic data will be collected and expects logging to stop when the issue investigation is over.

## Product Principles

- On-demand only: logging is off by default and starts only for a specific session.
- Consent-driven: logging begins only after explicit user consent.
- Operationally simple: phase 1 prioritizes a minimal but usable internal workflow.
- Safe by design: foreground-only streaming, single active session per device, and short retention.
- Searchable by session: logs must be easy to find for the active investigation.

## Goals and Success Criteria

### Goals

- Allow internal teams to start a remote logging session for an iOS app.
- Stream app logs and network logs for one active device session.
- Provide near real-time visibility of logs in an internal UI.
- Make collected logs searchable by `sessionId`.
- Resume logging automatically after app relaunch for the same active session.
- Keep data retention short and controlled.

### Success Metrics

- Percentage of requested sessions that successfully begin streaming
- Time from push trigger to first received log
- Percentage of sessions where enough logs are collected to investigate the issue
- Mean time to diagnose issues using the product
- Consent acceptance rate
- Percentage of sessions successfully resumed after app relaunch
- Push resend rate due to delivery failure

## Non-Goals

- Android support in phase 1
- Background-only logging in phase 1
- Public or end-user-facing log management UI
- Role-based access control in phase 1
- Advanced analytics across historical logs
- Diagnostic categories beyond app logs and network logs

## Scope

### In Scope

- iOS only
- Push-triggered start and stop
- Single active logging session per device
- User consent prompt at session start
- App logs
- Network logs including metadata, headers, request bodies, and response bodies when enabled
- Searchable server-side log storage
- Internal UI with live log updates
- Search in UI by `sessionId`
- Default retention of 24 hours
- Automatic logging resume after app relaunch for the same active session
- Configurable stop behavior delivered in push instructions

### Out of Scope

- Android implementation
- Multi-session support on one device
- Search by fields other than `sessionId` in phase 1
- Background streaming after app leaves foreground
- Fine-grained operator permissions
- Long-term storage or reporting beyond operational needs

## Product Assumptions

- The iOS application can receive and process push notifications.
- The app can persist session state locally and restore it after relaunch.
- The organization accepts a 24-hour default retention policy for phase 1.
- User consent wording can be approved by compliance and legal stakeholders.
- Internal users are acceptable as unrestricted operators in phase 1.

## User Stories

### Operator Stories

- As an operator, I want to trigger a logging session for a device so I can start collecting logs when an issue happens.
- As an operator, I want to set stop conditions for the session so I can control how long or how much data is collected.
- As an operator, I want to watch logs update in real time so I can confirm the issue is being captured.
- As an operator, I want to search logs by `sessionId` so I can inspect the exact investigation session.
- As an operator, I want to resend a push if nothing starts so I can recover from delivery failure.
- As an operator, I want to stop a session manually so I can end collection as soon as enough logs are received.

### End User Stories

- As an end user, I want to see a consent prompt before logs are collected so I understand what is happening.
- As an end user, I want logging to continue automatically after app relaunch for the same session so I do not need to keep approving repeatedly.
- As an end user, I want logging to happen only while I am using the app in foreground so background behavior stays limited.

### Developer Stories

- As a developer, I want app and network logs tied to a session ID so I can correlate events.
- As a developer, I want cancelled sessions to be visible when consent is denied so I know why no logs arrived.

## User Journey

### Journey 1: Successful Logging Session
1. Operator creates a logging session.
2. Backend generates a unique `sessionId`.
3. Backend sends a push containing session instructions.
4. App receives the push.
5. App shows a consent prompt.
6. User accepts.
7. Log streaming starts while the app is foregrounded.
8. Operator sees logs in the internal UI.
9. User relaunches the app if needed.
10. App restores the same active session and resumes logging on next foreground entry.
11. Server or operator stops the session.
12. Logs remain searchable for 24 hours, then expire based on retention policy.

### Journey 2: Consent Denied
1. Operator creates a logging session.
2. App receives the push.
3. App shows a consent prompt.
4. User denies consent.
5. Session is marked `cancelled`.
6. Operator sees that no logs were collected because consent was denied.

### Journey 3: Push Delivery Failure
1. Operator creates a logging session.
2. Push is not received or does not activate logging.
3. No logs appear in the UI.
4. Operator resends the push.
5. Logging begins if the app receives the retried push and the user consents.

## Feature Requirements

### Feature 1: Session Triggering
Operators must be able to create a new log collection session for a target device. The system must generate a unique `sessionId` and package it into the push payload with session-specific instructions such as stop behavior.

### Requirements

- Operator can initiate a session without RBAC restrictions in phase 1.
- Each new request creates exactly one unique `sessionId`.
- The push payload includes session ID and logging instructions.
- Only one active session is allowed per device at a time.
- Duplicate trigger attempts for the same active device should be handled safely.

### Feature 2: User Consent Flow
The app must present a consent prompt before starting log collection.

### Requirements

- Consent prompt appears when a valid start push is processed.
- Consent prompt explains that diagnostic data will be logged.
- Logging does not start until consent is accepted.
- If consent is denied, the session is marked `cancelled`.
- Once consent is granted for a session, the same session does not ask again after app relaunch.

### Feature 3: Foreground Log Streaming
The app must stream logs only while in foreground.

### Requirements

- Streaming starts only when app is foregrounded.
- Streaming pauses or stops when app is not in foreground, based on product-defined session behavior.
- Streaming resumes automatically on next foreground entry if the same session is still active.
- The app persists active session state across relaunch.
- Phase 1 does not require background log delivery.

### Feature 4: Log Capture
The product must capture app logs and network logs for the active session.

### Requirements

- App logs are included in the stream.
- Network logs are included in the stream.
- Network log capture may include metadata, headers, request bodies, and response bodies when enabled.
- Sensitive data handling must be configurable.
- PII transmission must only occur after user consent and approved configuration.

### Feature 5: Log Ingestion and Search
The server must store and expose logs for active investigation.

### Requirements

- Logs are ingested under the correct `sessionId`.
- Logs are viewable in near real time from the internal UI.
- Operators can search logs by `sessionId`.
- Session state is visible as `pending`, `active`, `completed`, `failed`, `expired`, or `cancelled`.
- Default retention is 24 hours.

### Feature 6: Session Stop Management
Sessions must stop through server control, operator action, or configured backup rules.

### Requirements

- Server can send a stop push when enough logs are collected.
- Operator can stop the session manually.
- Backup stop rules can be configured and included in the push instructions.
- Stop conditions may be time-based, size-based, event-count-based, or operator-controlled.
- Session closes cleanly and flushes buffered logs when stopping.

### Feature 7: Internal Operational UI
Phase 1 requires a simple internal UI focused on active investigations.

### Requirements

- UI shows active and completed sessions.
- UI shows live log updates for an active session.
- UI supports search by `sessionId` only.
- UI shows session status clearly.
- UI shows when no logs are received so operators know to resend push or investigate consent failure.

## UX Requirements

### End User Consent Experience

- Consent prompt must be short and clear.
- Prompt must explain that diagnostic logging is being requested.
- Prompt must indicate that collected data may include app and network logs.
- Prompt must explain that logging occurs only for the active investigation session.
- Prompt must allow clear accept and decline actions.

### Internal Operator Experience

- Trigger workflow should be simple and fast.
- Live log view should update without manual refresh.
- Session status should be obvious at a glance.
- Cancelled sessions should be distinguishable from technical failures.
- Resend push action should be easy to find.

## Product States

### Session States

- `pending`: session created, waiting for client start
- `consent_requested`: push received and consent prompt shown
- `active`: logs currently streaming
- `paused`: active session exists but app is not in foreground
- `completed`: stopped successfully
- `cancelled`: user denied consent
- `failed`: technical failure blocked session
- `expired`: backup stop or retention expiration ended session

### Device/App Behavior States

- No active session
- Active session persisted locally
- Foreground streaming
- Background paused
- Relaunched and waiting for foreground resume

## Prioritization

### Must Have

- iOS support
- Start push flow
- Consent prompt
- Foreground-only log streaming
- App and network logs
- Session persistence across relaunch
- Single active session per device
- Internal UI with live logs
- Search by `sessionId`
- Manual stop
- Server stop push
- 24-hour retention

### Should Have

- Push resend flow
- Configurable backup stop rules
- Clear cancelled session visibility
- Configurable sensitive-data handling

### Could Have Later

- Android support
- RBAC
- Richer search filters
- Additional diagnostic data categories
- Historical analytics and dashboards

## Dependencies

- iOS push notification integration
- Log streamer library integration inside the app
- Backend session management service
- Log ingestion API
- Searchable storage layer
- Internal operator UI
- Consent copy approval from compliance or legal stakeholders

## Risks

- Users may deny consent, reducing session completion rate.
- Full network payload logging raises higher privacy and redaction risk.
- Push delivery may be delayed or dropped.
- Foreground-only behavior may miss data if the user leaves the app.
- Open operator access in phase 1 may need operational guardrails.

## Risk Mitigations

- Show clear session status including `cancelled`.
- Enforce redaction and approved configuration before rollout.
- Provide resend push workflow.
- Support configurable backup stop behavior.
- Keep retention at 24 hours by default.

## Launch Plan

### Phase 1 Launch Sequence

1. Complete internal prototype on iOS.
2. Validate consent flow and session lifecycle.
3. Validate relaunch recovery and foreground resume behavior.
4. Validate searchable UI and operator workflow.
5. Roll out to internal testing users first.
6. Expand to controlled production use after operational confidence is established.

## Release Readiness Criteria

- Operators can start a session and receive a `sessionId`.
- Consent prompt appears reliably.
- Accepted sessions begin streaming logs.
- Denied consent results in `cancelled` state.
- Logs are searchable by `sessionId`.
- Live log UI updates during active session.
- Logging resumes automatically after app relaunch during the same active session.
- Stop flow works through manual action and stop push.
- Logs expire according to 24-hour default retention.
- Sensitive-data controls are active before rollout.

## Open Items for Design, Not Product Scope

- Exact push payload schema
- Exact ingestion API schema
- Client-side storage method for persisted session state
- Network interception implementation approach on iOS
- Redaction rule engine design
- Internal UI technology choice

## Recommendation
Proceed from this PRD into a technical design document focused on iOS client architecture, push payload format, session lifecycle management, ingestion APIs, redaction strategy, and internal live-view UI implementation.
