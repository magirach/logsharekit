import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class LogStreamerRuntime {
    static let shared = LogStreamerRuntime()

    private var config: LogStreamerConfig?
    private let store = SessionStore()
    private var uploadClient: UploadClient?
    private var redactionEngine: RedactionEngine?
    private let consentManager = ConsentManager()
    private let buffer = BatchBuffer()
    private let networkInspectorStore = NetworkInspectorStore()
    private var currentSession: PersistedSession?
    private var isForeground = true
    private var flushTask: Task<Void, Never>?
    private var lastError: String?

    /// Restores any previously accepted session so relaunches can continue an active server session.
    private init() {
        currentSession = store.load()
    }

    /// Rebuilds runtime collaborators from host app config during startup.
    /// - Parameter config: The host application configuration used to build runtime collaborators.
    func initialize(config: LogStreamerConfig) {
        self.config = config
        self.isForeground = Self.applicationIsForeground
        self.uploadClient = UploadClient(config: config)
        self.redactionEngine = RedactionEngine(redactedKeys: config.redactedKeys)
        self.networkInspectorStore.configure(
            maxEntries: config.networkInspectorMaxEntries,
            defaultSettings: config.networkInspectorSettings
        )
        if currentSession == nil {
            currentSession = store.load()
        }
    }

    /// Entry point for both direct async handling and `handleRemoteNotification`.
    /// - Parameter userInfo: The raw APNs `userInfo` dictionary delivered by the application.
    func handlePush(userInfo: [AnyHashable: Any]) async {
        isForeground = Self.applicationIsForeground
        do {
            let payload = try PushPayloadParser.parse(userInfo: userInfo)
            switch payload {
            case .start(let startPayload):
                try await startSession(payload: startPayload)
            case .stop(let stopPayload):
                await stopSessionIfMatches(sessionId: stopPayload.sessionId, reason: "stop-push")
            }
        } catch {
            lastError = "LS001 invalid push payload: \(error)"
        }
    }

    /// Foreground-only capture resumes here after an app activate event.
    func applicationDidBecomeActive() async {
        isForeground = true
        guard var session = currentSession else { return }
        if isExpired(session) {
            await stopSessionIfMatches(sessionId: session.sessionId, reason: "expiry")
            return
        }
        if !session.consentAccepted, session.state == .pendingConsent {
            await resolvePendingConsentIfPossible()
            return
        }
        if session.consentAccepted, session.state == .paused || session.state == .consentAccepted {
            session.state = .active
            session.lastUpdatedAt = SharedDateFormatter.iso8601.string(from: Date())
            currentSession = session
            try? store.save(session)
            appendLifecycleEvent(message: "App became active")
        }
    }

    /// Backgrounding pauses active capture and flushes what is already buffered.
    func applicationDidEnterBackground() async {
        isForeground = false
        guard var session = currentSession, session.state == .active else { return }
        session.state = .paused
        session.lastUpdatedAt = SharedDateFormatter.iso8601.string(from: Date())
        currentSession = session
        try? store.save(session)
        appendLifecycleEvent(message: "App entered background")
        await flushIfNeeded(force: true)
    }

    /// Best-effort shutdown flush before process exit.
    func applicationWillTerminate() async {
        appendLifecycleEvent(message: "App will terminate")
        await flushIfNeeded(force: true)
    }

    /// Captures application logs only when the session is active and still within its stop policy window.
    /// - Parameters:
    ///   - level: The log severity to record.
    ///   - message: The human-readable log message.
    ///   - component: The logical component emitting the log.
    ///   - metadata: Additional string metadata to attach to the event.
    func recordAppLog(level: LogSeverity, message: String, component: String, metadata: [String: String]) async {
        guard var session = currentSession, session.state == .active else { return }
        if isExpired(session) {
            await stopSessionIfMatches(sessionId: session.sessionId, reason: "expiry")
            return
        }
        session.lastUpdatedAt = SharedDateFormatter.iso8601.string(from: Date())
        currentSession = session
        let redactedMetadata = redactionEngine?.redactMetadata(metadata) ?? metadata
        let event = LogEvent(
            eventId: UUID().uuidString,
            sessionId: session.sessionId,
            timestamp: SharedDateFormatter.iso8601.string(from: Date()),
            type: .app,
            level: level.rawValue,
            component: component,
            message: message,
            metadata: redactedMetadata,
            payload: nil
        )
        enqueue(event: event)
    }

    /// Mirrors a single request/response exchange into separate request and response log events.
    /// - Parameters:
    ///   - request: The original request issued by the instrumented session.
    ///   - response: The HTTP response returned by the server, if any.
    ///   - responseBody: The response body data captured from the request lifecycle.
    ///   - error: The transport or protocol error returned by the request, if any.
    func recordNetworkExchange(
        request: URLRequest,
        response: HTTPURLResponse?,
        responseBody: Data?,
        error: Error?,
        startedAt: Date,
        finishedAt: Date
    ) async {
        let requestHeaders = redactionEngine?.redact(headers: request.allHTTPHeaderFields ?? [:]) ?? request.allHTTPHeaderFields ?? [:]
        let responseHeaders = response.map {
            redactionEngine?.redact(headers: $0.allHeaderFields.compactMapKeys()) ?? $0.allHeaderFields.compactMapKeys()
        } ?? [:]
        networkInspectorStore.append(
            LogStreamerNetworkEntry(
                id: UUID(),
                requestMethod: request.httpMethod ?? "GET",
                url: request.url?.absoluteString ?? "",
                startedAt: SharedDateFormatter.iso8601.string(from: startedAt),
                finishedAt: SharedDateFormatter.iso8601.string(from: finishedAt),
                durationMs: max(0, Int(finishedAt.timeIntervalSince(startedAt) * 1000)),
                requestHeaders: requestHeaders,
                requestBody: Self.makeDisplayString(from: request.httpBody),
                responseStatusCode: response?.statusCode,
                responseHeaders: responseHeaders,
                responseBody: Self.makeDisplayString(from: responseBody),
                errorDescription: error?.localizedDescription
            )
        )

        guard let session = currentSession, session.state == .active else { return }
        let requestPayload = session.captureNetworkBodies ? redactionEngine?.redactPayload(Self.makePayload(from: request.httpBody)) : nil
        let requestEvent = LogEvent(
            eventId: UUID().uuidString,
            sessionId: session.sessionId,
            timestamp: SharedDateFormatter.iso8601.string(from: Date()),
            type: .networkRequest,
            level: "INFO",
            component: "URLSession",
            message: request.url?.absoluteString,
            metadata: [
                "method": request.httpMethod ?? "GET",
                "url": request.url?.absoluteString ?? "",
                "headers": String(describing: requestHeaders)
            ],
            payload: requestPayload
        )
        enqueue(event: requestEvent)

        var responseMetadata: [String: String] = [
            "url": request.url?.absoluteString ?? ""
        ]
        if let response {
            responseMetadata["statusCode"] = String(response.statusCode)
            responseMetadata["headers"] = String(describing: responseHeaders)
        }
        if let error {
            responseMetadata["error"] = error.localizedDescription
        }
        let responsePayload = session.captureNetworkBodies ? redactionEngine?.redactPayload(Self.makePayload(from: responseBody)) : nil
        let responseEvent = LogEvent(
            eventId: UUID().uuidString,
            sessionId: session.sessionId,
            timestamp: SharedDateFormatter.iso8601.string(from: Date()),
            type: .networkResponse,
            level: error == nil ? "INFO" : "ERROR",
            component: "URLSession",
            message: request.url?.absoluteString,
            metadata: responseMetadata,
            payload: responsePayload
        )
        enqueue(event: responseEvent)
    }

    /// Provides the sample UI with a safe read-only runtime snapshot.
    /// - Returns: A snapshot of the active session state, buffered count, and last surfaced error.
    func debugSnapshot() -> LogStreamerDebugSnapshot {
        LogStreamerDebugSnapshot(
            sessionId: currentSession?.sessionId,
            state: currentSession?.state.rawValue ?? ClientSessionState.idle.rawValue,
            bufferedEvents: buffer.eventCount(),
            lastError: lastError
        )
    }

    /// Creates the local session state, reports consent visibility, and waits for the user's decision.
    /// - Parameter payload: The parsed start command received from APNs.
    private func startSession(payload: StartSessionPayload) async throws {
        if let currentSession {
            if currentSession.sessionId == payload.sessionId {
                await resolvePendingConsentIfPossible()
                return
            }
            lastError = "LS003 session conflict"
            return
        }

        let captureNetworkBodies = payload.captureNetworkBodies ?? payload.logs?.contains("network") ?? false

        let session = PersistedSession(
            sessionId: payload.sessionId,
            uploadToken: payload.uploadToken,
            uploadBaseURL: payload.baseURL,
            appId: payload.appId,
            environment: payload.environment,
            state: .pendingConsent,
            consentAccepted: false,
            captureNetworkBodies: captureNetworkBodies,
            stopPolicy: payload.stopPolicy,
            startedAt: SharedDateFormatter.iso8601.string(from: Date()),
            lastUpdatedAt: SharedDateFormatter.iso8601.string(from: Date())
        )
        currentSession = session
        try? store.save(session)

        do {
            try await uploadClient?.sendConsentShown(session: session)
        } catch {
            lastError = "LS007 consent shown callback failed: \(error)"
        }
        await resolvePendingConsentIfPossible()
    }

    /// Performs the device-side stop sequence and discards any local state after a final flush.
    /// - Parameters:
    ///   - sessionId: The session identifier that must match the active local session.
    ///   - reason: The reason recorded in the final lifecycle event before shutdown.
    private func stopSessionIfMatches(sessionId: String, reason: String) async {
        guard let session = currentSession, session.sessionId == sessionId else { return }
        currentSession?.state = .stopping
        appendLifecycleEvent(message: "Stopping session: \(reason)")
        await flushIfNeeded(force: true)
        currentSession = nil
        store.clear()
        buffer.removeAll()
        flushTask?.cancel()
        flushTask = nil
    }

    /// Enqueues an event and schedules an immediate or delayed flush based on the configured batch policy.
    /// - Parameter event: The log event to append to the in-memory upload queue.
    private func enqueue(event: LogEvent) {
        buffer.append(event)
        if let config, buffer.eventCount() >= config.batchPolicy.maxEvents || buffer.approximateSize() >= config.batchPolicy.maxApproximateBytes {
            flushTask?.cancel()
            flushTask = Task { await flushIfNeeded(force: true) }
            return
        }
        if flushTask == nil, let config {
            flushTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(config.batchPolicy.flushInterval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.flushIfNeeded(force: false)
            }
        }
    }

    /// Uploads the current batch and leaves it in memory when transport fails so it can be retried later.
    /// - Parameter force: When `true`, recursively drains all acknowledged batches until the queue is empty.
    private func flushIfNeeded(force: Bool) async {
        defer { flushTask = nil }
        guard let session = currentSession, let config, let uploadClient else { return }
        let batch = buffer.takeBatch(maxEvents: config.batchPolicy.maxEvents, maxApproximateBytes: config.batchPolicy.maxApproximateBytes)
        guard !batch.isEmpty else { return }
        do {
            _ = try await uploadClient.sendBatch(session: session, events: batch)
            buffer.removeFirst(batch.count)
            if force, buffer.eventCount() > 0 {
                await flushIfNeeded(force: true)
            }
        } catch {
            lastError = "LS006 upload transport failure: \(error)"
            if let lastError {
                print(lastError)
            }
        }
    }

    /// Lifecycle events make client state transitions visible in the streamed logs.
    /// - Parameter message: The lifecycle message to append to the current session log stream.
    private func appendLifecycleEvent(message: String) {
        guard let session = currentSession else { return }
        let event = LogEvent(
            eventId: UUID().uuidString,
            sessionId: session.sessionId,
            timestamp: SharedDateFormatter.iso8601.string(from: Date()),
            type: .lifecycle,
            level: "INFO",
            component: "LogStreamer",
            message: message,
            metadata: [:],
            payload: nil
        )
        buffer.append(event)
    }

    /// Uses the local start timestamp and stop policy instead of relying on server callbacks for expiry.
    /// - Parameter session: The locally persisted session whose expiry should be evaluated.
    /// - Returns: `true` when the local session has exceeded its stop policy window.
    private func isExpired(_ session: PersistedSession) -> Bool {
        guard let startedAt = SharedDateFormatter.iso8601.date(from: session.startedAt) else { return false }
        let expiryDate = startedAt.addingTimeInterval(TimeInterval(session.stopPolicy.expiresAfterMinutes * 60))
        return Date() >= expiryDate
    }

    /// Serializes arbitrary bodies into JSON when possible and falls back to string or base64 for binary payloads.
    /// - Parameter data: The raw body data captured from a network request or response.
    /// - Returns: A JSON-friendly payload representation, or `nil` when the body is empty.
    private static func makePayload(from data: Data?) -> JSONValue? {
        guard let data, !data.isEmpty else { return nil }
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           JSONSerialization.isValidJSONObject(jsonObject) {
            return JSONValue(any: jsonObject)
        }
        if let string = String(data: data, encoding: .utf8) {
            return .string(string)
        }
        return .string(data.base64EncodedString())
    }

    private static func makeDisplayString(from data: Data?) -> String? {
        guard let payload = makePayload(from: data) else { return nil }
        switch payload {
        case .string(let string):
            return string
        case .number(let number):
            return String(number)
        case .bool(let bool):
            return String(bool)
        case .null:
            return "null"
        case .object, .array:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let encoded = try? encoder.encode(payload) else { return String(describing: payload) }
            return String(data: encoded, encoding: .utf8)
        }
    }

    /// Promotes a pending session into an accepted session once the app has active UI to show consent.
    private func resolvePendingConsentIfPossible() async {
        guard let session = currentSession, !session.consentAccepted, session.state == .pendingConsent else { return }
        guard !isExpired(session) else {
            await stopSessionIfMatches(sessionId: session.sessionId, reason: "expiry")
            return
        }
        guard isForeground, consentManager.canPresentConsent() else {
            return
        }

        let accepted = await consentManager.requestConsent(copy: config?.consentCopy ?? ConsentCopy())
        if accepted {
            let activeSession = PersistedSession(
                sessionId: session.sessionId,
                uploadToken: session.uploadToken,
                uploadBaseURL: session.uploadBaseURL,
                appId: session.appId,
                environment: session.environment,
                state: .active,
                consentAccepted: true,
                captureNetworkBodies: session.captureNetworkBodies,
                stopPolicy: session.stopPolicy,
                startedAt: session.startedAt,
                lastUpdatedAt: SharedDateFormatter.iso8601.string(from: Date())
            )
            currentSession = activeSession
            try? store.save(activeSession)
            appendLifecycleEvent(message: "Session started")
            return
        }

        do {
            try await uploadClient?.sendCancel(session: session)
        } catch {
            lastError = "LS007 cancel callback failed: \(error)"
        }
        currentSession = nil
        store.clear()
        buffer.removeAll()
        flushTask?.cancel()
        flushTask = nil
    }

    /// Resets singleton state for deterministic package tests.
    func resetForTesting() {
        flushTask?.cancel()
        flushTask = nil
        currentSession = nil
        config = nil
        uploadClient = nil
        redactionEngine = nil
        isForeground = true
        lastError = nil
        buffer.removeAll()
        networkInspectorStore.resetForTesting()
        store.clear()
    }

    func networkEntries() -> [LogStreamerNetworkEntry] {
        networkInspectorStore.snapshot()
    }

    func networkEntrySummaries() -> [LogStreamerNetworkEntrySummary] {
        networkInspectorStore.snapshotSummaries()
    }

    func networkEntry(id: UUID) -> LogStreamerNetworkEntry? {
        networkInspectorStore.entry(id: id)
    }

    func clearNetworkEntries() {
        networkInspectorStore.clear()
    }

    func networkInspectorSettings() -> LogStreamerNetworkInspectorSettings {
        networkInspectorStore.settingsSnapshot()
    }

    func updateNetworkInspectorSettings(_ settings: LogStreamerNetworkInspectorSettings) {
        networkInspectorStore.updateSettings(settings)
    }

    func exportNetworkEntry(id: UUID) -> URL? {
        networkInspectorStore.exportEntry(id: id)
    }

    func exportNetworkSession() -> URL? {
        networkInspectorStore.exportSession()
    }

    private static var applicationIsForeground: Bool {
#if canImport(UIKit)
        UIApplication.shared.applicationState == .active
#else
        true
#endif
    }
}

private extension Dictionary where Key == AnyHashable, Value == Any {
    /// Converts Foundation header dictionaries into the string map expected by the redaction engine.
    /// - Returns: A `[String: String]` map suitable for metadata and header redaction.
    func compactMapKeys() -> [String: String] {
        reduce(into: [:]) { partialResult, entry in
            partialResult[String(describing: entry.key)] = String(describing: entry.value)
        }
    }
}
