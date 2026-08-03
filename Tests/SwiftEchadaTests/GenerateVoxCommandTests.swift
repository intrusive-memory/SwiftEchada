import ArgumentParser
import Foundation
import SwiftReparto
import Testing
@preconcurrency import VoxFormat

@testable import EchadaCLICore

/// Covers the model-free branches of `GenerateVoxCommand.run()` — the validation
/// gates, the `--dry-run` path, and the skip-existing path — all of which
/// execute and return before the command ever loads a TTS model. These run
/// anywhere (no Apple Intelligence, no model downloads) and exercise the `vox`
/// entry point that was otherwise only reachable via `make integration-test`.
///
/// Since Sortie 7 the roster lives in CAST.md: the command reads it via
/// SwiftReparto's `CastMarkdownParser`, fails when it is absent (EC-14), and
/// writes `.vox` paths back into CAST.md relative to its directory (EC-16).
@Suite("GenerateVoxCommand.run — model-free branches")
struct GenerateVoxCommandTests {

  /// Minimal PROJECT.md — deliberately without any legacy `cast:` block; the
  /// roster belongs to CAST.md now.
  static let minimalProject = """
    ---
    type: project
    title: Test Cast
    author: Test
    created: 2026-01-01T00:00:00Z
    ---
    """

  static let twoMemberCast = [
    SwiftReparto.CastMember(
      character: "ALICE",
      voicePrompt: "A warm, measured female narrator.",
      voices: ["voxalta": ["voices/ALICE.vox"]]),
    SwiftReparto.CastMember(
      character: "BOB",
      voicePrompt: "A gruff male detective, deep baritone.",
      voices: ["voxalta": ["voices/BOB.vox"]]),
  ]

