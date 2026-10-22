import ArgumentParser
import Foundation
import SwiftProyecto
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// Offline coverage for the `cast` meta-orchestrator's pipeline behavior: a
/// `--dry-run` invocation runs bootstrap + migration for real but stops before
/// the model-backed `generate prompt` / `generate vox` stages, and echada no
/// longer discovers cast members from the scripts (EC-P11, 3.0.0).
///
/// Every fixture here lives in a freshly-created temp directory with no
/// PROJECT.md anywhere in its ancestor chain, so bootstrap always scaffolds
/// the project asked for. The ancestor case is covered by `CastFileTests`'s
/// bootstrap suite.
@Suite("CastCommand pipeline — dry-run (offline)")
struct CastPipelineTests {

  /// A single script with two character cues. echada must not turn them into
  /// cast members.
  static let scriptWithTwoCharacters = """
    INT. KITCHEN - MORNING

    Coffee brews. Morning light through the window.

    MAYA
    Did you sleep at all?

    NOAH
    A little. Enough to function.
    """

  /// Builds a fresh, fully-isolated temp project directory (no PROJECT.md,
  /// no ancestor PROJECT.md) with an `episodes/` folder containing the given
  /// scripts. Returns `(projectDir, projectFileURL)`. Caller removes the
  /// returned directory's parent via `defer`.
  private func makeIsolatedProject(scripts: [String: String]) throws -> (
    projectDir: URL, projectFile: URL
  ) {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-pipeline-\(UUID().uuidString)")
    let projectDir = base.appendingPathComponent("show")
    let episodesDir = projectDir.appendingPathComponent("episodes")
    try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
    for (name, content) in scripts {
      try content.write(
        to: episodesDir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    return (projectDir, projectDir.appendingPathComponent("PROJECT.md"))
  }

  @Test(
    "`cast --dry-run` bootstraps PROJECT.md and an empty CAST.md, discovers nobody, creates no voices"
  )
  func dryRunBootstrapsWithoutDiscovery() async throws {
    let (projectDir, projectFile) = try makeIsolatedProject(scripts: [
      "ep1.fountain": Self.scriptWithTwoCharacters
    ])
    defer { try? FileManager.default.removeItem(at: projectDir.deletingLastPathComponent()) }

    #expect(!FileManager.default.fileExists(atPath: projectFile.path))

    let cmd = try CastCommand.parse(["--project", projectFile.path, "--dry-run"])
    try await cmd.run()

    #expect(FileManager.default.fileExists(atPath: projectFile.path))
    #expect(
      try LegacyProjectCastReader.readCast(fileURL: projectFile).isEmpty,
      "PROJECT.md must stay cast-free — the roster's home is CAST.md")
    let castFile = projectDir.appendingPathComponent("CAST.md")
    #expect(try CastMarkdownParser().parse(fileURL: castFile).cast.isEmpty)

    #expect(
      !FileManager.default.fileExists(atPath: projectDir.appendingPathComponent("voices").path))
    #expect(
      !FileManager.default.fileExists(atPath: projectDir.appendingPathComponent("characters").path))
  }

  @Test("`cast --dry-run` leaves an existing roster exactly as it was")
  func dryRunLeavesExistingRosterAlone() async throws {
    let (projectDir, projectFile) = try makeIsolatedProject(scripts: [
      "ep1.fountain": Self.scriptWithTwoCharacters
    ])
    defer { try? FileManager.default.removeItem(at: projectDir.deletingLastPathComponent()) }

    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Pipeline Roster Test",
      author: "Test",
      created: Date(timeIntervalSince1970: 0),
      episodesDir: "episodes",
      filePattern: FilePattern("*.fountain")
    )
    try ProjectMarkdownParser().write(frontMatter: frontMatter, body: "", to: projectFile)
    let castFile = projectDir.appendingPathComponent("CAST.md")
    try CastMarkdownParser().write(
      document: CastDocument(cast: [SwiftReparto.CastMember(character: "MAYA", actor: "Someone")]),
      to: castFile)
    let castBefore = try Data(contentsOf: castFile)

    try await CastCommand.parse(["--project", projectFile.path, "--dry-run", "--force"]).run()

    // NOAH appears in the script but is not added; MAYA keeps her actor.
    #expect(try Data(contentsOf: castFile) == castBefore)
  }
}
