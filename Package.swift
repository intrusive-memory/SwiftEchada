// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "SwiftEchada",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
  ],
  products: [
    .library(
      name: "SwiftEchada",
      targets: ["SwiftEchada"]
    ),
    .library(
      name: "EchadaCLICore",
      targets: ["EchadaCLICore"]
    ),
    .executable(
      name: "echada",
      targets: ["echada"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/intrusive-memory/SwiftProyecto.git", .upToNextMajor(from: "3.8.0")),
    .package(
      url: "https://github.com/intrusive-memory/SwiftVoxAlta.git", .upToNextMajor(from: "0.13.1")),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.7.1")),
    .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMajor(from: "0.31.3")),
    .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
    .package(
      url: "https://github.com/intrusive-memory/mlx-audio-swift.git", .upToNextMajor(from: "0.8.6")),
    .package(
      url: "https://github.com/intrusive-memory/vox-format.git", .upToNextMajor(from: "0.4.0")),
  ],
  targets: [
    .target(
      name: "SwiftEchada",
      dependencies: [
        .product(name: "SwiftProyecto", package: "SwiftProyecto")
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .target(
      name: "EchadaCLICore",
      dependencies: [
        "SwiftEchada",
        .product(name: "SwiftProyecto", package: "SwiftProyecto"),
        .product(name: "SwiftVoxAlta", package: "SwiftVoxAlta"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "MLX", package: "mlx-swift"),
        .product(name: "MLXAudioTTS", package: "mlx-audio-swift"),
        .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
        .product(name: "VoxFormat", package: "vox-format"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .executableTarget(
      name: "echada",
      dependencies: [
        "EchadaCLICore",
        "SwiftEchada",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "SwiftEchadaTests",
      dependencies: [
        "SwiftEchada",
        "EchadaCLICore",
        .product(name: "VoxFormat", package: "vox-format"),
        .product(name: "SwiftVoxAlta", package: "SwiftVoxAlta"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
