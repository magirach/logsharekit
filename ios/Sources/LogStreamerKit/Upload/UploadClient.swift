import Foundation

@MainActor
final class UploadClient {
    private let defaultBaseURL: URL
    private let urlSession: URLSession
    private let appId: String
    private let additionalHeaders: [String: String]
    private let deviceId: String?
    private let installationId: String?

    /// Captures the static SDK configuration; session-level overrides arrive later in the push payload.
    /// - Parameter config: The SDK configuration supplied by the host application.
    init(config: LogStreamerConfig) {
        self.defaultBaseURL = config.baseURL
        self.urlSession = config.uploadSessionFactory()
        self.appId = config.appId
        self.additionalHeaders = config.additionalHeaders
        self.deviceId = config.deviceId
        self.installationId = config.installationId
    }

    /// Notifies the backend that the consent prompt was shown on device.
    /// - Parameter session: The active session being acknowledged to the backend.
    func sendConsentShown(session: PersistedSession) async throws {
        let body = ["shownAt": ISO8601DateFormatter().string(from: Date())]
        _ = try await perform(
            path: "/api/v1/mobile/sessions/\(session.sessionId)/consent-shown",
            session: session,
            body: body
        )
    }

    /// Tells the backend the user declined the consent prompt.
    /// - Parameter session: The active session being cancelled on device.
    func sendCancel(session: PersistedSession) async throws {
        let body = [
            "cancelledAt": ISO8601DateFormatter().string(from: Date()),
            "reason": "USER_DENIED_CONSENT"
        ]
        _ = try await perform(
            path: "/api/v1/mobile/sessions/\(session.sessionId)/cancel",
            session: session,
            body: body
        )
    }

    @discardableResult
    /// Uploads a backend-shaped batch and returns the server acknowledgement when available.
    /// - Parameters:
    ///   - session: The active session that owns the upload token and URL override.
    ///   - events: The log events to send to the backend in this batch.
    /// - Returns: The decoded server acknowledgement, or a synthesized success response when the body is empty.
    func sendBatch(session: PersistedSession, events: [LogEvent]) async throws -> UploadAck {
        let request = EventBatchRequest(
            sentAt: ISO8601DateFormatter().string(from: Date()),
            events: events.map(UploadLogEvent.init(event:))
        )
        let data = try await perform(
            path: "/api/v1/mobile/sessions/\(session.sessionId)/events",
            session: session,
            body: request
        )
        return (try? JSONDecoder().decode(UploadAck.self, from: data)) ?? UploadAck(accepted: events.count, rejected: 0, status: "ACTIVE")
    }

    /// Applies shared headers and routes all mobile callbacks through the same authenticated transport.
    /// - Parameters:
    ///   - path: The backend path to call relative to the resolved base URL.
    ///   - session: The active session that provides authentication and URL override data.
    ///   - body: The encodable request body to POST.
    /// - Returns: The raw response body returned by the backend.
    private func perform<Body: Encodable>(path: String, session: PersistedSession, body: Body) async throws -> Data {
        var request = URLRequest(url: resolvedBaseURL(for: session).appendingPathComponent(path))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(session.uploadToken)", forHTTPHeaderField: "Authorization")
        request.addValue(appId, forHTTPHeaderField: "X-App-Id")
        request.addValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")
        if let deviceId {
            request.addValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        }
        if let installationId {
            request.addValue(installationId, forHTTPHeaderField: "X-Installation-Id")
        }
        for (key, value) in additionalHeaders {
            request.addValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadClientError.invalidResponse(statusCode: nil, body: nil)
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw UploadClientError.invalidResponse(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8)
            )
        }
        return data
    }

    /// Prefers the backend-supplied URL from the push payload so devices upload to a reachable host.
    /// - Parameter session: The active session that may contain a server-supplied upload base URL override.
    /// - Returns: The base URL that should be used for all callbacks and uploads for this session.
    private func resolvedBaseURL(for session: PersistedSession) -> URL {
        guard
            let override = session.uploadBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines),
            !override.isEmpty,
            let url = URL(string: override)
        else {
            return defaultBaseURL
        }
        return url
    }
}

enum UploadClientError: Error, LocalizedError {
    case invalidResponse(statusCode: Int?, body: String?)

    /// Keeps the surfaced mobile error short while preserving the backend status/body for debugging.
    /// - Returns: A compact human-readable description of the transport failure.
    var errorDescription: String? {
        switch self {
        case .invalidResponse(let statusCode, let body):
            var parts: [String] = []
            if let statusCode {
                parts.append("status \(statusCode)")
            } else {
                parts.append("non-HTTP response")
            }
            if let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append("body \(body)")
            }
            return parts.joined(separator: ", ")
        }
    }
}
