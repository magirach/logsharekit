import Foundation
import LogStreamerKit

@MainActor
final class ExampleViewModel: ObservableObject {
    @Published var snapshot = LogStreamerDebugSnapshot(sessionId: nil, state: "idle", bufferedEvents: 0, lastError: nil)
    @Published var backendSnapshot = MockBackendURLProtocol.snapshot()
    @Published var networkEntries: [LogStreamerNetworkEntry] = []

    private var refreshTask: Task<Void, Never>?

    func start() async {
        refreshTask?.cancel()
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    func simulateStartPush() async {
        let payload: [AnyHashable: Any] = [
            "aps": [
                "content-available": 1
            ],
            "data": [
                "command": "start_logging",
                "sessionId": "sess-demo-001",
                "uploadToken": "token-demo-001",
                "appId": "spm-example-ios",
                "environment": "debug",
                "userId": "user-demo-spm",
                "logs": ["network", "logs"],
                "retentionHours": 24,
                "stopPolicy": [
                    "expiresAfterMinutes": 15,
                    "maxEvents": NSNull(),
                    "maxBytes": NSNull()
                ]
            ]
        ]
        await LogStreamer.handlePush(userInfo: payload)
        await refresh()
    }

    func simulateStopPush() async {
        let sessionId = snapshot.sessionId ?? "sess-demo-001"
        let payload: [AnyHashable: Any] = [
            "aps": [
                "content-available": 1
            ],
            "data": [
                "command": "stop_logging",
                "sessionId": sessionId
            ]
        ]
        await LogStreamer.handlePush(userInfo: payload)
        await refresh()
    }

    func writeLog() {
        LogStreamer.logger.info(
            "User tapped Write App Log",
            component: "ContentView",
            metadata: ["screen": "example", "action": "write_log"]
        )
    }

    func runNetworkRequest() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockAPIURLProtocol.self]
        let session = LogStreamer.makeInstrumentedSession(configuration: configuration)
        let url = URL(string: "https://api.example.local/demo")!
        let task = session.dataTask(with: url) { _, _, _ in }
        task.resume()
    }

    private func refresh() async {
        snapshot = await LogStreamer.debugSnapshot()
        backendSnapshot = MockBackendURLProtocol.snapshot()
        networkEntries = await LogStreamer.networkEntries()
    }
}
