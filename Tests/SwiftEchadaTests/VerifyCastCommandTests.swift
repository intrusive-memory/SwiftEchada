import ArgumentParser
import CryptoKit
import Foundation
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// `echada verify cast` (EC-9): compares CAST.md against the legacy `cast:`
/// block in PROJECT.md, reports three divergence classes, exits non-zero on
/// any divergence and zero when clean — and never writes either file, which
/// every test here asserts by SHA-256.
@Suite("verify cast — report-only migration gate (offline)")
struct VerifyCastCommandTests {

  // MARK: - Fixture

  /// The canonical two-member legacy `cast:` block. NARRATOR carries a
  /// resolvable `.vox` pointer (the file is created on disk by
  /// `makeProject`); THE PRACTITIONER has no voices.
  private static let matchingProjectMd = """
    ---
    type: podcast
    title: Verify Fixture
    cast:
      - character: NARRATOR
        voicePrompt: Deep authoritative British baritone.
        voices:
          voxalta: voices/NARRATOR.vox
      - character: THE PRACTITIONER
        voicePrompt: Anxious, rapid-fire tenor.
    ---

    # Verify Fixture
    """

  /// The CAST.md roster that matches `matchingProjectMd` exactly.
  private static var matchingCast: [SwiftReparto.CastMember] {
    [
      SwiftReparto.CastMember(
        character: "NARRATOR",
        voicePrompt: "Deep authoritative British baritone.",
        voices: ["voxalta": ["voices/NARRATOR.vox"]]),
      SwiftReparto.CastMember(
        character: "THE PRACTITIONER",
        voicePrompt: "Anxious, rapid-fire tenor."),
    ]
  }

  /// Builds a temp project directory holding `projectMd` as PROJECT.md, a
  /// CAST.md generated from `cast`, and a dummy `voices/NARRATOR.vox` so the
  /// canonical pointer resolves. Returns the PROJECT.md URL; the caller
  /// removes the directory via `defer`.
  private func makeProject(
    projectMd: String,
    cast: [SwiftReparto.CastMember]
  ) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("verify-cast-\(UUID().uuidString)")
    let voicesDir = dir.appendingPathComponent("voices")
    try FileManager.default.createDirectory(at: voicesDir, withIntermediateDirectories: true)
    try Data("vox".utf8).write(to: voicesDir.appendingPathComponent("NARRATOR.vox"))

    let projectURL = dir.appendingPathComponent("PROJECT.md")
    try projectMd.write(to: projectURL, atomically: true, encoding: .utf8)

