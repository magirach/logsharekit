import SwiftUI
import LogStreamerKit

@main
struct PodsExampleApp: App {
    @UIApplicationDelegateAdaptor(ExampleAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        ExampleBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: ExampleViewModel())
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task { await LogStreamer.applicationDidBecomeActive() }
            case .background:
                Task { await LogStreamer.applicationDidEnterBackground() }
            default:
                break
            }
        }
    }
}
