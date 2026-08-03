import ArgumentParser
import CryptoKit
import Foundation
import FoundationModels
import SwiftProyecto
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// EC-18 (S8): the `echada cast` orchestrator's *call sequence* must preserve a
/// hand-authored `CAST.md` markdown body byte-for-byte, and must leave
/// `PROJECT.md` untouched (SHA-256-identical).
///
/// SwiftReparto's own round-trip tests prove the *parser* is lossless; they do
/// not prove that this repo's read-modify-write sequence is. This is the issue
/// #44/#55 class of bug, where a field-by-field rebuild silently destroyed
/// content the writer never knew about.
///
/// Two layers of coverage:
///
/// 1. **Offline (always runs, the CI regression gate)** — `echada cast
///    --dry-run` runs bootstrap + `generate cast` for real (the orchestrator
///    hardcodes the cast stage to a non-dry run) and rewrites `CAST.md`, so the
///    write path under test genuinely executes without any model.
/// 2. **Model-gated full run** — the complete pipeline (cast → prompt → vox)
///    with the same assertions, gated to skip wherever the Foundation Model or
///    the TTS weights are absent (same gates as `ModelBackedGenerationTests`).
@Suite("EC-18 — echada cast preserves the CAST.md body and never touches PROJECT.md")
struct CastBodyPreservationTests {

  // MARK: - Fixtures

  /// A script whose cue set ("MAYA", "NOAH") is a strict superset of the
  /// hand-authored roster below, so the cast stage discovers a NEW character
  /// and must rewrite CAST.md — making the body-preservation assertion
  /// non-vacuous.
  static let twoCharacterScript = """
    INT. KITCHEN - MORNING

    Coffee brews.

    MAYA
    Did you sleep at all?

    NOAH
    A little. Enough to function.
    """

  /// One-character script for the gated full-pipeline run (kept minimal so the
  /// model work stays fast when the gated test actually executes).
  static let oneCharacterScript = """
    INT. STUDIO - NIGHT

    The room is quiet.

    NARR
    Welcome back to the show.

    NARR
    Tonight we keep it short.
    """

  /// The hand-authored body region that must survive byte-for-byte (it is the
  /// byte-exact remainder after the closing `---` delimiter line, trailing
  /// newline included). Mixed markdown on purpose: heading, bold, em-dash
  /// prose, a fenced code block, unusual spacing — exactly the kind of content
  /// a rebuild-style writer mangles.
  static let handAuthoredBody = """
    ## Major Characters

    - **MAYA** — the anchor.   Hand-authored casting notes with *markdown*,
      double  spaces, and a fenced block:

    ```text
    keep me byte-for-byte — including this em-dash and trailing colon:
    ```

    ### Minor notes

    Nothing here is representable in front matter, and nothing here may move.

    """

  /// Raw, hand-written CAST.md content (NOT produced by the writer) whose body
  /// region is exactly `handAuthoredBody`.
  static func handAuthoredCastMarkdown(roster: String) -> String {
    """
    ---
    type: cast
    schemaVersion: 1
    cast:
    \(roster)
    ---
    \(handAuthoredBody)
    """
  }

  // MARK: - Helpers

  /// Builds a fully-isolated temp project directory (no PROJECT.md in any
  /// ancestor) with an `episodes/` folder holding the given scripts.
  private func makeIsolatedProject(scripts: [String: String]) throws -> (
    projectDir: URL, projectFile: URL
  ) {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-body-\(UUID().uuidString)")
    let projectDir = base.appendingPathComponent("show")
    let episodesDir = projectDir.appendingPathComponent("episodes")
    try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
    for (name, content) in scripts {
      try content.write(
        to: episodesDir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    return (projectDir, projectDir.appendingPathComponent("PROJECT.md"))
  }

  private func writeProjectMarkdown(title: String, to projectFile: URL) throws {
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: title,
      author: "Test",
      created: Date(timeIntervalSince1970: 0),
      episodesDir: "episodes",
      filePattern: FilePattern("*.fountain")
    )
    try ProjectMarkdownParser().write(frontMatter: frontMatter, body: "", to: projectFile)
  }

  /// Extracts the raw body region of a front-mattered markdown file: every byte
  /// after the closing `---` delimiter line. Deliberately parser-free, so the
  /// comparison is on file bytes, not on any type's idea of the body.
  private func bodyRegionBytes(of fileURL: URL) throws -> [UInt8] {
    let text = try String(contentsOf: fileURL, encoding: .utf8)
    #expect(text.hasPrefix("---\n"), "expected a front-matter block at \(fileURL.path)")
    let close = try #require(
      text.range(of: "\n---\n"), "expected a closing front-matter delimiter in \(fileURL.path)")
    return Array(text[close.upperBound...].utf8)
  }

