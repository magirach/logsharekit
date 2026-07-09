import Foundation

/// Copy shown to the user before a server-started logging session begins.
public struct ConsentCopy {
    public var title: String
    public var message: String
    public var acceptButtonTitle: String
    public var declineButtonTitle: String

    /// Allows host apps to replace the consent wording without changing the consent flow itself.
    /// - Parameters:
    ///   - title: The dialog title shown to the user.
    ///   - message: The body copy explaining what will be captured.
    ///   - acceptButtonTitle: The label used for the positive action.
    ///   - declineButtonTitle: The label used for the negative action.
    public init(
        title: String = "Share Diagnostic Logs?",
        message: String = "This session will collect app and network logs while you use the app in foreground.",
        acceptButtonTitle: String = "Allow",
        declineButtonTitle: String = "Decline"
    ) {
        self.title = title
        self.message = message
        self.acceptButtonTitle = acceptButtonTitle
        self.declineButtonTitle = declineButtonTitle
    }
}

/// Controls how aggressively buffered events are flushed to the backend.
public struct BatchPolicy {
    public var flushInterval: TimeInterval
    public var maxEvents: Int
    public var maxApproximateBytes: Int

    /// Keeps upload frequency configurable without exposing buffer internals to integrators.
    /// - Parameters:
    ///   - flushInterval: The maximum number of seconds to wait before forcing a flush.
    ///   - maxEvents: The maximum number of events to include in one upload batch.
    ///   - maxApproximateBytes: The approximate payload size threshold that triggers an upload.
    public init(
        flushInterval: TimeInterval = 2,
        maxEvents: Int = 100,
        maxApproximateBytes: Int = 512 * 1_024
    ) {
        self.flushInterval = flushInterval
        self.maxEvents = maxEvents
        self.maxApproximateBytes = maxApproximateBytes
    }
}

/// Top-level SDK configuration supplied once during app startup.
public struct LogStreamerConfig {
    public var baseURL: URL
    public var appId: String
    public var environment: String
    public var consentCopy: ConsentCopy
    public var redactedKeys: Set<String>
    public var batchPolicy: BatchPolicy
    public var networkInspectorMaxEntries: Int
    public var networkInspectorSettings: LogStreamerNetworkInspectorSettings
    public var additionalHeaders: [String: String]
    public var deviceId: String?
    public var installationId: String?
    public var userId: String?
    public var uploadSessionFactory: () -> URLSession

    /// The backend may override `baseURL` per session via push, but this remains the default for local bootstrapping.
    /// - Parameters:
    ///   - baseURL: The default backend base URL used before any push-supplied override is received.
    ///   - appId: The application identifier sent with callbacks and uploads.
    ///   - environment: The logical app environment, such as debug or production.
    ///   - consentCopy: The user-facing copy used in the consent alert.
    ///   - redactedKeys: The case-insensitive keys that should be masked before upload.
    ///   - batchPolicy: The local buffering and flush policy for event uploads.
    ///   - networkInspectorMaxEntries: The maximum number of captured network entries kept for in-app inspection.
    ///   - networkInspectorSettings: Persistent network inspector preferences such as ignored hosts and reset behavior.
    ///   - additionalHeaders: Additional HTTP headers appended to outbound mobile requests.
    ///   - deviceId: An optional device identifier forwarded to the backend.
    ///   - installationId: An optional installation identifier forwarded to the backend.
    ///   - userId: An optional user identifier stored in local config for host app use.
    ///   - uploadSessionFactory: A factory that creates the URLSession used for backend callbacks and uploads.
    public init(
        baseURL: URL,
        appId: String,
        environment: String,
        consentCopy: ConsentCopy = ConsentCopy(),
        redactedKeys: Set<String> = ["authorization", "token", "password", "secret", "cookie", "set-cookie"],
        batchPolicy: BatchPolicy = BatchPolicy(),
        networkInspectorMaxEntries: Int = 200,
        networkInspectorSettings: LogStreamerNetworkInspectorSettings = LogStreamerNetworkInspectorSettings(),
        additionalHeaders: [String: String] = [:],
        deviceId: String? = nil,
        installationId: String? = nil,
        userId: String? = nil,
        uploadSessionFactory: @escaping () -> URLSession = {
            URLSession(configuration: .default)
        }
    ) {
        self.baseURL = baseURL
        self.appId = appId
        self.environment = environment
        self.consentCopy = consentCopy
        self.redactedKeys = redactedKeys
        self.batchPolicy = batchPolicy
        self.networkInspectorMaxEntries = max(0, networkInspectorMaxEntries)
        self.networkInspectorSettings = networkInspectorSettings.normalized()
        self.additionalHeaders = additionalHeaders
        self.deviceId = deviceId
        self.installationId = installationId
        self.userId = userId
        self.uploadSessionFactory = uploadSessionFactory
    }
}
