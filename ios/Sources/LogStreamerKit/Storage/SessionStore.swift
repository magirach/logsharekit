import Foundation

final class SessionStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Persists the active session under Application Support so it survives relaunches during an active server session.
    private var fileURL: URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = applicationSupport.appendingPathComponent("LogStreamer", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("active-session.json")
    }

    /// Drops unreadable state eagerly so a corrupted session file cannot wedge startup.
    /// - Returns: The previously persisted active session, or `nil` when nothing valid is stored.
    func load() -> PersistedSession? {
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        do {
            return try decoder.decode(PersistedSession.self, from: data)
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }

    /// Atomically replaces the stored session to avoid partial writes during relaunch-sensitive flows.
    /// - Parameter session: The active session state that should survive relaunch.
    func save(_ session: PersistedSession) throws {
        let data = try encoder.encode(session)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Clears local state once the server-driven session is no longer active on device.
    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
