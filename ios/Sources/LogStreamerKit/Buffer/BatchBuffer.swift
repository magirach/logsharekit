import Foundation

/// In-memory queue used to batch events before upload.
final class BatchBuffer {
    private var events: [LogEvent] = []
    private var approximateBytes = 0

    /// Keeps a rough byte count so flush decisions do not require re-encoding the whole batch each time.
    /// - Parameter event: The event to append to the in-memory queue.
    func append(_ event: LogEvent) {
        events.append(event)
        approximateBytes += event.approximateSize
    }

    /// Used by the runtime for debug snapshots and flush threshold checks.
    /// - Returns: The number of queued events currently waiting for upload.
    func eventCount() -> Int {
        events.count
    }

    /// Returns the current rough payload size budget.
    /// - Returns: The approximate byte size of the queued events.
    func approximateSize() -> Int {
        approximateBytes
    }

    /// Builds the next upload batch without mutating the queue until the backend accepts it.
    /// - Parameters:
    ///   - maxEvents: The maximum number of events allowed in the batch.
    ///   - maxApproximateBytes: The approximate byte ceiling for the batch.
    /// - Returns: The next uploadable prefix of queued events.
    func takeBatch(maxEvents: Int, maxApproximateBytes: Int) -> [LogEvent] {
        guard !events.isEmpty else { return [] }

        var batch: [LogEvent] = []
        var size = 0
        for event in events {
            if !batch.isEmpty && (batch.count >= maxEvents || size + event.approximateSize > maxApproximateBytes) {
                break
            }
            batch.append(event)
            size += event.approximateSize
        }
        return batch
    }

    /// Removes only the acknowledged prefix so failed uploads can be retried intact.
    /// - Parameter count: The number of leading events acknowledged by the backend.
    func removeFirst(_ count: Int) {
        guard count > 0 else { return }
        let prefix = events.prefix(count)
        approximateBytes -= prefix.reduce(0) { $0 + $1.approximateSize }
        events.removeFirst(min(count, events.count))
    }

    /// Used when a session ends and local buffering should be discarded immediately.
    func removeAll() {
        events.removeAll()
        approximateBytes = 0
    }
}
