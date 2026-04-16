//
//  CDNAvailabilityTests.swift
//  SwiftEchadaTests
//
//  Validates that the Qwen3-TTS models used by the echada CLI voice pipeline
//  are available on the Acervo CDN and download correctly via SwiftAcervo.
//
//  These tests require network access and download only config.json (~2–5 KB
//  per model). They are excluded from make test via -skip-testing and run
//  explicitly via:
//
//    make test-cdn
//    # or manually:
//    xcodebuild test -scheme SwiftEchada-Package -destination 'platform=macOS' \
//        -only-testing:SwiftEchadaTests/CDNAvailabilityTests

import Testing
import Foundation
@testable import SwiftAcervo
import SwiftVoxAlta

// MARK: - Models under test

/// The three Qwen3-TTS models the echada CLI voice pipeline requires.
private let echadaModels: [Qwen3TTSModelRepo] = [
  .voiceDesign1_7B,  // Phase A: voice candidate generation
  .base1_7B,         // Phase B: default voice locking
  .base0_6B,         // Phase B: lightweight alternative
]

// MARK: - Helpers

private let cdnBase = "https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models"

private func manifestURL(for modelId: String) -> URL {
  URL(string: "\(cdnBase)/\(Acervo.slugify(modelId))/manifest.json")!
}

private func makeTempDir() throws -> URL {
  let dir = FileManager.default.temporaryDirectory
    .appendingPathComponent("Echada-CDN-\(UUID().uuidString)")
  try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  return dir
}

private func cleanup(_ dir: URL) {
  try? FileManager.default.removeItem(at: dir)
}

// MARK: - Tests

@Suite("CDN Availability: Echada Pipeline Models")
struct CDNAvailabilityTests {

  @Test("Pipeline model manifests are accessible on CDN (HTTP 200)", arguments: echadaModels)
  func manifestAccessible(repo: Qwen3TTSModelRepo) async throws {
    let (_, response) = try await URLSession.shared.data(from: manifestURL(for: repo.rawValue))
    let http = try #require(response as? HTTPURLResponse)
    #expect(
      http.statusCode == 200,
      "echada requires \(repo.rawValue) but CDN manifest returned HTTP \(http.statusCode)"
    )
  }

  @Test("Pipeline model manifests declare required files", arguments: echadaModels)
  func manifestDeclaresRequiredFiles(repo: Qwen3TTSModelRepo) async throws {
    let (data, response) = try await URLSession.shared.data(from: manifestURL(for: repo.rawValue))
    let http = try #require(response as? HTTPURLResponse)
    try #require(http.statusCode == 200, "Cannot parse manifest: HTTP \(http.statusCode)")

    let json = try #require(
      try JSONSerialization.jsonObject(with: data) as? [String: Any],
      "manifest.json is not a JSON dictionary"
    )

    let files = json["files"] as? [[String: Any]] ?? []
    let paths = Set(files.compactMap { $0["path"] as? String })
    #expect(paths.contains("config.json"), "\(repo.rawValue): manifest missing config.json")
    #expect(paths.contains("model.safetensors"), "\(repo.rawValue): manifest missing model.safetensors")
  }

  @Test("config.json downloads and parses as JSON", arguments: echadaModels)
  func configJsonDownloads(repo: Qwen3TTSModelRepo) async throws {
    let tempBase = try makeTempDir()
    defer { cleanup(tempBase) }

    try await Acervo.download(repo.rawValue, files: ["config.json"], in: tempBase)

    let configPath = tempBase
      .appendingPathComponent(Acervo.slugify(repo.rawValue))
      .appendingPathComponent("config.json")

    #expect(
      FileManager.default.fileExists(atPath: configPath.path),
      "\(repo.rawValue): config.json missing after Acervo download"
    )

    let data = try Data(contentsOf: configPath)
    let json = try JSONSerialization.jsonObject(with: data)
    #expect(json is [String: Any], "\(repo.rawValue): config.json is not a JSON dictionary")
  }

  @Test("Acervo marks pipeline models available after config.json download", arguments: echadaModels)
  func modelAvailableAfterDownload(repo: Qwen3TTSModelRepo) async throws {
    let tempBase = try makeTempDir()
    defer { cleanup(tempBase) }

    #expect(!Acervo.isModelAvailable(repo.rawValue, in: tempBase))
    try await Acervo.download(repo.rawValue, files: ["config.json"], in: tempBase)
    #expect(
      Acervo.isModelAvailable(repo.rawValue, in: tempBase),
      "\(repo.rawValue): not marked available after config.json download"
    )
  }
}
