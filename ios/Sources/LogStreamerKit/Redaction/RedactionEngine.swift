import Foundation

/// Applies simple key-based redaction before logs leave the device.
final class RedactionEngine {
    private let redactedKeys: Set<String>

    /// Normalizes configured keys once so later lookups stay cheap and case-insensitive.
    /// - Parameter redactedKeys: The case-insensitive keys whose values should be masked before upload.
    init(redactedKeys: Set<String>) {
        self.redactedKeys = Set(redactedKeys.map { $0.lowercased() })
    }

    /// Redacts sensitive header values while preserving original header names for debugging.
    /// - Parameter headers: The HTTP headers captured from the request or response.
    /// - Returns: A copy of the headers with configured keys replaced by `[REDACTED]`.
    func redact(headers: [String: String]) -> [String: String] {
        headers.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = redactedKeys.contains(entry.key.lowercased()) ? "[REDACTED]" : entry.value
        }
    }

    /// Applies the same key-driven masking policy to free-form metadata.
    /// - Parameter metadata: Arbitrary key-value metadata attached to a log event.
    /// - Returns: A copy of the metadata with configured keys replaced by `[REDACTED]`.
    func redactMetadata(_ metadata: [String: String]) -> [String: String] {
        metadata.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = redactedKeys.contains(entry.key.lowercased()) ? "[REDACTED]" : entry.value
        }
    }

    /// Recursively walks JSON payloads so nested objects and arrays are redacted before upload.
    /// - Parameter payload: The JSON payload captured from a request or response body.
    /// - Returns: A redacted copy of the payload, or `nil` when no payload is present.
    func redactPayload(_ payload: JSONValue?) -> JSONValue? {
        guard let payload else { return nil }
        switch payload {
        case .object(let object):
            let redactedObject = object.reduce(into: [String: JSONValue]()) { partialResult, entry in
                partialResult[entry.key] = redactedKeys.contains(entry.key.lowercased()) ? .string("[REDACTED]") : (redactPayload(entry.value) ?? .null)
            }
            return .object(redactedObject)
        case .array(let array):
            return .array(array.map { redactPayload($0) ?? .null })
        default:
            return payload
        }
    }
}