    let castURL = dir.appendingPathComponent("CAST.md")
    try CastMarkdownParser().write(document: CastDocument(cast: cast), to: castURL)
    return projectURL
  }

  private func sha256(of url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  /// Asserts PROJECT.md and CAST.md are byte-identical (by SHA-256) to the
  /// captured hashes — verification must never write either input file.
  private func expectUnchanged(
    _ projectURL: URL, projectSha: String, castSha: String
  ) throws {
    let castURL = projectURL.deletingLastPathComponent().appendingPathComponent("CAST.md")
    #expect(try sha256(of: projectURL) == projectSha)
    #expect(try sha256(of: castURL) == castSha)
  }

  // MARK: - Clean pair exits 0

  @Test("A matching CAST.md / PROJECT.md pair exits 0 and writes neither file")
  func matchingPairExitsZero() async throws {
    let projectURL = try makeProject(projectMd: Self.matchingProjectMd, cast: Self.matchingCast)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let projectSha = try sha256(of: projectURL)
    let castSha = try sha256(
      of: projectURL.deletingLastPathComponent().appendingPathComponent("CAST.md"))

    let cmd = try VerifyCastCommand.parse(["--project", projectURL.path])
    // Exit code 0 is "run() returns without throwing" — ArgumentParser maps
    // a clean return to EX_OK.
    try await cmd.run()

    let divergences = try VerifyCastCommand.collectDivergences(
      projectURL: projectURL, castName: "CAST.md")
    #expect(divergences.isEmpty)

    try expectUnchanged(projectURL, projectSha: projectSha, castSha: castSha)
  }

  // MARK: - Divergence class 1: membership

  @Test("A character missing from CAST.md exits non-zero and is named in the diagnostics")
  func missingCharacterExitsNonZero() async throws {
    // ESPECTRO FAMILIAR exists only in PROJECT.md's legacy cast; PRODUCER
    // exists only in CAST.md. Both directions of the membership class must
    // be reported by name.
    let projectMd = """
      ---
      type: podcast
      title: Verify Fixture
      cast:
        - character: NARRATOR
          voicePrompt: Deep authoritative British baritone.
          voices:
            voxalta: voices/NARRATOR.vox
        - character: THE PRACTITIONER
          voicePrompt: Anxious, rapid-fire tenor.
        - character: ESPECTRO FAMILIAR
          voicePrompt: Methodical, unhurried, ancient.
      ---
      """
    let castRoster = Self.matchingCast + [SwiftReparto.CastMember(character: "PRODUCER")]
    let projectURL = try makeProject(projectMd: projectMd, cast: castRoster)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let projectSha = try sha256(of: projectURL)
    let castSha = try sha256(
      of: projectURL.deletingLastPathComponent().appendingPathComponent("CAST.md"))

    let cmd = try VerifyCastCommand.parse(["--project", projectURL.path])
    await #expect(throws: ExitCode(1)) { try await cmd.run() }

    // The emitted diagnostics (run() writes exactly these messages to
    // stderr) name the offending characters, in both directions.
    let divergences = try VerifyCastCommand.collectDivergences(
      projectURL: projectURL, castName: "CAST.md")
    let membership = divergences.filter { $0.kind == .membership }
    #expect(membership.count == 2)
    let messages = membership.map(\.message).joined(separator: "\n")
    #expect(messages.contains("ESPECTRO FAMILIAR"))
    #expect(messages.contains("missing from CAST.md"))
    #expect(messages.contains("PRODUCER"))
    #expect(divergences.filter { $0.kind != .membership }.isEmpty)

    try expectUnchanged(projectURL, projectSha: projectSha, castSha: castSha)
  }

  // MARK: - Divergence class 2: field mismatch

  @Test("A differing voicePrompt exits non-zero and the diagnostics name the field")
  func differingVoicePromptExitsNonZero() async throws {
    var castRoster = Self.matchingCast
    castRoster[0].voicePrompt = "Bright, chirpy morning-radio host."
    let projectURL = try makeProject(projectMd: Self.matchingProjectMd, cast: castRoster)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let projectSha = try sha256(of: projectURL)
    let castSha = try sha256(
      of: projectURL.deletingLastPathComponent().appendingPathComponent("CAST.md"))

    let cmd = try VerifyCastCommand.parse(["--project", projectURL.path])
    await #expect(throws: ExitCode(1)) { try await cmd.run() }

    let divergences = try VerifyCastCommand.collectDivergences(
      projectURL: projectURL, castName: "CAST.md")
    let mismatches = divergences.filter { $0.kind == .fieldMismatch }
    #expect(mismatches.count == 1)
    let message = try #require(mismatches.first?.message)
    #expect(message.contains("NARRATOR"))
    #expect(message.contains("voicePrompt"))
    #expect(divergences.filter { $0.kind != .fieldMismatch }.isEmpty)

    try expectUnchanged(projectURL, projectSha: projectSha, castSha: castSha)
  }

  // MARK: - Divergence class 3: dangling .vox path

  @Test("A dangling .vox path exits non-zero and the diagnostics name the path")
  func danglingVoxPathExitsNonZero() async throws {
    // Both rosters agree, but the pointer names a file that does not exist.
    // The path appears identically in PROJECT.md, so this is purely the
    // on-disk resolution class.
    let projectMd = """
      ---
      type: podcast
      title: Verify Fixture
      cast:
        - character: NARRATOR
          voicePrompt: Deep authoritative British baritone.
          voices:
            voxalta: voices/GHOST.vox
      ---
      """
    let castRoster = [
      SwiftReparto.CastMember(
        character: "NARRATOR",
        voicePrompt: "Deep authoritative British baritone.",
        voices: ["voxalta": ["voices/GHOST.vox"]])
    ]
    let projectURL = try makeProject(projectMd: projectMd, cast: castRoster)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let projectSha = try sha256(of: projectURL)
    let castSha = try sha256(
      of: projectURL.deletingLastPathComponent().appendingPathComponent("CAST.md"))

    let cmd = try VerifyCastCommand.parse(["--project", projectURL.path])
    await #expect(throws: ExitCode(1)) { try await cmd.run() }

    let divergences = try VerifyCastCommand.collectDivergences(
      projectURL: projectURL, castName: "CAST.md")
    let dangling = divergences.filter { $0.kind == .danglingVoicePath }
    #expect(dangling.count == 1)
    let message = try #require(dangling.first?.message)
    #expect(message.contains("voices/GHOST.vox"))
    #expect(message.contains("NARRATOR"))
    #expect(divergences.filter { $0.kind != .danglingVoicePath }.isEmpty)

    try expectUnchanged(projectURL, projectSha: projectSha, castSha: castSha)
  }

  // MARK: - Never writes (EC-9: report only)

  @Test("Both input files are SHA-256-identical after clean and divergent runs alike")
  func verificationNeverWritesEitherFile() async throws {
    // Clean run.
    let cleanURL = try makeProject(projectMd: Self.matchingProjectMd, cast: Self.matchingCast)
    defer { try? FileManager.default.removeItem(at: cleanURL.deletingLastPathComponent()) }
    let cleanProjectSha = try sha256(of: cleanURL)
    let cleanCastSha = try sha256(
      of: cleanURL.deletingLastPathComponent().appendingPathComponent("CAST.md"))
    try await VerifyCastCommand.parse(["--project", cleanURL.path]).run()
    try expectUnchanged(cleanURL, projectSha: cleanProjectSha, castSha: cleanCastSha)

    // Divergent run (roster drifted): still no writes.
    var drifted = Self.matchingCast
    drifted.removeLast()
    let driftedURL = try makeProject(projectMd: Self.matchingProjectMd, cast: drifted)
    defer { try? FileManager.default.removeItem(at: driftedURL.deletingLastPathComponent()) }
    let driftedProjectSha = try sha256(of: driftedURL)
    let driftedCastSha = try sha256(
      of: driftedURL.deletingLastPathComponent().appendingPathComponent("CAST.md"))
    let cmd = try VerifyCastCommand.parse(["--project", driftedURL.path])
    await #expect(throws: ExitCode(1)) { try await cmd.run() }
    try expectUnchanged(driftedURL, projectSha: driftedProjectSha, castSha: driftedCastSha)
  }

  // MARK: - Option surface

  @Test("verify cast parses --project and --cast, with CAST.md as the default filename")
  func parsesOptionSurface() throws {
    let defaulted = try VerifyCastCommand.parse(["--project", "PROJECT.md"])
    #expect(defaulted.project == "PROJECT.md")
    #expect(defaulted.cast == "CAST.md")

    let overridden = try VerifyCastCommand.parse([
      "--project", "PROJECT.md", "--cast", "ROSTER.md",
    ])
    #expect(overridden.cast == "ROSTER.md")
  }

  @Test("verify cast rejects a --cast value carrying a path separator")
  func rejectsCastPathSeparators() async throws {
    let projectURL = try makeProject(projectMd: Self.matchingProjectMd, cast: Self.matchingCast)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    let cmd = try VerifyCastCommand.parse([
      "--project", projectURL.path, "--cast", "../CAST.md",
    ])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }
}
