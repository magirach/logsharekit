// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LogStreamerKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LogStreamerKit",
            targets: ["LogStreamerKit"]
        ),
    ],
    targets: [
        .target(
            name: "LogStreamerKit"
        ),
        .testTarget(
            name: "LogStreamerKitTests",
            dependencies: ["LogStreamerKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
