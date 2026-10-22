// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "SwiftEchada",
  platforms: [
    // FoundationModels' LanguageModel protocol (SwiftLlavero, every cloud
    // provider, Private Cloud Compute) requires the 27 SDKs.
    .iOS("27.0"),
    .macOS("27.0"),
  ],
  products: [
    .library(
      name: "SwiftEchada",
      targets: ["SwiftEchada"]
    ),
    .library(
      name: "EchadaVoice",
      targets: ["EchadaVoice"]
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
      url: "https://github.com/intrusive-memory/SwiftProyecto.git", .upToNextMajor(from: "5.3.2")),
    // TODO: pin .upToNextMajor(from: "0.2.0") once SwiftReparto 0.2.0 is released
    // (role, manifest, canonicalName: EC-23, EC-24).
    .package(
      url: "https://github.com/intrusive-memory/SwiftReparto.git", branch: "requirements/personaje"),
    .package(
      url: "https://github.com/intrusive-memory/SwiftVoxAlta.git", .upToNextMajor(from: "0.14.2")),
    .package(
      url: "https://github.com/intrusive-memory/SwiftLlavero.git",
      .upToNextMinor(from: "0.1.0-beta.2")),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.7.1")),
    // Reads PROJECT.md's `personaje:` block, which SwiftProyecto doesn't model.
    .package(url: "https://github.com/jpsim/Yams.git", .upToNextMajor(from: "6.2.2")),
    .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMajor(from: "0.31.3")),
    .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
    // Aligned with SwiftVoxAlta 0.14.1, which depends on mlx-audio-swift
    // `0.10.0..<1.0.0` (the swift-tokenizers migration). Keep these in lockstep:
    // bump both together when SwiftVoxAlta adopts a newer mlx-audio-swift line.
    .package(
      url: "https://github.com/intrusive-memory/mlx-audio-swift.git", .upToNextMajor(from: "0.10.0")
    ),
    .package(
      url: "https://github.com/intrusive-memory/vox-format.git", .upToNextMajor(from: "0.4.1")),
  ],
  targets: [
    .target(
      name: "SwiftEchada",
      dependencies: [
        .product(name: "SwiftReparto", package: "SwiftReparto")
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    // The voice builder an app can link (Personaje Part B, EC-P5): .vox
    // generation, auditions, and samples with no ArgumentParser and no
    // PROJECT.md reader in its dependency closure.
    .target(
      name: "EchadaVoice",
      dependencies: [
        "SwiftEchada",
        .product(name: "SwiftReparto", package: "SwiftReparto"),
        .product(name: "SwiftVoxAlta", package: "SwiftVoxAlta"),
        .product(name: "MLX", package: "mlx-swift"),
        .product(name: "MLXAudioTTS", package: "mlx-audio-swift"),
        .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
        .product(name: "VoxFormat", package: "vox-format"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .target(
      name: "EchadaCLICore",
      dependencies: [
        "SwiftEchada",
        "EchadaVoice",
        .product(name: "SwiftProyecto", package: "SwiftProyecto"),
        .product(name: "SwiftReparto", package: "SwiftReparto"),
        .product(name: "SwiftVoxAlta", package: "SwiftVoxAlta"),
        .product(name: "SwiftLlavero", package: "SwiftLlavero"),
        .product(name: "LlaveroCLI", package: "SwiftLlavero"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "MLX", package: "mlx-swift"),
        .product(name: "MLXAudioTTS", package: "mlx-audio-swift"),
        .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
        .product(name: "VoxFormat", package: "vox-format"),
        .product(name: "Yams", package: "Yams"),
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
        "EchadaVoice",
        "EchadaCLICore",
        .product(name: "SwiftReparto", package: "SwiftReparto"),
        .product(name: "VoxFormat", package: "vox-format"),
        .product(name: "SwiftVoxAlta", package: "SwiftVoxAlta"),
      ],
      resources: [
        .copy("Fixtures")
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
