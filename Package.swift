// swift-tools-version: 6.2

import Foundation
import PackageDescription

// In CI we always pin to released remotes. Locally, prefer a sibling checkout
// at ../<name> if present so in-flight changes can be exercised end-to-end
// without publishing a release. Falls back to the remote pin if the sibling
// directory is missing, so fresh clones still build.
//
// When this manifest is evaluated as a transitive dependency inside Xcode's
// `SourcePackages/checkouts/` or SwiftPM's `.build/checkouts/`, every other
// dependency lives as a sibling in the same directory. Treating those as
// in-development local paths produces conflicting package identities, so we
// must skip the sibling shortcut in that context.
let manifestDir = (#filePath as NSString).deletingLastPathComponent
let isSPMCheckout =
  manifestDir.contains("/SourcePackages/checkouts/")
  || manifestDir.contains("/.build/checkouts/")
let isCI = ProcessInfo.processInfo.environment["CI"] == "true"
let useLocalSiblings = !isCI && !isSPMCheckout

func sibling(_ name: String, remote: String, from version: Version) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, .upToNextMajor(from: version))
}

/// Same sibling-priority pattern as ``sibling(_:remote:from:)`` but pins to a
/// remote branch when no local sibling exists. Use only when a temporary
/// pre-release dependency on a feature branch is required; switch back to the
/// version-pinned ``sibling(_:remote:from:)`` once the upstream tags a release.
func sibling(_ name: String, remote: String, branch: String) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, branch: branch)
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
    sibling(
      "SwiftProyecto",
      remote: "https://github.com/intrusive-memory/SwiftProyecto.git",
      from: "3.8.0"),
    sibling(
      "SwiftVoxAlta",
      remote: "https://github.com/intrusive-memory/SwiftVoxAlta.git",
      from: "0.14.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.7.1")),
    .package(url: "https://github.com/ml-explore/mlx-swift", .upToNextMajor(from: "0.31.3")),
    .package(url: "https://github.com/ml-explore/mlx-swift-lm", .upToNextMajor(from: "3.31.3")),
    sibling(
      "mlx-audio-swift",
      remote: "https://github.com/intrusive-memory/mlx-audio-swift.git",
      from: "0.8.6"),
    sibling(
      "vox-format",
      remote: "https://github.com/intrusive-memory/vox-format.git",
      from: "0.4.1"),
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
