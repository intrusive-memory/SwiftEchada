// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftEchada",
    platforms: [
        .iOS(.v26),
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "SwiftEchada",
            targets: ["SwiftEchada"]
        ),
        .executable(
            name: "echada",
            targets: ["echada"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/intrusive-memory/SwiftProyecto.git", branch: "development"),
        .package(url: "https://github.com/intrusive-memory/SwiftHablare.git", branch: "development"),
        .package(url: "https://github.com/intrusive-memory/SwiftBruja.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "SwiftEchada",
            dependencies: [
                .product(name: "SwiftProyecto", package: "SwiftProyecto"),
                .product(name: "SwiftHablare", package: "SwiftHablare"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "echada",
            dependencies: [
                "SwiftEchada",
                .product(name: "SwiftBruja", package: "SwiftBruja"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "SwiftEchadaTests",
            dependencies: ["SwiftEchada"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
