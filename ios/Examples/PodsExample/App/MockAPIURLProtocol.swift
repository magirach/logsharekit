import Foundation

final class MockAPIURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "api.example.local"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        let route = makeRoute(for: request, url: url)
        let response = HTTPURLResponse(
            url: url,
            statusCode: route.statusCode,
            httpVersion: nil,
            headerFields: route.headers
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: route.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private func makeRoute(for request: URLRequest, url: URL) -> MockRoute {
        let method = request.httpMethod?.uppercased() ?? "GET"
        switch (method, url.path) {
        case ("GET", "/demo/json"):
            let payload = """
            {"feature":"demo-json","status":"ok","timestamp":"\(ISO8601DateFormatter().string(from: Date()))","source":"pods-example"}
            """
            return MockRoute(
                statusCode: 200,
                headers: ["Content-Type": "application/json"],
                body: Data(payload.utf8)
            )

        case ("POST", "/demo/orders"):
            let requestBody = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
            let payload = """
            {"feature":"demo-post","received":\(requestBody.isEmpty ? "null" : requestBody),"message":"Order accepted"}
            """
            return MockRoute(
                statusCode: 201,
                headers: ["Content-Type": "application/json", "X-Demo-Flow": "create-order"],
                body: Data(payload.utf8)
            )

        case ("GET", "/demo/page"):
            let html = """
            <!doctype html>
            <html>
            <head><title>Mock HTML</title></head>
            <body>
            <h1>Network Inspector HTML Preview</h1>
            <p>This mocked endpoint returns renderable HTML.</p>
            </body>
            </html>
            """
            return MockRoute(
                statusCode: 200,
                headers: ["Content-Type": "text/html; charset=utf-8"],
                body: Data(html.utf8)
            )

        case ("GET", "/demo/text"):
            let text = """
            Demo text response
            line 2
            line 3
            """
            return MockRoute(
                statusCode: 200,
                headers: ["Content-Type": "text/plain; charset=utf-8"],
                body: Data(text.utf8)
            )

        case ("GET", "/demo/file"):
            return MockRoute(
                statusCode: 200,
                headers: ["Content-Type": "application/octet-stream"],
                body: Data([0xDE, 0xAD, 0xBE, 0xEF, 0x01, 0x02, 0x03, 0x04])
            )

        case ("GET", "/demo/missing"):
            let payload = """
            {"feature":"demo-error","error":"Resource not found","path":"\(url.path)"}
            """
            return MockRoute(
                statusCode: 404,
                headers: ["Content-Type": "application/json"],
                body: Data(payload.utf8)
            )

        default:
            let payload = """
            {"error":"Unhandled mock route","method":"\(method)","path":"\(url.path)"}
            """
            return MockRoute(
                statusCode: 400,
                headers: ["Content-Type": "application/json"],
                body: Data(payload.utf8)
            )
        }
    }
}

private struct MockRoute {
    let statusCode: Int
    let headers: [String: String]
    let body: Data
}
