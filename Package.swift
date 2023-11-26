// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftSignals",
    platforms: [.iOS(.v17), .macCatalyst(.v17), .macOS(.v14), .watchOS(.v10), .tvOS(.v17), .visionOS(.v1)],
    products: [
        .library(name: "SwiftSignals", targets: ["SwiftSignals"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", branch: "main")
    ],
    targets: [
        .target(name: "SwiftSignals"),
        .testTarget(name: "SwiftSignalsTests", dependencies: [
            "SwiftSignals",
            .product(name: "Testing", package: "swift-testing"),
        ])
    ]
)
