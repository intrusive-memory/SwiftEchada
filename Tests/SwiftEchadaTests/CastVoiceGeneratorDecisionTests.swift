import Foundation
import Testing
@preconcurrency import VoxFormat

@testable import EchadaCLICore

// MARK: - Helpers

private let model06B = "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16"
private let model17B = "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16"

/// Minimal silent WAV used as sample-audio bytes for the synthetic .vox files.
private func syntheticWAV(durationSeconds: Double = 0.25, sampleRate: Int = 24000) -> Data {
  let numSamples = Int(Double(sampleRate) * durationSeconds)
  let dataSize = numSamples * 2  // 16-bit mono
  let fileSize = 36 + dataSize

  var data = Data()
  data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])  // "RIFF"
  data.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
  data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])  // "WAVE"
  data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])  // "fmt "
  data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
  data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
  data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
  data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
  data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) })
  data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })
  data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })
  data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])  // "data"
  data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
  data.append(Data(repeating: 0, count: dataSize))
  return data
}

private func syntheticClonePrompt(size: Int = 256) -> Data {
  Data((0..<size).map { _ in UInt8.random(in: 0...255) })
}

/// Builds a `.vox` on disk containing only the given variant's clone-prompt +
/// sample-audio entries (matches the layout VoxExporter produces).
@discardableResult
private func writeVoxOnDisk(
  at url: URL,
  containingVariant slug: String,
  modelId: String
) throws -> URL {
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

  let manifest = VoxManifest(
    voxVersion: VoxFormat.currentVersion,
    id: UUID().uuidString.lowercased(),
    created: Date(),
    voice: VoxManifest.Voice(
      name: "TEST", description: "Synthetic test voice for decision logic checks")
  )
  let vox = VoxFile(manifest: manifest)

  try vox.add(
    syntheticClonePrompt(),
    at: "embeddings/qwen3-tts/\(slug)/clone-prompt.bin",
    metadata: [
      "key": "qwen3-tts-\(slug)-clone-prompt",
      "model": modelId,
      "engine": "qwen3-tts",
      "format": "bin",
    ] as [String: Any])

  try vox.add(
    syntheticWAV(),
    at: "embeddings/qwen3-tts/\(slug)/sample-audio.wav",
    metadata: [
      "key": "qwen3-tts-\(slug)-sample-audio",
      "model": modelId,
      "engine": "qwen3-tts",
      "format": "wav",
    ] as [String: Any])

  try vox.write(to: url)
  return url
}

private func tempVoxURL() -> URL {
  FileManager.default.temporaryDirectory
    .appendingPathComponent("decide-vox-\(UUID().uuidString)")
    .appendingPathComponent("voice.vox")
}

// MARK: - Tests

@Suite("CastVoiceGenerator decision logic")
struct CastVoiceGeneratorDecisionTests {

  /// (a) Existing 1.7b vox + request 0.6b → `.generate` (must NOT skip).
  @Test func existing17b_request06b_generates() throws {
    let url = tempVoxURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    try writeVoxOnDisk(at: url, containingVariant: "1.7b", modelId: model17B)

    let decision = decideVoxGeneration(
      existingFileExists: true,
      forceRegenerate: false,
      ttsModelVariant: "0.6b",
      openExistingVox: { try VoxFile(contentsOf: url) }
    )
    #expect(decision == .generate)
  }

  /// (b) Existing 1.7b vox + request 1.7b → `.skipExistingHasVariant`.
  @Test func existing17b_request17b_skips() throws {
    let url = tempVoxURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    try writeVoxOnDisk(at: url, containingVariant: "1.7b", modelId: model17B)

    let decision = decideVoxGeneration(
      existingFileExists: true,
      forceRegenerate: false,
      ttsModelVariant: "1.7b",
      openExistingVox: { try VoxFile(contentsOf: url) }
    )
    #expect(decision == .skipExistingHasVariant)
  }

  /// (b') Mirror of (b) for 0.6b symmetry.
  @Test func existing06b_request06b_skips() throws {
    let url = tempVoxURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    try writeVoxOnDisk(at: url, containingVariant: "0.6b", modelId: model06B)

    let decision = decideVoxGeneration(
      existingFileExists: true,
      forceRegenerate: false,
      ttsModelVariant: "0.6b",
      openExistingVox: { try VoxFile(contentsOf: url) }
    )
    #expect(decision == .skipExistingHasVariant)
  }

  /// (c) No existing vox → `.generate`, regardless of variant.
  @Test func noExistingVox_generates_for06b() {
    let decision = decideVoxGeneration(
      existingFileExists: false,
      forceRegenerate: false,
      ttsModelVariant: "0.6b",
      openExistingVox: {
        Issue.record("openExistingVox should not be invoked when file does not exist")
        return VoxFile(name: "x", description: "y" + String(repeating: "y", count: 12))
      }
    )
    #expect(decision == .generate)
  }

  @Test func noExistingVox_generates_for17b() {
    let decision = decideVoxGeneration(
      existingFileExists: false,
      forceRegenerate: false,
      ttsModelVariant: "1.7b",
      openExistingVox: {
        Issue.record("openExistingVox should not be invoked when file does not exist")
        return VoxFile(name: "x", description: "y" + String(repeating: "y", count: 12))
      }
    )
    #expect(decision == .generate)
  }

  /// (d) `--force-regenerate` → `.generate`, regardless of variant or what's already there.
  @Test func forceRegenerate_generates_evenWhenVariantPresent() throws {
    let url = tempVoxURL()
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    try writeVoxOnDisk(at: url, containingVariant: "1.7b", modelId: model17B)

    let decision = decideVoxGeneration(
      existingFileExists: true,
      forceRegenerate: true,
      ttsModelVariant: "1.7b",
      openExistingVox: {
        Issue.record("openExistingVox should not be invoked when forceRegenerate is true")
        return try VoxFile(contentsOf: url)
      }
    )
    #expect(decision == .generate)
  }

  @Test func forceRegenerate_generates_whenNoFile() {
    let decision = decideVoxGeneration(
      existingFileExists: false,
      forceRegenerate: true,
      ttsModelVariant: "0.6b",
      openExistingVox: {
        Issue.record("openExistingVox should not be invoked")
        return VoxFile(name: "x", description: "y" + String(repeating: "y", count: 12))
      }
    )
    #expect(decision == .generate)
  }

  /// Corrupt / unreadable existing .vox → `.skipExistingUnreadable` (don't silently overwrite).
  @Test func corruptExistingVox_isSkippedNotOverwritten() {
    struct DummyError: Error {}

    let decision = decideVoxGeneration(
      existingFileExists: true,
      forceRegenerate: false,
      ttsModelVariant: "1.7b",
      openExistingVox: { throw DummyError() }
    )
    #expect(decision == .skipExistingUnreadable)
  }
}
