import Foundation
import LogStreamerKit

@MainActor
enum ExampleBootstrap {
    static func configure() {
        let baseURL = URL(string: "http://127.0.0.1:8080")!
        let config = LogStreamerConfig(
            baseURL: baseURL,
            appId: "pods-example-ios",
            environment: "debug",
            consentCopy: ConsentCopy(
                title: "Allow Example Logging?",
                message: "This sample app uses a mock backend and will capture app and network logs while the session is active.",
                acceptButtonTitle: "Allow",
                declineButtonTitle: "Decline"
            ),
            additionalHeaders: ["X-Demo-Mode": "true"],
            deviceId: "device-demo-pod",
            installationId: "install-demo-pod",
            userId: "user-demo-pod",
            uploadSessionFactory: {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [MockBackendURLProtocol.self]
                return URLSession(configuration: configuration)
            }
        )
        LogStreamer.initialize(config: config)
    }
}
