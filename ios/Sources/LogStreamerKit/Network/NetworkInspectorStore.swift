import Foundation

public enum LogStreamerBodyContentKind: String, Codable, Sendable, CaseIterable {
    case none
    case json
    case html
    case xml
    case text
    case binary

    public var title: String {
        switch self {
        case .none: return "None"
        case .json: return "JSON"
        case .html: return "HTML"
        case .xml: return "XML"
        case .text: return "Text"
        case .binary: return "Binary"
        }
    }
}

public struct LogStreamerNetworkInspectorSettings: Codable, Sendable, Equatable {
    public var resetOnAppLaunch: Bool
    public var ignoredHosts: [String]

    public init(
        resetOnAppLaunch: Bool = false,
        ignoredHosts: [String] = []
    ) {
        self.resetOnAppLaunch = resetOnAppLaunch
        self.ignoredHosts = ignoredHosts
    }

    func normalized() -> LogStreamerNetworkInspectorSettings {
        LogStreamerNetworkInspectorSettings(
            resetOnAppLaunch: resetOnAppLaunch,
            ignoredHosts: Array(
                Set(
                    ignoredHosts
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                        .filter { !$0.isEmpty }
                )
            ).sorted()
        )
    }
}

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
        if let requestBody = formattedRequestBody, !requestBody.isEmpty {
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

    public var endpoint: String {
        guard let parsedURL = URL(string: url),
              let components = URLComponents(url: parsedURL, resolvingAgainstBaseURL: false) else {
            return path
        }
        return components.path.isEmpty ? "/" : components.path
    }

    public var statusSummary: String {
        if let responseStatusCode {
            return String(responseStatusCode)
        }
        return errorDescription == nil ? "Pending" : "Error"
    }

    public var requestContentType: String? {
        NetworkInspectorBodyFormatter.contentType(from: requestHeaders)
    }

    public var responseContentType: String? {
        NetworkInspectorBodyFormatter.contentType(from: responseHeaders)
    }

    public var requestBodyKind: LogStreamerBodyContentKind {
        NetworkInspectorBodyFormatter.detectKind(body: requestBody, contentType: requestContentType)
    }

    public var responseBodyKind: LogStreamerBodyContentKind {
        NetworkInspectorBodyFormatter.detectKind(body: responseBody, contentType: responseContentType)
    }

    public var formattedRequestBody: String? {
        NetworkInspectorBodyFormatter.formattedBody(body: requestBody, kind: requestBodyKind)
    }

    public var formattedResponseBody: String? {
        NetworkInspectorBodyFormatter.formattedBody(body: responseBody, kind: responseBodyKind)
    }
}

public struct LogStreamerNetworkEntrySummary: Identifiable, Codable, Sendable {
    public let id: UUID
    public let requestMethod: String
    public let url: String
    public let host: String
    public let path: String
    public let endpoint: String
    public let startedAt: String
    public let finishedAt: String
    public let durationMs: Int
    public let responseStatusCode: Int?
    public let errorDescription: String?
    public let requestContentType: String?
    public let responseContentType: String?
    public let requestBodyPreview: String?
    public let responseBodyPreview: String?
    public let requestBodyKind: LogStreamerBodyContentKind
    public let responseBodyKind: LogStreamerBodyContentKind
    public let requestBodyBytes: Int
    public let responseBodyBytes: Int

    public init(entry: LogStreamerNetworkEntry) {
        let formattedRequestBody = entry.formattedRequestBody
        let formattedResponseBody = entry.formattedResponseBody

        self.id = entry.id
        self.requestMethod = entry.requestMethod
        self.url = entry.url
        self.host = entry.host
        self.path = entry.path
        self.endpoint = entry.endpoint
        self.startedAt = entry.startedAt
        self.finishedAt = entry.finishedAt
        self.durationMs = entry.durationMs
        self.responseStatusCode = entry.responseStatusCode
        self.errorDescription = entry.errorDescription
        self.requestContentType = entry.requestContentType
        self.responseContentType = entry.responseContentType
        self.requestBodyKind = entry.requestBodyKind
        self.responseBodyKind = entry.responseBodyKind
        self.requestBodyPreview = NetworkInspectorBodyFormatter.preview(for: formattedRequestBody, kind: requestBodyKind)
        self.responseBodyPreview = NetworkInspectorBodyFormatter.preview(for: formattedResponseBody, kind: responseBodyKind)
        self.requestBodyBytes = formattedRequestBody?.utf8.count ?? 0
        self.responseBodyBytes = formattedResponseBody?.utf8.count ?? 0
    }

    public var statusSummary: String {
        if let responseStatusCode {
            return String(responseStatusCode)
        }
        return errorDescription == nil ? "Pending" : "Error"
    }
}

private struct NetworkInspectorSessionExport: Codable {
    let exportedAt: String
    let settings: LogStreamerNetworkInspectorSettings
    let entries: [LogStreamerNetworkEntry]
}

enum NetworkInspectorBodyFormatter {
    private static let previewLineLimit = 6
    private static let previewCharacterLimit = 900

