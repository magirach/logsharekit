import Foundation

final class AppLogger: LogStreamerLogger {
    /// Dispatches onto the main-actor runtime without forcing callers to be async-aware.
    /// - Parameters:
    ///   - message: The human-readable log message.
    ///   - component: The logical component or feature emitting the log.
    ///   - metadata: Additional string metadata to attach to the event.
    func debug(_ message: String, component: String, metadata: [String: String]) {
        Task { await LogStreamerRuntime.shared.recordAppLog(level: .debug, message: message, component: component, metadata: metadata) }
    }

    /// Dispatches onto the main-actor runtime without forcing callers to be async-aware.
    /// - Parameters:
    ///   - message: The human-readable log message.
    ///   - component: The logical component or feature emitting the log.
    ///   - metadata: Additional string metadata to attach to the event.
    func info(_ message: String, component: String, metadata: [String: String]) {
        Task { await LogStreamerRuntime.shared.recordAppLog(level: .info, message: message, component: component, metadata: metadata) }
    }

    /// Dispatches onto the main-actor runtime without forcing callers to be async-aware.
    /// - Parameters:
    ///   - message: The human-readable log message.
    ///   - component: The logical component or feature emitting the log.
    ///   - metadata: Additional string metadata to attach to the event.
    func warn(_ message: String, component: String, metadata: [String: String]) {
        Task { await LogStreamerRuntime.shared.recordAppLog(level: .warn, message: message, component: component, metadata: metadata) }
    }

    /// Dispatches onto the main-actor runtime without forcing callers to be async-aware.
    /// - Parameters:
    ///   - message: The human-readable log message.
    ///   - component: The logical component or feature emitting the log.
    ///   - metadata: Additional string metadata to attach to the event.
    func error(_ message: String, component: String, metadata: [String: String]) {
        Task { await LogStreamerRuntime.shared.recordAppLog(level: .error, message: message, component: component, metadata: metadata) }
    }
}
