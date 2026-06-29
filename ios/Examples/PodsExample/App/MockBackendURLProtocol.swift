import Foundation

struct BackendSnapshot {
    var consentShownCount: Int
    var cancelCount: Int
    var uploadBatchCount: Int
    var uploadedEventCount: Int
    var lastPath: String?
}

final class MockBackendURLProtocol: URLProtocol {
    private static var state = BackendSnapshot(
        consentShownCount: 0,
        cancelCount: 0,
        uploadBatchCount: 0,
        uploadedEventCount: 0,
        lastPath: nil
    )
    private static let lock = NSLock()

    static func snapshot() -> BackendSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "mock.logstreamer.local"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url?.path ?? "/"
        Self.lock.lock()
        Self.state.lastPath = path
        if path.hasSuffix("/consent-shown") {
            Self.state.consentShownCount += 1
        } else if path.hasSuffix("/cancel") {
            Self.state.cancelCount += 1
        } else if path.hasSuffix("/events"),
                  let body = request.httpBody,
                  let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  let events = object["events"] as? [Any] {
            Self.state.uploadBatchCount += 1
            Self.state.uploadedEventCount += events.count
        }
        Self.lock.unlock()

        let payload = "{\"accepted\":1,\"rejected\":0,\"status\":\"ACTIVE\"}".data(using: .utf8) ?? Data()
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "http://127.0.0.1:8080")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: payload)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