  /// Writes a PROJECT.md (and, unless `castMembers` is nil, a CAST.md roster
  /// beside it) into a fresh per-test temp directory and returns PROJECT.md's
  /// URL. The caller is responsible for removing the parent directory (`defer`).
  private func writeProject(
    _ yaml: String = GenerateVoxCommandTests.minimalProject,
    castMembers: [SwiftReparto.CastMember]?
  ) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-cmd-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("PROJECT.md")
    try yaml.write(to: url, atomically: true, encoding: .utf8)
    if let castMembers {
      let castURL = dir.appendingPathComponent("CAST.md")
      try CastMarkdownParser().write(document: CastDocument(cast: castMembers), to: castURL)
    }
    return url
  }

  // MARK: - Validation gates (reached before any model work)

  @Test("A missing project file is rejected")
  func missingProjectFileThrows() async throws {
    let missing = FileManager.default.temporaryDirectory
      .appendingPathComponent("does-not-exist-\(UUID().uuidString)")
      .appendingPathComponent("PROJECT.md")
    let cmd = try GenerateVoxCommand.parse(["--project", missing.path])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  @Test("A missing CAST.md fails, pointing at `echada generate cast`, and never creates it (EC-14)")
  func missingCastFileThrowsActionably() async throws {
    let url = try writeProject(castMembers: nil)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let cmd = try GenerateVoxCommand.parse(["--project", url.path])
    do {
      try await cmd.run()
      Issue.record("expected a ValidationError for the missing CAST.md")
    } catch let error as ValidationError {
      #expect(error.message.contains("echada generate cast"))
    }
    // EC-14: the command must not have created the roster it failed over.
    let castURL = url.deletingLastPathComponent().appendingPathComponent("CAST.md")
    #expect(!FileManager.default.fileExists(atPath: castURL.path))
  }

  @Test("An empty CAST.md roster is rejected")
  func noCastMembersThrows() async throws {
    let url = try writeProject(castMembers: [])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let cmd = try GenerateVoxCommand.parse(["--project", url.path])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  @Test("An unsupported --tts-model variant is rejected")
  func unsupportedTTSModelThrows() async throws {
    let url = try writeProject(castMembers: Self.twoMemberCast)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let cmd = try GenerateVoxCommand.parse(["--project", url.path, "--tts-model", "9.9b"])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  @Test("An unknown --character is rejected")
  func unknownCharacterThrows() async throws {
    let url = try writeProject(castMembers: Self.twoMemberCast)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    // --dry-run is set too, so even if the guard were reordered this never loads a model.
    let cmd = try GenerateVoxCommand.parse([
      "--project", url.path, "--character", "NOBODY", "--dry-run",
    ])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  // MARK: - Dry run (returns before the generator; no model, no writes)

  @Test("Dry run succeeds and writes nothing")
  func dryRunSucceedsAndWritesNothing() async throws {
    let url = try writeProject(castMembers: Self.twoMemberCast)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let castURL = url.deletingLastPathComponent().appendingPathComponent("CAST.md")
    let projectBefore = try String(contentsOf: url, encoding: .utf8)
    let castBefore = try String(contentsOf: castURL, encoding: .utf8)

    let cmd = try GenerateVoxCommand.parse(["--project", url.path, "--dry-run"])
    try await cmd.run()

    // The generator is never constructed: no voices/ directory, both files untouched.
    let voicesDir = url.deletingLastPathComponent().appendingPathComponent("voices")
    #expect(!FileManager.default.fileExists(atPath: voicesDir.path))
    #expect(try String(contentsOf: url, encoding: .utf8) == projectBefore)
    #expect(try String(contentsOf: castURL, encoding: .utf8) == castBefore)
  }

  @Test("Dry run honors the --character filter without generating")
  func dryRunWithCharacterFilterSucceeds() async throws {
    let url = try writeProject(castMembers: Self.twoMemberCast)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let cmd = try GenerateVoxCommand.parse([
      "--project", url.path, "--character", "ALICE", "--dry-run",
    ])
    try await cmd.run()
    let voicesDir = url.deletingLastPathComponent().appendingPathComponent("voices")
    #expect(!FileManager.default.fileExists(atPath: voicesDir.path))
  }

  @Test("The --character filter is case-insensitive")
  func characterFilterIsCaseInsensitive() async throws {
    let url = try writeProject(castMembers: Self.twoMemberCast)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    // Lowercase "alice" must resolve to the "ALICE" cast member (no throw).
    let cmd = try GenerateVoxCommand.parse([
      "--project", url.path, "--character", "alice", "--dry-run",
    ])
    try await cmd.run()
  }

  // MARK: - CAST.md write-back of .vox paths (EC-16; skip-existing path, no model)

  /// Builds a synthetic-but-valid `.vox` on disk containing the given variant's
  /// clone-prompt + sample-audio entries (matches the layout VoxExporter
  /// produces), so the command's decision logic takes the model-free
  /// `.skipExistingHasVariant` path.
  private func writeSyntheticVox(at url: URL, variant slug: String, modelId: String) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    let manifest = VoxManifest(
      voxVersion: VoxFormat.currentVersion,
      id: UUID().uuidString.lowercased(),
      created: Date(),
      voice: VoxManifest.Voice(name: "NARR", description: "Synthetic test voice")
    )
    let vox = VoxFile(manifest: manifest)

    // Minimal silent 16-bit mono WAV.
    let sampleRate = 24000
    let numSamples = sampleRate / 4
    let dataSize = numSamples * 2
    var wav = Data()
    wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46])  // "RIFF"
    wav.append(contentsOf: withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { Array($0) })
    wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45])  // "WAVE"
    wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])  // "fmt "
    wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
    wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
    wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
    wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
    wav.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) })
    wav.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })
    wav.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })
    wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61])  // "data"
    wav.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
    wav.append(Data(repeating: 0, count: dataSize))

    try vox.add(
      Data((0..<256).map { _ in UInt8.random(in: 0...255) }),
      at: "embeddings/qwen3-tts/\(slug)/clone-prompt.bin",
      metadata: [
        "key": "qwen3-tts-\(slug)-clone-prompt",
        "model": modelId,
        "engine": "qwen3-tts",
        "format": "bin",
      ] as [String: Any])
    try vox.add(
      wav,
      at: "embeddings/qwen3-tts/\(slug)/sample-audio.wav",
      metadata: [
        "key": "qwen3-tts-\(slug)-sample-audio",
        "model": modelId,
        "engine": "qwen3-tts",
        "format": "wav",
      ] as [String: Any])
    try vox.write(to: url)
  }

  /// EC-16 end to end (model-free): a member whose `.vox` already holds the
  /// requested variant takes the skip-existing path, which still records the
  /// voice pointer — and the path written into CAST.md must resolve to an
  /// existing file relative to CAST.md's directory.
  @Test("A .vox path written into CAST.md resolves relative to CAST.md's directory (EC-16)")
  func voxPathInCastMdResolvesRelativeToCastDirectory() async throws {
    let member = SwiftReparto.CastMember(
      character: "NARR",
      voicePrompt: "A calm, warm narrator.")
    let url = try writeProject(castMembers: [member])
    let projectDir = url.deletingLastPathComponent()
    defer { try? FileManager.default.removeItem(at: projectDir) }

    // Pre-existing bundle already carrying the requested 1.7b variant → the
    // command records the pointer without loading any model.
    try writeSyntheticVox(
      at: projectDir.appendingPathComponent("voices/NARR.vox"),
      variant: "1.7b",
      modelId: "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16")

    let cmd = try GenerateVoxCommand.parse([
      "--project", url.path, "--tts-model", "1.7b",
    ])
    try await cmd.run()

    // The pointer was written into CAST.md...
    let castURL = projectDir.appendingPathComponent("CAST.md")
    let roster = try CastMarkdownParser().parse(fileURL: castURL).cast
    let narr = try #require(roster.first { $0.character == "NARR" })
    let voxPath = try #require(narr.voices["voxalta"]?.first)
    #expect(voxPath == "voices/NARR.vox")

    // ...and resolves to an existing file relative to CAST.md's directory.
    let resolved = castURL.deletingLastPathComponent().appendingPathComponent(voxPath)
    #expect(FileManager.default.fileExists(atPath: resolved.path))

    // PROJECT.md gained no cast: the roster's home is CAST.md alone.
    let projectText = try String(contentsOf: url, encoding: .utf8)
    #expect(!projectText.contains("cast:"))
  }
}
