import Foundation

enum SharedDateFormatter {
    /// Creates a fractional-second formatter each time to avoid cross-thread mutation concerns.
    /// - Returns: A freshly configured ISO8601 formatter with internet date-time and fractional seconds enabled.
    static var iso8601: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
