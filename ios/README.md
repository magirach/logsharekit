# LogStreamerKit

`LogStreamerKit` is an iOS log streaming library that can be consumed through:

- Swift Package Manager
- CocoaPods

## What is included

- SPM package: [Package.swift](/Users/atiqaakif/Documents/logs_stream/ios/Package.swift)
- CocoaPods spec: [LogStreamerKit.podspec](/Users/atiqaakif/Documents/logs_stream/ios/LogStreamerKit.podspec)
- Library source: [Sources/LogStreamerKit](/Users/atiqaakif/Documents/logs_stream/ios/Sources/LogStreamerKit)
- SPM example app: [Examples/SPMExample](/Users/atiqaakif/Documents/logs_stream/ios/Examples/SPMExample)
- CocoaPods example app: [Examples/PodsExample](/Users/atiqaakif/Documents/logs_stream/ios/Examples/PodsExample)

## Library features in this scaffold

- library-owned consent prompt
- push-driven start and stop handling
- local session persistence
- app logging API
- `URLSession` instrumentation for network capture
- reusable in-app network inspector view
- batched upload client
- mockable upload transport for local testing

## Open the example apps

### SPM example

Open:

- [SPMExample.xcodeproj](/Users/atiqaakif/Documents/logs_stream/ios/Examples/SPMExample/SPMExample.xcodeproj)

This project references the package locally.

### CocoaPods example

Open:

- [PodsExample.xcworkspace](/Users/atiqaakif/Documents/logs_stream/ios/Examples/PodsExample/PodsExample.xcworkspace)

This project consumes the local pod from:

- [Podfile](/Users/atiqaakif/Documents/logs_stream/ios/Examples/PodsExample/Podfile)

## Test flows in the example apps

Both sample apps include buttons for:

- simulate start push
- write app log
- run mock network request
- simulate stop push

The examples also use in-app mock `URLProtocol` handlers so consent callbacks and event uploads can be exercised without a real backend.

## Install in another app

### Swift Package Manager

Use the local package or add the package repository and import:

```swift
import LogStreamerKit
```

### CocoaPods

Add:

```ruby
pod 'LogStreamerKit', :path => 'path/to/logs_stream'
```

## Required push handling hooks

The host app must forward APNs pushes into `LogStreamerKit`.

SwiftUI app example:

```swift
import SwiftUI
import LogStreamerKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        LogStreamer.handleRemoteNotification(userInfo: userInfo) { handled in
            completionHandler(handled ? .newData : .noData)
        }
    }
}

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        LogStreamer.initialize(config: /* your config */)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Useful helpers:

- `LogStreamer.handleRemoteNotification(userInfo:)`
- `LogStreamer.handleRemoteNotification(userInfo:completion:)`
- `LogStreamer.deviceTokenString(from:)`
- `LogStreamer.makeInstrumentedSession(configuration:delegate:delegateQueue:)`
- `LogStreamer.networkEntries()`
- `LogStreamer.clearNetworkEntries()`

## In-app network inspector

If you want a built-in in-app network viewer instead of a separate tool like Netfox, use `LogStreamer.makeInstrumentedSession(...)` for the sessions you want to capture and present `LogStreamerNetworkInspectorView()` anywhere in your SwiftUI app.

When a `start_logging` push arrives while the app is backgrounded or relaunched in the background, LogStreamer now persists the pending session and defers the consent popup until the app becomes active.

## Real APNs delivery requirements

The repo now includes development entitlements and remote-notification background mode in both example apps, but Apple still requires project signing to match your account.

For real device delivery:

1. Open the example project in Xcode
2. Select the app target and choose your `Team`
3. Confirm the bundle identifier is unique in your Apple Developer account
4. Ensure the App ID has Push Notifications enabled
5. Build to a physical device, not Simulator
6. Reinstall the app after signing/capability changes so iOS refreshes entitlements

Included in repo:

- `aps-environment = development`
- `UIBackgroundModes = remote-notification`
- automatic signing-friendly project settings

If you want production APNs, change the entitlements value from `development` to `production` for your release-signed app.

## Important note

The example app Xcode projects were generated in the repo and the Swift source for the library and both examples type-checks locally. End-to-end `xcodebuild` validation in this environment is limited by local Xcode/CoreSimulator cache and permissions issues, not by the generated Swift sources themselves.
