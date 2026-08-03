import ArgumentParser
import CryptoKit
import Foundation
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// `echada prune cast` (EC-10): strips the legacy `cast:` block from
/// PROJECT.md — and nothing else — gated on CAST.md existing and the
/// Sortie 5 verification passing. Refusals write nothing; repeats are
/// no-ops; `--dry-run` never writes.
@Suite("prune cast — explicit legacy cast: excision (offline)")
struct PruneCastCommandTests {

  // MARK: - Fixture

  /// The canonical two-member legacy `cast:` block, flanked by front-matter
  /// keys that must survive the excision byte-for-byte.
  private static let matchingProjectMd = """
    ---
    type: podcast
    title: Prune Fixture
    introFile: audio/intro.m4a
    cast:
      - character: NARRATOR
        voicePrompt: Deep authoritative British baritone.
        voices:
          voxalta: voices/NARRATOR.vox
      - character: THE PRACTITIONER
        voicePrompt: Anxious, rapid-fire tenor.
    outroFile: audio/outro.m4a
    tts:
      model: 1.7b
    ---

    # Prune Fixture
    """

  /// `matchingProjectMd` with exactly the `cast:` line span removed — the
  /// only difference a successful prune is allowed to produce.
  private static let prunedProjectMd = """
    ---
    type: podcast
    title: Prune Fixture
    introFile: audio/intro.m4a
    outroFile: audio/outro.m4a
    tts:
      model: 1.7b
    ---

    # Prune Fixture
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
  /// CAST.md generated from `cast` (skipped when nil), and a dummy
  /// `voices/NARRATOR.vox` so the canonical pointer resolves. Returns the
  /// PROJECT.md URL; the caller removes the directory via `defer`.
  private func makeProject(
    projectMd: String,
    cast: [SwiftReparto.CastMember]?
  ) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("prune-cast-\(UUID().uuidString)")
    let voicesDir = dir.appendingPathComponent("voices")
    try FileManager.default.createDirectory(at: voicesDir, withIntermediateDirectories: true)
    try Data("vox".utf8).write(to: voicesDir.appendingPathComponent("NARRATOR.vox"))

    let projectURL = dir.appendingPathComponent("PROJECT.md")
    try projectMd.write(to: projectURL, atomically: true, encoding: .utf8)

    if let cast {
      let castURL = dir.appendingPathComponent("CAST.md")
      try CastMarkdownParser().write(document: CastDocument(cast: cast), to: castURL)
    }
    return projectURL
  }

  private func sha256(of url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private func castURL(_ projectURL: URL) -> URL {
    projectURL.deletingLastPathComponent().appendingPathComponent("CAST.md")
  }

  // MARK: - Successful excision

  @Test("Prune removes exactly the cast: line span and touches nothing else")
  func pruneRemovesOnlyCastBlock() async throws {
    let projectURL = try makeProject(projectMd: Self.matchingProjectMd, cast: Self.matchingCast)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let castShaBefore = try sha256(of: castURL(projectURL))

    let cmd = try PruneCastCommand.parse(["--project", projectURL.path])
    try await cmd.run()

    let residual = try String(contentsOf: projectURL, encoding: .utf8)
    #expect(residual == Self.prunedProjectMd)

    // CAST.md is never written by prune.
    #expect(try sha256(of: castURL(projectURL)) == castShaBefore)
  }

  @Test("The removal diff lists exactly the excised cast: lines, all as removals")
  func removalDiffIsExact() {
    let diff = PruneCastCommand.removalDiff(
      original: Self.matchingProjectMd, pruned: Self.prunedProjectMd, label: "PROJECT.md")

    // One hunk of pure removals: the cast: header plus its indented span.
    #expect(diff.contains("-cast:\n"))
    #expect(diff.contains("-  - character: NARRATOR\n"))
    #expect(diff.contains("-  - character: THE PRACTITIONER\n"))
    let lines = diff.split(separator: "\n")
    #expect(lines.filter { $0.hasPrefix("-") && !$0.hasPrefix("---") }.count == 7)
    #expect(lines.filter { $0.hasPrefix("+") && !$0.hasPrefix("+++") }.isEmpty)
  }

  // MARK: - Gate 1: CAST.md must exist

  @Test("Prune exits non-zero and writes nothing when CAST.md is absent")
  func absentCastFileExitsNonZero() async throws {
    let projectURL = try makeProject(projectMd: Self.matchingProjectMd, cast: nil)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let projectSha = try sha256(of: projectURL)

    let cmd = try PruneCastCommand.parse(["--project", projectURL.path])
    // ValidationError maps to a non-zero (EX_USAGE) exit in ArgumentParser.
    await #expect(throws: ValidationError.self) { try await cmd.run() }

    #expect(try sha256(of: projectURL) == projectSha)
  }

  // MARK: - Gate 2: verification must pass

  @Test("Prune exits non-zero and writes nothing when the rosters diverge")
  func divergentRostersExitNonZero() async throws {
    // CAST.md is missing THE PRACTITIONER — verification reports a
    // membership divergence, so prune must refuse.
    var drifted = Self.matchingCast
    drifted.removeLast()
    let projectURL = try makeProject(projectMd: Self.matchingProjectMd, cast: drifted)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let projectSha = try sha256(of: projectURL)
    let castSha = try sha256(of: castURL(projectURL))

    let cmd = try PruneCastCommand.parse(["--project", projectURL.path])
    await #expect(throws: ExitCode(1)) { try await cmd.run() }

    #expect(try sha256(of: projectURL) == projectSha)
    #expect(try sha256(of: castURL(projectURL)) == castSha)
  }

  // MARK: - Idempotency

  @Test("A second consecutive prune exits 0 and leaves PROJECT.md SHA-256-identical")
  func secondRunIsCleanNoOp() async throws {
    let projectURL = try makeProject(projectMd: Self.matchingProjectMd, cast: Self.matchingCast)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    let first = try PruneCastCommand.parse(["--project", projectURL.path])
    try await first.run()
    let shaAfterFirst = try sha256(of: projectURL)

    // Second run: no `cast:` block left. A clean return maps to exit 0.
    let second = try PruneCastCommand.parse(["--project", projectURL.path])
    try await second.run()

    #expect(try sha256(of: projectURL) == shaAfterFirst)
  }

  @Test("A PROJECT.md that never had a cast: block is a zero-exit no-op")
  func neverHadCastBlockIsNoOp() async throws {
    let projectURL = try makeProject(projectMd: Self.prunedProjectMd, cast: Self.matchingCast)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let projectSha = try sha256(of: projectURL)

    let cmd = try PruneCastCommand.parse(["--project", projectURL.path])
    try await cmd.run()

    #expect(try sha256(of: projectURL) == projectSha)
  }

  // MARK: - --dry-run

  @Test("--dry-run leaves PROJECT.md SHA-256-identical")
  func dryRunWritesNothing() async throws {
    let projectURL = try makeProject(projectMd: Self.matchingProjectMd, cast: Self.matchingCast)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let projectSha = try sha256(of: projectURL)
    let castSha = try sha256(of: castURL(projectURL))

    let cmd = try PruneCastCommand.parse(["--project", projectURL.path, "--dry-run"])
    try await cmd.run()

    #expect(try sha256(of: projectURL) == projectSha)
    #expect(try sha256(of: castURL(projectURL)) == castSha)
  }

  // MARK: - Option surface

  @Test("prune cast parses --project, --cast, and --dry-run, with defaults")
  func parsesOptionSurface() throws {
    let defaulted = try PruneCastCommand.parse(["--project", "PROJECT.md"])
    #expect(defaulted.project == "PROJECT.md")
    #expect(defaulted.cast == "CAST.md")
    #expect(!defaulted.dryRun)

    let overridden = try PruneCastCommand.parse([
      "--project", "PROJECT.md", "--cast", "ROSTER.md", "--dry-run",
    ])
    #expect(overridden.cast == "ROSTER.md")
    #expect(overridden.dryRun)
  }

  @Test("prune cast rejects a --cast value carrying a path separator")
  func rejectsCastPathSeparators() async throws {
    let projectURL = try makeProject(projectMd: Self.matchingProjectMd, cast: Self.matchingCast)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    let cmd = try PruneCastCommand.parse([
      "--project", projectURL.path, "--cast", "../CAST.md",
    ])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }
}
