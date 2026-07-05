import ArgumentParser
import Foundation
import Testing

@testable import EchadaCLICore

/// Covers the model-free branches of `GenerateVoxCommand.run()` — the validation
/// gates and the `--dry-run` path, all of which execute and return before the
/// command ever constructs a `CastVoiceGenerator` or loads a TTS model. These run
/// anywhere (no Apple Intelligence, no model downloads) and exercise the `vox`
/// entry point that was otherwise only reachable via `make integration-test`.
@Suite("GenerateVoxCommand.run — model-free branches")
struct GenerateVoxCommandTests {

  static let twoMemberProject = """
    ---
    type: project
    title: Test Cast
    author: Test
    created: 2026-01-01T00:00:00Z
    cast:
      - character: ALICE
        voicePrompt: "A warm, measured female narrator."
        voices:
          voxalta: voices/ALICE.vox
      - character: BOB
        voicePrompt: "A gruff male detective, deep baritone."
        voices:
          voxalta: voices/BOB.vox
    ---
    """

  static let noCastProject = """
    ---
    type: project
    title: Empty Cast
    author: Test
    created: 2026-01-01T00:00:00Z
    ---
    """

  /// Writes a PROJECT.md into a fresh per-test temp directory and returns its URL.
  /// The caller is responsible for removing the parent directory (via `defer`).
  private func writeProject(_ yaml: String) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-cmd-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("PROJECT.md")
    try yaml.write(to: url, atomically: true, encoding: .utf8)
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

  @Test("A project with no cast members is rejected")
  func noCastMembersThrows() async throws {
    let url = try writeProject(Self.noCastProject)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let cmd = try GenerateVoxCommand.parse(["--project", url.path])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  @Test("An unsupported --tts-model variant is rejected")
  func unsupportedTTSModelThrows() async throws {
    let url = try writeProject(Self.twoMemberProject)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let cmd = try GenerateVoxCommand.parse(["--project", url.path, "--tts-model", "9.9b"])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  @Test("An unknown --character is rejected")
  func unknownCharacterThrows() async throws {
    let url = try writeProject(Self.twoMemberProject)
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
    let url = try writeProject(Self.twoMemberProject)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let before = try String(contentsOf: url, encoding: .utf8)

    let cmd = try GenerateVoxCommand.parse(["--project", url.path, "--dry-run"])
    try await cmd.run()

    // The generator is never constructed: no voices/ directory, PROJECT.md untouched.
    let voicesDir = url.deletingLastPathComponent().appendingPathComponent("voices")
    #expect(!FileManager.default.fileExists(atPath: voicesDir.path))
    let after = try String(contentsOf: url, encoding: .utf8)
    #expect(before == after)
  }

  @Test("Dry run honors the --character filter without generating")
  func dryRunWithCharacterFilterSucceeds() async throws {
    let url = try writeProject(Self.twoMemberProject)
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
    let url = try writeProject(Self.twoMemberProject)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    // Lowercase "alice" must resolve to the "ALICE" cast member (no throw).
    let cmd = try GenerateVoxCommand.parse([
      "--project", url.path, "--character", "alice", "--dry-run",
    ])
    try await cmd.run()
  }
}