  private func sha256(of url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  // MARK: - Offline regression (always runs)

  @Test(
    "Hand-authored CAST.md body survives `echada cast --dry-run` byte-for-byte while the roster grows"
  )
  func offlineCastRunPreservesHandAuthoredBody() async throws {
    let (projectDir, projectFile) = try makeIsolatedProject(scripts: [
      "ep1.fountain": Self.twoCharacterScript
    ])
    defer { try? FileManager.default.removeItem(at: projectDir.deletingLastPathComponent()) }

    try writeProjectMarkdown(title: "Body Preservation", to: projectFile)

    // Hand-write CAST.md (raw text, not the writer) with MAYA only, so the
    // cast stage MUST rewrite the file to add NOAH.
    let castFile = projectDir.appendingPathComponent("CAST.md")
    let raw = Self.handAuthoredCastMarkdown(
      roster: """
          - character: MAYA
            actor: Existing Actor
        """)
    try raw.write(to: castFile, atomically: true, encoding: .utf8)

    let bodyBefore = try bodyRegionBytes(of: castFile)
    #expect(bodyBefore == Array(Self.handAuthoredBody.utf8))
    let projectShaBefore = try sha256(of: projectFile)

    let cmd = try CastCommand.parse(["--project", projectFile.path, "--dry-run"])
    try await cmd.run()

    // The rewrite genuinely happened: NOAH was discovered and merged in.
    let roster = try CastMarkdownParser().parse(fileURL: castFile).cast
    #expect(roster.map(\.character).sorted() == ["MAYA", "NOAH"])
    #expect(roster.first { $0.character == "MAYA" }?.actor == "Existing Actor")

    // EC-18: the hand-authored body region is byte-identical.
    let bodyAfter = try bodyRegionBytes(of: castFile)
    #expect(bodyAfter == bodyBefore, "CAST.md body region must survive byte-for-byte")

    // Companion assertion: PROJECT.md is SHA-256-unchanged by the run.
    #expect(try sha256(of: projectFile) == projectShaBefore)
  }

  @Test("--cast cascades from the orchestrator: an overridden roster filename is the one written")
  func castOptionCascadesToTheCastStage() async throws {
    let (projectDir, projectFile) = try makeIsolatedProject(scripts: [
      "ep1.fountain": Self.twoCharacterScript
    ])
    defer { try? FileManager.default.removeItem(at: projectDir.deletingLastPathComponent()) }

    try writeProjectMarkdown(title: "Cascade", to: projectFile)

    let cmd = try CastCommand.parse([
      "--project", projectFile.path, "--cast", "ROSTER.md", "--dry-run",
    ])
    try await cmd.run()

    // The override reached the bootstrap + cast stage: ROSTER.md exists and
    // carries the discovered roster; no CAST.md was created anywhere.
    let rosterFile = projectDir.appendingPathComponent("ROSTER.md")
    let roster = try CastMarkdownParser().parse(fileURL: rosterFile).cast
    #expect(roster.map(\.character) == ["MAYA", "NOAH"])
    #expect(
      !FileManager.default.fileExists(
        atPath: projectDir.appendingPathComponent("CAST.md").path))
  }

  @Test("Bootstrap ensures CAST.md exists even before discovery (EC-15)")
  func bootstrapCreatesCastMarkdownWhenAbsent() async throws {
    let (projectDir, projectFile) = try makeIsolatedProject(scripts: [
      "ep1.fountain": Self.twoCharacterScript
    ])
    defer { try? FileManager.default.removeItem(at: projectDir.deletingLastPathComponent()) }

    // No PROJECT.md and no CAST.md: step 0 must bootstrap both.
    let cmd = try CastCommand.parse(["--project", projectFile.path, "--dry-run"])
    try await cmd.run()

    #expect(FileManager.default.fileExists(atPath: projectFile.path))
    let castFile = projectDir.appendingPathComponent("CAST.md")
    #expect(FileManager.default.fileExists(atPath: castFile.path))
    let roster = try CastMarkdownParser().parse(fileURL: castFile).cast
    #expect(roster.map(\.character) == ["MAYA", "NOAH"])
  }

  // MARK: - Model-gated full run (skips where either model is absent)

  /// The full, un-truncated `echada cast` pipeline — cast, prompt (Foundation
  /// Model), and vox (MLX TTS) all write CAST.md — with the same two EC-18
  /// assertions. Gate conjunction mirrors
  /// `ModelBackedGenerationTests.fullCastPipelineProducesAllFourOutputs`.
  @Test(
    "Hand-authored CAST.md body and PROJECT.md bytes survive the FULL echada cast pipeline",
    .enabled(if: SystemLanguageModel.default.isAvailable && TTSWeights.present))
  func fullPipelinePreservesBodyAndProjectBytes() async throws {
    let (projectDir, projectFile) = try makeIsolatedProject(scripts: [
      "ep1.fountain": Self.oneCharacterScript
    ])
    defer { try? FileManager.default.removeItem(at: projectDir.deletingLastPathComponent()) }

    try writeProjectMarkdown(title: "Full Run Body Preservation", to: projectFile)

    let castFile = projectDir.appendingPathComponent("CAST.md")
    let raw = Self.handAuthoredCastMarkdown(
      roster: """
          - character: NARR
        """)
    try raw.write(to: castFile, atomically: true, encoding: .utf8)

    let bodyBefore = try bodyRegionBytes(of: castFile)
    let projectShaBefore = try sha256(of: projectFile)

    let cmd = try CastCommand.parse(["--project", projectFile.path])
    try await cmd.run()

    // All three stages wrote through: NARR gained a prompt and a .vox pointer.
    let roster = try CastMarkdownParser().parse(fileURL: castFile).cast
    let narr = try #require(roster.first { $0.character == "NARR" })
    #expect(!(narr.voicePrompt ?? "").isEmpty)
    #expect(narr.voices["voxalta"] == ["voices/NARR.vox"])

    // EC-18, across the full pipeline.
    #expect(try bodyRegionBytes(of: castFile) == bodyBefore)
    #expect(try sha256(of: projectFile) == projectShaBefore)
  }
}
