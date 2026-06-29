import Foundation

enum ClientSessionState: String, Codable {
    case idle
    case pendingConsent
    case consentAccepted
    case active
    case paused
    case stopping
    case completed
    case cancelled
}

enum PushCommand: String, Codable {
    case startLogging = "start_logging"
    case stopLogging = "stop_logging"
}

struct StopPolicy: Codable {
    let expiresAfterMinutes: Int
    let maxEvents: Int?
    let maxBytes: Int?
}

struct StartSessionPayload: Codable {
    let command: PushCommand
    let sessionId: String
    let uploadToken: String
    let baseURL: String?
    let appId: String
    let environment: String
    let userId: String?
    let logs: [String]?
    let logLevel: String?
    let captureNetworkBodies: Bool?
    let retentionHours: Int
    let stopPolicy: StopPolicy
    let issuedAt: String?
    let expiresAt: String?
    let signature: String?

    enum CodingKeys: String, CodingKey {
        case command
        case sessionId
        case uploadToken
        case baseURL = "baseUrl"
        case appId
        case environment
        case userId
        case logs
        case logLevel
        case captureNetworkBodies
        case retentionHours
        case stopPolicy
        case issuedAt
        case expiresAt
        case signature
    }
}

struct StopSessionPayload: Codable {
    let command: PushCommand
    let sessionId: String
    let issuedAt: String?
    let signature: String?
}

struct PersistedSession: Codable {
    let sessionId: String
    let uploadToken: String
    let uploadBaseURL: String?
    let appId: String
    let environment: String
    var state: ClientSessionState
    let consentAccepted: Bool
    let captureNetworkBodies: Bool
    let stopPolicy: StopPolicy
    let startedAt: String
    var lastUpdatedAt: String
}

enum LogSeverity: String, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

enum LogEventType: String, Codable {
    case app
    case networkRequest
    case networkResponse
    case lifecycle
}

enum JSONValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case object([String: JSONValue])
    case array([JSONValue])
    case bool(Bool)
    case null

    /// Converts a Foundation value into the SDK's JSON-safe enum representation.
    /// - Parameter value: The Foundation value to normalize into a JSON-compatible shape.
    init(any value: Any) {
        switch value {
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.doubleValue)
            }
        case let object as [String: Any]:
            self = .object(object.mapValues(JSONValue.init(any:)))
        case let array as [Any]:
            self = .array(array.map(JSONValue.init(any:)))
        default:
            self = .string(String(describing: value))
        }
    }

    /// Decodes a JSON value into the SDK's enum representation.
    /// - Parameter decoder: The decoder positioned at a single JSON value.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    /// Encodes the enum back into its JSON representation.
    /// - Parameter encoder: The encoder that receives the JSON value.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

struct LogEvent: Codable, Sendable {
    let eventId: String
    let sessionId: String
    let timestamp: String
    let type: LogEventType
    let level: String?
    let component: String
    let message: String?
    let metadata: [String: String]
    let payload: JSONValue?

    /// Estimates the memory and payload footprint of the event for batching decisions.
    /// - Returns: A rough byte estimate used by the local batch buffer.
    var approximateSize: Int {
        let metadataSize = metadata.reduce(0) { $0 + $1.key.count + $1.value.count }
        let messageSize = message?.count ?? 0
        let payloadSize: Int
        switch payload {
        case .string(let string):
            payloadSize = string.count
        case .object(let object):
            payloadSize = object.description.count
        case .array(let array):
            payloadSize = array.description.count
        case .number, .bool, .null, .none:
            payloadSize = 32
        }
        return eventId.count + sessionId.count + component.count + metadataSize + messageSize + payloadSize + 128
    }
}

struct EventBatchRequest: Codable {
    let sentAt: String
    let events: [UploadLogEvent]
}

struct UploadLogEvent: Codable, Sendable {
    let eventId: String
    let timestamp: String
    let type: LogEventType
    let level: String?
    let component: String
    let message: String?
    let metadata: [String: String]
    let payload: JSONValue?

    /// Converts a locally buffered event into the backend upload shape.
    /// - Parameter event: The buffered event to normalize for upload.
    init(event: LogEvent) {
        self.eventId = event.eventId
        self.timestamp = event.timestamp
        self.type = event.type
        self.level = event.level
        self.component = event.component
        self.message = event.message
        self.metadata = event.metadata
        self.payload = event.payload
    }
}

struct UploadAck: Codable {
    let accepted: Int?
    let rejected: Int?
    let status: String?
}
