import Foundation

final class MockAPIURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "api.example.local"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let payload = """
        {"feature":"demo","status":"ok","timestamp":"\(ISO8601DateFormatter().string(from: Date()))"}
        """.data(using: .utf8) ?? Data()
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://api.example.local/demo")!,
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
