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
        .package(url: "https://github.com/intrusive-memory/SwiftVoxAlta.git", branch: "development"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm", branch: "main"),
        .package(url: "https://github.com/intrusive-memory/mlx-audio-swift.git", branch: "development"),
        .package(url: "https://github.com/intrusive-memory/vox-format.git", from: "0.3.0"),
    ],
    targets: [
        .target(
            name: "SwiftEchada",
            dependencies: [
                .product(name: "SwiftProyecto", package: "SwiftProyecto"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "echada",
            dependencies: [
                "SwiftEchada",
                .product(name: "SwiftVoxAlta", package: "SwiftVoxAlta"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXAudioTTS", package: "mlx-audio-swift"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "VoxFormat", package: "vox-format"),
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
