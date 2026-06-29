import Foundation

public struct LogStreamerNetworkEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let requestMethod: String
    public let url: String
    public let startedAt: String
    public let finishedAt: String
    public let durationMs: Int
    public let requestHeaders: [String: String]
    public let requestBody: String?
    public let responseStatusCode: Int?
    public let responseHeaders: [String: String]
    public let responseBody: String?
    public let errorDescription: String?

    public init(
        id: UUID,
        requestMethod: String,
        url: String,
        startedAt: String,
        finishedAt: String,
        durationMs: Int,
        requestHeaders: [String: String],
        requestBody: String?,
        responseStatusCode: Int?,
        responseHeaders: [String: String],
        responseBody: String?,
        errorDescription: String?
    ) {
        self.id = id
        self.requestMethod = requestMethod
        self.url = url
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.durationMs = durationMs
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseStatusCode = responseStatusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.errorDescription = errorDescription
    }

    public var curlCommand: String {
        var segments = ["curl -X \(requestMethod.shellEscaped)"]
        for header in requestHeaders.sorted(by: { $0.key < $1.key }) {
            segments.append("-H '\(header.key): \(header.value)'")
        }
        if let requestBody, !requestBody.isEmpty {
            segments.append("--data '\(requestBody.shellEscaped)'")
        }
        segments.append("'\(url.shellEscaped)'")
        return segments.joined(separator: " ")
    }

    public var host: String {
        URL(string: url)?.host ?? url
    }

    public var path: String {
        guard let parsedURL = URL(string: url),
              let components = URLComponents(url: parsedURL, resolvingAgainstBaseURL: false) else {
            return url
        }
        let path = components.path.isEmpty ? "/" : components.path
        if let query = components.query, !query.isEmpty {
            return "\(path)?\(query)"
        }
        return path
    }

    public var statusSummary: String {
        if let responseStatusCode {
            return String(responseStatusCode)
        }
        return errorDescription == nil ? "Pending" : "Error"
    }
}

@MainActor
final class NetworkInspectorStore {
    private var entries: [LogStreamerNetworkEntry] = []
    private var maxEntries = 200

    func configure(maxEntries: Int) {
        self.maxEntries = max(0, maxEntries)
        trimIfNeeded()
    }

    func append(_ entry: LogStreamerNetworkEntry) {
        guard maxEntries > 0 else { return }
        entries.insert(entry, at: 0)
        trimIfNeeded()
        NotificationCenter.default.post(name: .logStreamerNetworkInspectorDidChange, object: nil)
    }

    func snapshot() -> [LogStreamerNetworkEntry] {
        entries
    }

    func clear() {
        entries.removeAll()
        NotificationCenter.default.post(name: .logStreamerNetworkInspectorDidChange, object: nil)
    }

    private func trimIfNeeded() {
        guard entries.count > maxEntries else { return }
        entries.removeLast(entries.count - maxEntries)
    }
}

private extension String {
    var shellEscaped: String {
        replacingOccurrences(of: "'", with: "'\\''")
    }
}

extension Notification.Name {
    static let logStreamerNetworkInspectorDidChange = Notification.Name("LogStreamerNetworkInspectorDidChange")
}
