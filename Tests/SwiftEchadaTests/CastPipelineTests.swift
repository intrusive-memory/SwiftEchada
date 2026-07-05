import ArgumentParser
import Foundation
import SwiftProyecto
import Testing

@testable import EchadaCLICore

/// Offline coverage for the `cast` meta-orchestrator's pipeline behavior
/// (S8): that a `--dry-run` invocation runs bootstrap + `generate cast` for
/// real but stops before the model-backed `generate prompt` / `generate vox`
/// stages, and that the orchestrator's single cascading `--force` flag
/// actually reaches the stage(s) it fans out to.
///
/// Every fixture here lives in a freshly-created temp directory with no
/// PROJECT.md anywhere in its ancestor chain, to avoid the known orchestrator
/// edge case where `ProjectDiscovery.findProjectMd` finds an ancestor
/// PROJECT.md while `generate cast` itself checks only the literal
/// `--project` path (see `CastCommand.ensureProjectMarkdown`). That case is
/// already covered by `GenerateCastCommandTests`'s bootstrap suite and is not
/// re-tested here.
@Suite("CastCommand pipeline — dry-run + --force cascade (offline)")
struct CastPipelineTests {

  /// A single script with two character cues, enough to exercise the
  /// offline, heuristic `generate cast` discovery stage.
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

  // MARK: - Dry-run: bootstrap + generate cast run for real; model stages do not

  @Test(
    "Full `cast --dry-run` bootstraps PROJECT.md, populates the cast list, and creates no voices/ output"
  )
  func dryRunBootstrapsAndDiscoversCastButStopsBeforeModelStages() async throws {
    let (projectDir, projectFile) = try makeIsolatedProject(scripts: [
      "ep1.fountain": Self.scriptWithTwoCharacters
    ])
    defer { try? FileManager.default.removeItem(at: projectDir.deletingLastPathComponent()) }

    #expect(!FileManager.default.fileExists(atPath: projectFile.path))

    let cmd = try CastCommand.parse(["--project", projectFile.path, "--dry-run"])
    try await cmd.run()

    // Stage 0 (bootstrap) + Stage 1 (`generate cast`) ran for real: PROJECT.md
    // now exists with a populated cast list.
    #expect(FileManager.default.fileExists(atPath: projectFile.path))
    let (frontMatter, _) = try ProjectMarkdownParser().parse(fileURL: projectFile)
    #expect(frontMatter.cast?.map(\.character) == ["MAYA", "NOAH"])

    // Nothing from the model-backed stages ran: no voicePrompts were written...
    for member in frontMatter.cast ?? [] {
      #expect(member.voiceDescription == nil)
      #expect(member.voices.isEmpty)
    }
    // ...and `generate vox` never got far enough to create its output directory.
    let voicesDir = projectDir.appendingPathComponent("voices")
    #expect(!FileManager.default.fileExists(atPath: voicesDir.path))
  }

  // MARK: - `--force` cascade

  /// The orchestrator maps a single `--force` onto `castStage.force`,
  /// `promptStage.force`, and `voxStage.forceRegenerate` (verified by reading
  /// `CastCommand.run()`). The prompt/vox legs are only reachable through
  /// model-backed work (Foundation Model / MLX TTS), which is out of scope
  /// for an offline test, so the cleanest observable seam offline is the cast
  /// leg: `--dry-run` still runs `generate cast` for real before stopping, so
  /// running the same discovery twice -- once without `--force` and once with
  /// it -- against a project whose existing cast has diverged from the
  /// current source material demonstrates the flag actually reaches the cast
  /// stage (default merges/adds only; `--force` re-syncs and drops stale
  /// entries). The prompt/vox force-forwarding itself is not independently
  /// observable without invoking the model stages; that is a documented
  /// limitation of this offline suite, not a gap in the orchestrator.
  @Test("Cascading --force reaches the cast stage: re-syncs and drops stale cast entries")
  func forceCascadesToCastStage() async throws {
    let (projectDir, projectFile) = try makeIsolatedProject(scripts: [
      "ep1.fountain": Self.scriptWithTwoCharacters
    ])
    defer { try? FileManager.default.removeItem(at: projectDir.deletingLastPathComponent()) }

    // Pre-seed PROJECT.md (bypassing bootstrap) with a cast containing a
    // character ("GHOST") that no longer appears in the current source
    // material, alongside one ("MAYA") that does.
    let seededFrontMatter = ProjectFrontMatter(
      type: "project",
      title: "Pipeline Force Test",
      author: "Test",
      created: Date(timeIntervalSince1970: 0),
      episodesDir: "episodes",
      filePattern: FilePattern("*.fountain"),
      cast: [
        CastMember(character: "GHOST", actor: "Stale Actor"),
        CastMember(character: "MAYA", actor: "Existing Actor"),
      ]
    )
    try ProjectMarkdownParser().write(frontMatter: seededFrontMatter, body: "", to: projectFile)

    // Without --force: default merge only adds newly-discovered characters;
    // GHOST (no longer in the source) is left in place.
    let withoutForce = try CastCommand.parse(["--project", projectFile.path, "--dry-run"])
    try await withoutForce.run()
    let (afterDefault, _) = try ProjectMarkdownParser().parse(fileURL: projectFile)
    #expect(afterDefault.cast?.map(\.character).sorted() == ["GHOST", "MAYA", "NOAH"])

    // With --force: the orchestrator's cascading force reaches the cast
    // stage, which re-syncs to exactly what's discovered now -- GHOST drops.
    let withForce = try CastCommand.parse([
      "--project", projectFile.path, "--dry-run", "--force",
    ])
    try await withForce.run()
    let (afterForce, _) = try ProjectMarkdownParser().parse(fileURL: projectFile)
    #expect(afterForce.cast?.map(\.character).sorted() == ["MAYA", "NOAH"])

    // MAYA's downstream fields survive the re-sync (force preserves fields
    // for characters that persist -- it only drops those that vanished).
    let maya = afterForce.cast?.first { $0.character == "MAYA" }
    #expect(maya?.actor == "Existing Actor")
  }

  @Test(
    "CastCommand.parse maps a bare --force flag onto the `force` property forwarded to every stage")
  func castCommandParsesForceFlag() throws {
    let cmd = try CastCommand.parse(["--force"])
    #expect(cmd.force)

    let withoutFlag = try CastCommand.parse([])
    #expect(!withoutFlag.force)
  }
}
