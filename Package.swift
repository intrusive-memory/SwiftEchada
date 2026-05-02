// swift-tools-version: 6.2

import Foundation
import PackageDescription

// In CI we always pin to released remotes. Locally, prefer a sibling checkout
// at ../<name> if present so in-flight changes can be exercised end-to-end
// without publishing a release. Falls back to the remote pin if the sibling
// directory is missing, so fresh clones still build.
let useLocalSiblings = ProcessInfo.processInfo.environment["CI"] != "true"

func sibling(_ name: String, remote: String, from version: Version) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, .upToNextMajor(from: version))
}

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
    .executable(
      name: "echada",
      targets: ["echada"]
    ),
  ],
  dependencies: [
    sibling(
      "SwiftProyecto", remote: "https://github.com/intrusive-memory/SwiftProyecto.git",
      from: "3.5.1"),
    sibling(
      "SwiftVoxAlta", remote: "https://github.com/intrusive-memory/SwiftVoxAlta.git", from: "0.10.1"
    ),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.7.1")),
    .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMajor(from: "0.31.3")),
    .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
    sibling(
      "mlx-audio-swift", remote: "https://github.com/intrusive-memory/mlx-audio-swift.git",
      from: "0.6.0"),
    sibling(
      "vox-format", remote: "https://github.com/intrusive-memory/vox-format.git", from: "0.3.1"),
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
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "SwiftEchadaTests",
      dependencies: [
        "SwiftEchada",
        "echada",
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
