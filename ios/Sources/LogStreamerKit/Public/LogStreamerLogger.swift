import Foundation

/// Minimal logging surface exposed to host apps.
public protocol LogStreamerLogger {
    /// Records a debug log for the current active session.
    /// - Parameters:
    ///   - message: The human-readable log message.
    ///   - component: The logical component or feature emitting the log.
    ///   - metadata: Additional string metadata to attach to the event.
    func debug(_ message: String, component: String, metadata: [String: String])
    /// Records an informational log for the current active session.
    /// - Parameters:
    ///   - message: The human-readable log message.
    ///   - component: The logical component or feature emitting the log.
    ///   - metadata: Additional string metadata to attach to the event.
    func info(_ message: String, component: String, metadata: [String: String])
    /// Records a warning log for the current active session.
    /// - Parameters:
    ///   - message: The human-readable log message.
    ///   - component: The logical component or feature emitting the log.
    ///   - metadata: Additional string metadata to attach to the event.
    func warn(_ message: String, component: String, metadata: [String: String])
    /// Records an error log for the current active session.
    /// - Parameters:
    ///   - message: The human-readable log message.
    ///   - component: The logical component or feature emitting the log.
    ///   - metadata: Additional string metadata to attach to the event.
    func error(_ message: String, component: String, metadata: [String: String])
}