    static func contentType(from headers: [String: String]) -> String? {
        headers.first { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }?.value
    }

    static func detectKind(body: String?, contentType: String?) -> LogStreamerBodyContentKind {
        guard let rawBody = body?.trimmingCharacters(in: .whitespacesAndNewlines), !rawBody.isEmpty else {
            return .none
        }

        let normalizedContentType = contentType?.lowercased() ?? ""
        if normalizedContentType.contains("application/json") || normalizedContentType.contains("+json") {
            return .json
        }
        if normalizedContentType.contains("text/html") || normalizedContentType.contains("application/xhtml") {
            return .html
        }
        if normalizedContentType.contains("xml") {
            return .xml
        }
        if normalizedContentType.hasPrefix("text/") {
            return .text
        }
        if normalizedContentType.hasPrefix("image/")
            || normalizedContentType.hasPrefix("audio/")
            || normalizedContentType.hasPrefix("video/")
            || normalizedContentType.contains("octet-stream") {
            return .binary
        }

        if rawBody.hasPrefix("{") || rawBody.hasPrefix("[") {
            return .json
        }
        let lowercasedBody = rawBody.lowercased()
        if lowercasedBody.hasPrefix("<!doctype html") || lowercasedBody.hasPrefix("<html") {
            return .html
        }
        if rawBody.hasPrefix("<?xml") {
            return .xml
        }
        return .text
    }

    static func formattedBody(body: String?, kind: LogStreamerBodyContentKind) -> String? {
        guard let body, !body.isEmpty else { return nil }
        switch kind {
        case .json:
            guard let data = body.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data),
                  JSONSerialization.isValidJSONObject(object),
                  let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
                  let prettyBody = String(data: prettyData, encoding: .utf8) else {
                return body
            }
            return prettyBody
        default:
            return body
        }
    }

    static func preview(for body: String?, kind: LogStreamerBodyContentKind) -> String? {
        guard let body, !body.isEmpty else { return nil }
        if kind == .binary {
            return "Binary content detected. Open details to inspect the raw payload."
        }

        let lines = body.components(separatedBy: .newlines)
        let linePreview = lines.prefix(previewLineLimit).joined(separator: "\n")
        let needsCharacterTrim = linePreview.count > previewCharacterLimit
        let trimmedPreview = needsCharacterTrim
            ? String(linePreview.prefix(previewCharacterLimit))
            : linePreview
        let wasTruncated = lines.count > previewLineLimit || body.count > trimmedPreview.count
        return wasTruncated ? trimmedPreview + "\n…" : trimmedPreview
    }
}

