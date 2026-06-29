import Foundation

enum InstrumentedURLSessionFactory {
    private static let protocolClassesKey = "LogStreamerProtocolClasses"
    private static let protocolClassesHeader = "X-LogStreamer-Protocol-Classes"

    /// Ensures the custom URLProtocol is inserted only once ahead of the host app's protocol chain.
    /// - Parameters:
    ///   - configuration: The base session configuration to instrument.
    ///   - delegate: The URL session delegate to attach to the created session.
    ///   - delegateQueue: The operation queue that receives delegate callbacks.
    /// - Returns: A URL session whose requests are intercepted by `InstrumentedURLProtocol`.
    static func makeSession(
        configuration: URLSessionConfiguration,
        delegate: URLSessionDelegate?,
        delegateQueue: OperationQueue?
    ) -> URLSession {
        let customProtocols = configuration.protocolClasses ?? []
        if !customProtocols.isEmpty {
            var headers = configuration.httpAdditionalHeaders ?? [:]
            headers[protocolClassesHeader] = customProtocols.map(NSStringFromClass).joined(separator: ",")
            configuration.httpAdditionalHeaders = headers
        }
        configuration.protocolClasses = [InstrumentedURLProtocol.self] + customProtocols.filter { $0 != InstrumentedURLProtocol.self }
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: delegateQueue)
    }

    static func protocolClassesPropertyKey() -> String {
        protocolClassesKey
    }

    static func protocolClassesHeaderKey() -> String {
        protocolClassesHeader
    }
}

final class InstrumentedURLProtocol: URLProtocol, @unchecked Sendable {
    private var activeTask: URLSessionDataTask?
    private let startedAt = Date()

    /// Prevents the protocol from re-intercepting the request it is already proxying.
    /// - Parameter request: The URL request being evaluated by the protocol system.
    /// - Returns: `true` when the request has not yet been handled by LogStreamer.
    override class func canInit(with request: URLRequest) -> Bool {
        URLProtocol.property(forKey: "LogStreamerHandled", in: request) == nil
    }

    /// Leaves request canonicalization untouched because the SDK is observing, not rewriting.
    /// - Parameter request: The original URL request.
    /// - Returns: The original request without modification.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    /// Proxies the request through a fresh URLSession and mirrors the response back to the original client.
    override func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        URLProtocol.setProperty(true, forKey: "LogStreamerHandled", in: mutableRequest)
        if let headerValue = request.value(forHTTPHeaderField: InstrumentedURLSessionFactory.protocolClassesHeaderKey()),
           let originalProtocols = protocolClasses(from: headerValue) {
            URLProtocol.setProperty(
                originalProtocols,
                forKey: InstrumentedURLSessionFactory.protocolClassesPropertyKey(),
                in: mutableRequest
            )
            mutableRequest.setValue(nil, forHTTPHeaderField: InstrumentedURLSessionFactory.protocolClassesHeaderKey())
        }
        let instrumentedRequest = mutableRequest as URLRequest

        let configuration = URLSessionConfiguration.default
        // Preserve any host app protocol classes except this one so behavior stays close to the original session.
        configuration.protocolClasses = (URLProtocol.property(
            forKey: InstrumentedURLSessionFactory.protocolClassesPropertyKey(),
            in: instrumentedRequest
        ) as? [AnyClass]) ?? requestProtocolClasses(from: instrumentedRequest)

        let session = URLSession(configuration: configuration)
        activeTask = session.dataTask(with: instrumentedRequest) { [weak self] data, response, error in
            guard let self else { return }
            let startedAt = self.startedAt
            let finishedAt = Date()

            if let response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data {
                self.client?.urlProtocol(self, didLoad: data)
            }
            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
            } else {
                self.client?.urlProtocolDidFinishLoading(self)
            }

            Task {
                await LogStreamerRuntime.shared.recordNetworkExchange(
                    request: instrumentedRequest,
                    response: response as? HTTPURLResponse,
                    responseBody: data,
                    error: error,
                    startedAt: startedAt,
                    finishedAt: finishedAt
                )
            }
        }
        activeTask?.resume()
    }

    /// Cancels the proxied network task when the original request is torn down.
    override func stopLoading() {
        activeTask?.cancel()
    }

    /// Falls back to the default protocol chain when no explicit classes were attached to the request.
    /// - Parameter request: The proxied request whose protocol chain should be preserved.
    /// - Returns: The protocol classes that should remain active for the downstream session.
    private func requestProtocolClasses(from request: URLRequest) -> [AnyClass] {
        var classes = (URLProtocol.property(
            forKey: InstrumentedURLSessionFactory.protocolClassesPropertyKey(),
            in: request
        ) as? [AnyClass]) ?? protocolClasses(
            from: request.value(forHTTPHeaderField: InstrumentedURLSessionFactory.protocolClassesHeaderKey())
        ) ?? (URLSessionConfiguration.default.protocolClasses ?? [])
        classes.removeAll { $0 == InstrumentedURLProtocol.self }
        return classes
    }

    private func protocolClasses(from headerValue: String?) -> [AnyClass]? {
        guard let headerValue, !headerValue.isEmpty else { return nil }
        let classes = headerValue
            .split(separator: ",")
            .compactMap { NSClassFromString(String($0)) }
        return classes.isEmpty ? nil : classes
    }
}
