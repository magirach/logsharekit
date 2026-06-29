import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Lightweight snapshot used by the example app and integrators for troubleshooting.
public struct LogStreamerDebugSnapshot: Sendable {
    public var sessionId: String?
    public var state: String
    public var bufferedEvents: Int
    public var lastError: String?

    /// Captures the current runtime state without exposing internal implementation types.
    /// - Parameters:
    ///   - sessionId: The active session identifier, if one exists.
    ///   - state: The current runtime state as a string value.
    ///   - bufferedEvents: The number of events still waiting for upload.
    ///   - lastError: The last runtime error surfaced by the SDK, if any.
    public init(sessionId: String?, state: String, bufferedEvents: Int, lastError: String?) {
        self.sessionId = sessionId
        self.state = state
        self.bufferedEvents = bufferedEvents
        self.lastError = lastError
    }
}

@MainActor
public enum LogStreamer {
    private static let runtime = LogStreamerRuntime.shared

    /// Entry point for writing app-level logs into the active streaming session.
    public static let logger: LogStreamerLogger = AppLogger()

    /// Boots the singleton runtime and wires the upload client, redaction rules, and persisted session state.
    /// - Parameter config: The host application configuration used to initialize the SDK.
    public static func initialize(config: LogStreamerConfig) {
        runtime.initialize(config: config)
    }

    /// Handles a parsed APNs payload asynchronously.
    /// - Parameter userInfo: The raw APNs `userInfo` dictionary delivered by the application.
    public static func handlePush(userInfo: [AnyHashable: Any]) async {
        await runtime.handlePush(userInfo: userInfo)
    }

    @discardableResult
    /// Synchronously checks whether the payload looks like a LogStreamer push before dispatching async handling.
    /// - Parameter userInfo: The raw APNs `userInfo` dictionary delivered by the application.
    /// - Returns: `true` when the payload parses as a LogStreamer command, otherwise `false`.
    public static func handleRemoteNotification(userInfo: [AnyHashable: Any]) -> Bool {
        do {
            _ = try PushPayloadParser.parse(userInfo: userInfo)
            Task { await runtime.handlePush(userInfo: userInfo) }
            return true
        } catch {
            Task { await runtime.handlePush(userInfo: userInfo) }
            return false
        }
    }

    /// Defers the host app's APNs completion callback until LogStreamer finishes processing the push.
    /// - Parameters:
    ///   - userInfo: The raw APNs `userInfo` dictionary delivered by the application.
    ///   - completion: Called with `true` when the payload matched a LogStreamer command.
    public static func handleRemoteNotification(
        userInfo: [AnyHashable: Any],
        completion: @escaping (Bool) -> Void
    ) {
        Task {
            do {
                _ = try PushPayloadParser.parse(userInfo: userInfo)
                await runtime.handlePush(userInfo: userInfo)
                completion(true)
            } catch {
                await runtime.handlePush(userInfo: userInfo)
                completion(false)
            }
        }
    }

    /// Converts the APNs device token into the hex string expected by the backend session API.
    /// - Parameter deviceToken: The binary device token returned by APNs registration.
    /// - Returns: A lowercase hexadecimal token string suitable for the backend session API.
    public static func deviceTokenString(from deviceToken: Data) -> String {
        deviceToken.map { String(format: "%02x", $0) }.joined()
    }

    /// Resumes an accepted session when the app returns to foreground.
    public static func applicationDidBecomeActive() async {
        await runtime.applicationDidBecomeActive()
    }

    /// Pauses foreground-only capture when the app leaves the foreground.
    public static func applicationDidEnterBackground() async {
        await runtime.applicationDidEnterBackground()
    }

    /// Flushes buffered events before the process exits.
    public static func applicationWillTerminate() async {
        await runtime.applicationWillTerminate()
    }

    /// Creates a URLSession that routes traffic through the instrumented URLProtocol once.
    /// - Parameters:
    ///   - configuration: The session configuration to instrument.
    ///   - delegate: The session delegate to attach to the created session.
    ///   - delegateQueue: The operation queue used for delegate callbacks.
    /// - Returns: A URL session that records request and response activity for active LogStreamer sessions.
    public static func makeInstrumentedSession(
        configuration: URLSessionConfiguration = .default,
        delegate: URLSessionDelegate? = nil,
        delegateQueue: OperationQueue? = nil
    ) -> URLSession {
        InstrumentedURLSessionFactory.makeSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: delegateQueue
        )
    }

    /// Returns a debug view of the singleton runtime for local inspection and sample UI.
    /// - Returns: A snapshot of the active runtime state and last surfaced error.
    public static func debugSnapshot() async -> LogStreamerDebugSnapshot {
        runtime.debugSnapshot()
    }

    /// Returns locally captured network inspector entries in reverse chronological order.
    public static func networkEntries() async -> [LogStreamerNetworkEntry] {
        runtime.networkEntries()
    }

    /// Clears locally captured network inspector entries.
    public static func clearNetworkEntries() async {
        runtime.clearNetworkEntries()
    }
}
