import Foundation

/// Normalized representation of the two APNs commands the SDK currently understands.
enum ParsedPushPayload {
    case start(StartSessionPayload)
    case stop(StopSessionPayload)
}

enum PushPayloadParser {
    /// Accepts either a flat payload or the nested `data` object used by the backend APNs envelope.
    /// - Parameter userInfo: The raw APNs `userInfo` payload delivered by the application.
    /// - Returns: A normalized LogStreamer push command ready for runtime handling.
    static func parse(userInfo: [AnyHashable: Any]) throws -> ParsedPushPayload {
        let dictionary = Dictionary(uniqueKeysWithValues: userInfo.compactMap { key, value -> (String, Any)? in
            guard let stringKey = key as? String else { return nil }
            return (stringKey, value)
        })
        let candidatePayload: [String: Any]
        // APNs delivery nests custom fields under `data`, while local debugging sometimes sends them at the top level.
        if let nestedData = dictionary["data"] as? [String: Any] {
            candidatePayload = nestedData
        } else {
            candidatePayload = dictionary
        }

        let data = try JSONSerialization.data(withJSONObject: candidatePayload, options: [])
        let commandContainer = try JSONDecoder().decode(CommandContainer.self, from: data)
        switch commandContainer.command {
        case .startLogging:
            return .start(try JSONDecoder().decode(StartSessionPayload.self, from: data))
        case .stopLogging:
            return .stop(try JSONDecoder().decode(StopSessionPayload.self, from: data))
        }
    }
}

private struct CommandContainer: Codable {
    let command: PushCommand
}