@MainActor
final class NetworkInspectorStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var summaries: [LogStreamerNetworkEntrySummary] = []
    private var settings = LogStreamerNetworkInspectorSettings()
    private var maxEntries = 200
    private var hasLoadedState = false

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func configure(maxEntries: Int, defaultSettings: LogStreamerNetworkInspectorSettings) {
        self.maxEntries = max(0, maxEntries)
        if !hasLoadedState {
            loadState(defaultSettings: defaultSettings)
            hasLoadedState = true
        }
        trimIfNeeded()
        persistIndex()
    }

    func append(_ entry: LogStreamerNetworkEntry) {
        guard maxEntries > 0 else { return }
        guard shouldCapture(entry) else { return }
        do {
            let formattedEntry = LogStreamerNetworkEntry(
                id: entry.id,
                requestMethod: entry.requestMethod,
                url: entry.url,
                startedAt: entry.startedAt,
                finishedAt: entry.finishedAt,
                durationMs: entry.durationMs,
                requestHeaders: entry.requestHeaders,
                requestBody: entry.formattedRequestBody,
                responseStatusCode: entry.responseStatusCode,
                responseHeaders: entry.responseHeaders,
                responseBody: entry.formattedResponseBody,
                errorDescription: entry.errorDescription
            )
            try writeEntry(formattedEntry)
            summaries.insert(LogStreamerNetworkEntrySummary(entry: formattedEntry), at: 0)
            trimIfNeeded()
            persistIndex()
            notifyDidChange()
        } catch {
            print("LogStreamer network inspector append failed: \(error)")
        }
    }

    func snapshot() -> [LogStreamerNetworkEntry] {
        summaries.compactMap { loadEntry(id: $0.id) }
    }

    func snapshotSummaries() -> [LogStreamerNetworkEntrySummary] {
        summaries
    }

    func entry(id: UUID) -> LogStreamerNetworkEntry? {
        loadEntry(id: id)
    }

    func settingsSnapshot() -> LogStreamerNetworkInspectorSettings {
        settings
    }

    func updateSettings(_ newSettings: LogStreamerNetworkInspectorSettings) {
        let normalized = newSettings.normalized()
        let ignoredHostsChanged = Set(normalized.ignoredHosts) != Set(settings.ignoredHosts)
        settings = normalized
        persistSettings()
        if ignoredHostsChanged {
            pruneIgnoredHosts()
        }
        notifyDidChange()
    }

    func clear() {
        summaries.forEach { deleteEntryFile(id: $0.id) }
        summaries.removeAll()
        persistIndex()
        notifyDidChange()
    }

    func clearAllPersistentData() {
        clear()
        settings = LogStreamerNetworkInspectorSettings()
        try? FileManager.default.removeItem(at: settingsURL)
    }

    func resetForTesting() {
        clearAllPersistentData()
        summaries.removeAll()
        settings = LogStreamerNetworkInspectorSettings()
        maxEntries = 200
        hasLoadedState = false
    }

    func exportEntry(id: UUID) -> URL? {
        guard let entry = loadEntry(id: id),
              let data = try? encoder.encode(entry) else {
            return nil
        }
        return writeExportFile(named: "\(entry.requestMethod.lowercased())-\(entry.id.uuidString).json", data: data)
    }

    func exportSession() -> URL? {
        let payload = NetworkInspectorSessionExport(
            exportedAt: SharedDateFormatter.iso8601.string(from: Date()),
            settings: settings,
            entries: snapshot()
        )
        guard let data = try? encoder.encode(payload) else { return nil }
        return writeExportFile(named: "logstreamer-network-session.json", data: data)
    }

    private func loadState(defaultSettings: LogStreamerNetworkInspectorSettings) {
        ensureDirectories()
        settings = (loadSettings() ?? defaultSettings).normalized()
        summaries = loadIndex() ?? rebuildIndexFromEntriesDirectory()
        if settings.resetOnAppLaunch {
            summaries.forEach { deleteEntryFile(id: $0.id) }
            summaries.removeAll()
        }
        trimIfNeeded()
        persistSettings()
        persistIndex()
    }

    private func shouldCapture(_ entry: LogStreamerNetworkEntry) -> Bool {
        let host = entry.host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !settings.ignoredHosts.contains(host)
    }

    private func pruneIgnoredHosts() {
        let ignoredHosts = Set(settings.ignoredHosts)
        let removedIds = summaries
            .filter { ignoredHosts.contains($0.host.lowercased()) }
            .map(\.id)
        summaries.removeAll { ignoredHosts.contains($0.host.lowercased()) }
        removedIds.forEach(deleteEntryFile(id:))
        persistIndex()
    }

    private func trimIfNeeded() {
        guard summaries.count > maxEntries else { return }
        let removed = Array(summaries.dropFirst(maxEntries))
        summaries = Array(summaries.prefix(maxEntries))
        removed.forEach { deleteEntryFile(id: $0.id) }
    }

    private func writeEntry(_ entry: LogStreamerNetworkEntry) throws {
        ensureDirectories()
        let data = try encoder.encode(entry)
        try data.write(to: entryURL(for: entry.id), options: .atomic)
    }

    private func loadEntry(id: UUID) -> LogStreamerNetworkEntry? {
        guard let data = try? Data(contentsOf: entryURL(for: id)) else { return nil }
        return try? decoder.decode(LogStreamerNetworkEntry.self, from: data)
    }

    private func loadIndex() -> [LogStreamerNetworkEntrySummary]? {
        guard let data = try? Data(contentsOf: indexURL) else { return nil }
        return try? decoder.decode([LogStreamerNetworkEntrySummary].self, from: data)
    }

    private func loadSettings() -> LogStreamerNetworkInspectorSettings? {
        guard let data = try? Data(contentsOf: settingsURL) else { return nil }
        return try? decoder.decode(LogStreamerNetworkInspectorSettings.self, from: data)
    }

    private func rebuildIndexFromEntriesDirectory() -> [LogStreamerNetworkEntrySummary] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: entriesDirectoryURL,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let entries = urls.compactMap { url -> LogStreamerNetworkEntry? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(LogStreamerNetworkEntry.self, from: data)
        }

        return entries
            .sorted { $0.startedAt > $1.startedAt }
            .map(LogStreamerNetworkEntrySummary.init(entry:))
    }

    private func persistIndex() {
        ensureDirectories()
        guard let data = try? encoder.encode(summaries) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    private func persistSettings() {
        ensureDirectories()
        guard let data = try? encoder.encode(settings) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }

    private func writeExportFile(named fileName: String, data: Data) -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LogStreamerExports", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func deleteEntryFile(id: UUID) {
        try? FileManager.default.removeItem(at: entryURL(for: id))
    }

    private func ensureDirectories() {
        try? FileManager.default.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: entriesDirectoryURL, withIntermediateDirectories: true)
    }

    private func entryURL(for id: UUID) -> URL {
        entriesDirectoryURL.appendingPathComponent("\(id.uuidString).json")
    }

    private var rootDirectoryURL: URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return applicationSupport.appendingPathComponent("LogStreamer/network-inspector", isDirectory: true)
    }

    private var entriesDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent("entries", isDirectory: true)
    }

    private var indexURL: URL {
        rootDirectoryURL.appendingPathComponent("index.json")
    }

    private var settingsURL: URL {
        rootDirectoryURL.appendingPathComponent("settings.json")
    }

    private func notifyDidChange() {
        NotificationCenter.default.post(name: .logStreamerNetworkInspectorDidChange, object: nil)
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
