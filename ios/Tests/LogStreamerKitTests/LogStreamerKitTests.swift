import XCTest
@testable import LogStreamerKit

final class LogStreamerKitTests: XCTestCase {
    override func tearDown() {
        Task { @MainActor in
            LogStreamerRuntime.shared.resetForTesting()
        }
        super.tearDown()
    }

    func testRedactionMasksConfiguredKeys() {
        let engine = RedactionEngine(redactedKeys: ["authorization", "password"])
        let headers = engine.redact(headers: ["Authorization": "secret", "Accept": "application/json"])
        XCTAssertEqual(headers["Authorization"], "[REDACTED]")
        XCTAssertEqual(headers["Accept"], "application/json")
    }

    func testParserDecodesStartPush() throws {
        let payload: [AnyHashable: Any] = [
            "aps": [
                "content-available": 1
            ],
            "data": [
                "command": "start_logging",
                "sessionId": "sess_1",
                "uploadToken": "token",
                "baseUrl": "http://10.0.0.5:8080",
                "appId": "consumer-ios",
                "environment": "debug",
                "userId": "user-1",
                "logs": ["network", "logs"],
                "retentionHours": 24,
                "stopPolicy": [
                    "expiresAfterMinutes": 15,
                    "maxEvents": NSNull(),
                    "maxBytes": NSNull()
                ]
            ]
        ]

        let parsed = try PushPayloadParser.parse(userInfo: payload)
        switch parsed {
        case .start(let start):
            XCTAssertEqual(start.sessionId, "sess_1")
            XCTAssertEqual(start.logs, ["network", "logs"])
            XCTAssertEqual(start.baseURL, "http://10.0.0.5:8080")
        case .stop:
            XCTFail("Expected start payload")
        }
    }

    func testEventBatchEncodingOmitsSessionId() throws {
        let request = EventBatchRequest(
            sentAt: "2026-06-28T00:00:00Z",
            events: [
                UploadLogEvent(event: LogEvent(
                    eventId: "evt_1",
                    sessionId: "sess_1",
                    timestamp: "2026-06-28T00:00:00Z",
                    type: .app,
                    level: "INFO",
                    component: "Example",
                    message: "Hello",
                    metadata: ["key": "value"],
                    payload: .object(["foo": .string("bar")])
                ))
            ]
        )

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
        )
        XCTAssertNil(json["sessionId"])

        let events = try XCTUnwrap(json["events"] as? [[String: Any]])
        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events[0]["sessionId"])
        XCTAssertEqual(events[0]["eventId"] as? String, "evt_1")
    }

    func testUploadClientErrorDescriptionIncludesStatusAndBody() {
        let error = UploadClientError.invalidResponse(
            statusCode: 400,
            body: "{\"code\":\"INVALID_REQUEST\"}"
        )

        XCTAssertEqual(
            error.localizedDescription,
            "status 400, body {\"code\":\"INVALID_REQUEST\"}"
        )
    }

    @MainActor
    func testBackgroundStartPushPersistsPendingConsentSession() async {
        LogStreamerRuntime.shared.resetForTesting()
        LogStreamer.initialize(config: makeTestConfig())
        await LogStreamer.applicationDidEnterBackground()
        await LogStreamer.handlePush(userInfo: startPushPayload(sessionId: "sess_bg"))

        let snapshot = await LogStreamer.debugSnapshot()
        XCTAssertEqual(snapshot.sessionId, "sess_bg")
        XCTAssertEqual(snapshot.state, "pendingConsent")
        XCTAssertNil(snapshot.lastError)
    }

    @MainActor
    func testStopPushClearsPendingConsentSession() async {
        LogStreamerRuntime.shared.resetForTesting()
        LogStreamer.initialize(config: makeTestConfig())
        await LogStreamer.applicationDidEnterBackground()
        await LogStreamer.handlePush(userInfo: startPushPayload(sessionId: "sess_bg_stop"))
        await LogStreamer.handlePush(userInfo: stopPushPayload(sessionId: "sess_bg_stop"))

        let snapshot = await LogStreamer.debugSnapshot()
        XCTAssertNil(snapshot.sessionId)
        XCTAssertEqual(snapshot.state, "idle")
    }

    @MainActor
    func testNetworkInspectorCapturesInstrumentedRequest() async throws {
        LogStreamerRuntime.shared.resetForTesting()
        LogStreamer.initialize(config: makeTestConfig())

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubInspectorURLProtocol.self]
        let session = LogStreamer.makeInstrumentedSession(configuration: configuration)

        let expectation = expectation(description: "network request completes")
        var request = URLRequest(url: URL(string: "https://example.logstreamer.local/hello?source=test")!)
        request.httpMethod = "POST"
        request.httpBody = #"{"message":"hello"}"#.data(using: .utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        session.dataTask(with: request) { _, _, _ in
            expectation.fulfill()
        }.resume()

        await fulfillment(of: [expectation], timeout: 2.0)

        let entries = await LogStreamer.networkEntries()
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.requestMethod, "POST")
        XCTAssertEqual(entry.responseStatusCode, 200)
        XCTAssertTrue(entry.url.contains("/hello"))
        XCTAssertEqual(entry.requestHeaders["Content-Type"], "application/json")
        XCTAssertTrue(entry.responseBody?.contains("\"ok\"") == true)
        XCTAssertTrue(entry.curlCommand.contains("curl -X POST"))
    }

    private func makeTestConfig() -> LogStreamerConfig {
        LogStreamerConfig(
            baseURL: URL(string: "https://example.logstreamer.local")!,
            appId: "test-ios",
            environment: "test",
            uploadSessionFactory: {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [StubUploadURLProtocol.self]
                return URLSession(configuration: configuration)
            }
        )
    }

    private func startPushPayload(sessionId: String) -> [AnyHashable: Any] {
        [
            "aps": [
                "content-available": 1
            ],
            "data": [
                "command": "start_logging",
                "sessionId": sessionId,
                "uploadToken": "token-\(sessionId)",
                "baseUrl": "https://example.logstreamer.local",
                "appId": "consumer-ios",
                "environment": "debug",
                "userId": "user-1",
                "logs": ["network", "logs"],
                "retentionHours": 24,
                "stopPolicy": [
                    "expiresAfterMinutes": 15,
                    "maxEvents": NSNull(),
                    "maxBytes": NSNull()
                ]
            ]
        ]
    }

    private func stopPushPayload(sessionId: String) -> [AnyHashable: Any] {
        [
            "aps": [
                "content-available": 1
            ],
            "data": [
                "command": "stop_logging",
                "sessionId": sessionId
            ]
        ]
    }
}

private final class StubUploadURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.logstreamer.local")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class StubInspectorURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let data = #"{"ok":true,"source":"inspector"}"#.data(using: .utf8) ?? Data()
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.logstreamer.local")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
