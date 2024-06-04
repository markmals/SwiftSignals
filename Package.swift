// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SwiftSignals",
    platforms: [.iOS(.v17), .macCatalyst(.v17), .macOS(.v14), .watchOS(.v10), .tvOS(.v17), .visionOS(.v1)],
    products: [
        .library(name: "AngularSignals", targets: ["AngularSignals"]),
        .library(name: "ObservableSignals", targets: ["ObservableSignals"]),
        .library(name: "ReactivelySignals", targets: ["ReactivelySignals"]),
//        .library(name: "LeptosSignals", targets: ["LeptosSignals"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.9.0")
    ],
    targets: [
        .target(name: "AngularSignals"),
        .target(name: "ObservableSignals"),
        .target(name: "ReactivelySignals"),
//        .target(name: "LeptosSignals"),
        
        .testTarget(name: "AngularSignalsTests", dependencies: [
            "AngularSignals",
            .product(name: "Testing", package: "swift-testing"),
        ]),
        .testTarget(name: "ObservableSignalsTests", dependencies: [
            "ObservableSignals",
            .product(name: "Testing", package: "swift-testing"),
        ]),
        .testTarget(name: "ReactivelySignalsTests", dependencies: [
            "ReactivelySignals",
            .product(name: "Testing", package: "swift-testing"),
        ]),
//        .testTarget(name: "LeptosSignalsTests", dependencies: [
//            "LeptosSignals",
//            .product(name: "Testing", package: "swift-testing"),
//        ]),
    ]
)
