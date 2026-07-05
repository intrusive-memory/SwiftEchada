import ArgumentParser
import Foundation
import SwiftProyecto
import Testing

@testable import EchadaCLICore

/// Offline coverage for `generate cast` (`GenerateCastCommand`, R-TEST-1) and the
/// `cast` orchestrator's PROJECT.md bootstrap step (`CastCommand`, R-TEST-2).
///
/// Everything here runs against fixture Fountain text and temp-directory
/// PROJECT.md files -- no LLM/ML model is ever invoked, matching the
/// heuristic-only, no-model contract of both `generate cast` and the bootstrap.
@Suite("GenerateCastCommand + PROJECT.md bootstrap — offline")
struct GenerateCastCommandTests {

  // MARK: - Fixture Fountain text

  /// Two characters, standard Fountain cue formatting (scene heading + action +
  /// blank-line-separated character cues), mirroring SwiftProyecto's own
  /// CastExtractor fixtures so SwiftCompartido's parser recognizes the cues.
  static let episodeOne = """
    INT. HOUSE - DAY

    Some action description sets the scene.

    ALICE
    Hello there, friend.

    BOB
    Good morning to you too.
    """

  /// Shares BOB with episodeOne (to exercise de-duplication across files) and
  /// introduces DAVE.
  static let episodeTwo = """
    INT. STREET - NIGHT

    More action lines describing the scene outside.

    BOB
    Let's go find DAVE.

    DAVE
    I'm right here, waiting for you both.
    """

  /// No character cues at all -- pure scene description, no dialogue blocks.
  static let noCharactersScript = """
    INT. EMPTY ROOM - DAY

    Nothing happens. The room is still and silent.

    A single dust mote drifts through a shaft of light.
    """

  // MARK: - Fixture helpers

  /// Builds a fresh temp-directory project: an `episodes/` subfolder containing
  /// the given scripts, and a PROJECT.md with the given (optional) existing cast.
  /// Returns the PROJECT.md URL. Caller removes the parent directory via `defer`.
  private func makeProject(
    cast: [CastMember]? = nil,
    scripts: [String: String] = [:]
  ) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("generate-cast-cmd-\(UUID().uuidString)")
    let episodesDir = dir.appendingPathComponent("episodes")
    try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
    for (name, content) in scripts {
      try content.write(
        to: episodesDir.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Test Cast Discovery",
      author: "Test",
      created: Date(timeIntervalSince1970: 0),
      episodesDir: "episodes",
      filePattern: FilePattern("*.fountain"),
      cast: cast
    )
    let projectURL = dir.appendingPathComponent("PROJECT.md")
    try ProjectMarkdownParser().write(frontMatter: frontMatter, body: "", to: projectURL)
    return projectURL
  }

  private func readCast(_ url: URL) throws -> [CastMember] {
    try ProjectMarkdownParser().parse(fileURL: url).0.cast ?? []
  }

  // MARK: - Discovery: names found, sorted, and de-duplicated

  @Test("Discovers characters across scripts, de-duplicated and sorted, with no other fields set")
  func discoversCharactersSortedAndUnique() async throws {
    let url = try makeProject(
      cast: nil,
      scripts: ["ep1.fountain": Self.episodeOne, "ep2.fountain": Self.episodeTwo])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let cmd = try GenerateCastCommand.parse(["--project", url.path])
    try await cmd.run()

    let cast = try readCast(url)
    // ALICE, BOB, DAVE -- BOB appears in both scripts but must not be duplicated.
    #expect(cast.map(\.character) == ["ALICE", "BOB", "DAVE"])
    for member in cast {
      #expect(member.actor == nil)
      #expect(member.voiceDescription == nil)
      #expect(member.voices.isEmpty)
      #expect(member.language == nil)
    }
  }

  // MARK: - Default merge: no clobbering of downstream fields

  @Test("Default merge adds newly-discovered characters without touching existing downstream fields")
  func defaultMergePreservesExistingFields() async throws {
    let existing = [
      CastMember(
        character: "ALICE",
        actor: "Jane",
        voiceDescription: "A warm, measured female narrator.",
        voices: ["voxalta": ["alice.vox"]],
        language: "en"
      ),
      // EVE is not discovered by either script this run -- default merge must not drop it.
      CastMember(character: "EVE", actor: "Existing Actor"),
    ]
    let url = try makeProject(
      cast: existing,
      scripts: ["ep1.fountain": Self.episodeOne, "ep2.fountain": Self.episodeTwo])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let cmd = try GenerateCastCommand.parse(["--project", url.path])
    try await cmd.run()

    let cast = try readCast(url)
    let byName = Dictionary(uniqueKeysWithValues: cast.map { ($0.character, $0) })

    // Union of existing + discovered: ALICE, BOB, DAVE, EVE.
    #expect(cast.map(\.character) == ["ALICE", "BOB", "DAVE", "EVE"])

    // ALICE's downstream fields must survive untouched.
    let alice = try #require(byName["ALICE"])
    #expect(alice.actor == "Jane")
    #expect(alice.voiceDescription == "A warm, measured female narrator.")
    #expect(alice.voices == ["voxalta": ["alice.vox"]])
    #expect(alice.language == "en")

    // EVE (not present in any script) is preserved by default, not dropped.
    let eve = try #require(byName["EVE"])
    #expect(eve.actor == "Existing Actor")

    // BOB and DAVE are brand new -- empty downstream fields.
    let bob = try #require(byName["BOB"])
    #expect(bob.actor == nil)
    #expect(bob.voices.isEmpty)
  }

  // MARK: - --force: re-sync to discovered set, keep fields for survivors, drop the rest

  @Test("--force re-syncs to exactly the discovered characters, dropping missing ones but keeping fields for survivors")
  func forceResyncsAndDropsMissingCharacters() async throws {
    let existing = [
      CastMember(
        character: "ALICE",
        actor: "Jane",
        voiceDescription: "A warm, measured female narrator.",
        voices: ["voxalta": ["alice.vox"]],
        language: "en"
      ),
      CastMember(character: "EVE", actor: "Existing Actor"),
    ]
    let url = try makeProject(
      cast: existing,
      scripts: ["ep1.fountain": Self.episodeOne, "ep2.fountain": Self.episodeTwo])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let cmd = try GenerateCastCommand.parse(["--project", url.path, "--force"])
    try await cmd.run()

    let cast = try readCast(url)
    let byName = Dictionary(uniqueKeysWithValues: cast.map { ($0.character, $0) })

    // Only what's discovered this run survives -- EVE is dropped.
    #expect(cast.map(\.character) == ["ALICE", "BOB", "DAVE"])
    #expect(byName["EVE"] == nil)

    // ALICE persists and keeps her downstream fields.
    let alice = try #require(byName["ALICE"])
    #expect(alice.actor == "Jane")
    #expect(alice.voiceDescription == "A warm, measured female narrator.")
    #expect(alice.voices == ["voxalta": ["alice.vox"]])
    #expect(alice.language == "en")

    // BOB and DAVE are newly discovered -- empty downstream fields.
    let dave = try #require(byName["DAVE"])
    #expect(dave.actor == nil)
    #expect(dave.voices.isEmpty)
  }

  // MARK: - --dry-run writes nothing

  @Test("--dry-run previews discovered characters and writes nothing")
  func dryRunWritesNothing() async throws {
    let existing = [CastMember(character: "ALICE", actor: "Jane")]
    let url = try makeProject(
      cast: existing,
      scripts: ["ep1.fountain": Self.episodeOne, "ep2.fountain": Self.episodeTwo])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let before = try String(contentsOf: url, encoding: .utf8)

    let cmd = try GenerateCastCommand.parse(["--project", url.path, "--dry-run"])
    try await cmd.run()

    let after = try String(contentsOf: url, encoding: .utf8)
    #expect(before == after)
  }

  @Test("--dry-run combined with --force still writes nothing")
  func dryRunWithForceWritesNothing() async throws {
    let existing = [CastMember(character: "ALICE", actor: "Jane")]
    let url = try makeProject(
      cast: existing,
      scripts: ["ep1.fountain": Self.episodeOne])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let before = try String(contentsOf: url, encoding: .utf8)

    let cmd = try GenerateCastCommand.parse(["--project", url.path, "--dry-run", "--force"])
    try await cmd.run()

    let after = try String(contentsOf: url, encoding: .utf8)
    #expect(before == after)
  }

  // MARK: - Empty / no-scripts path errors cleanly

  @Test("No script files under episodesDir errors cleanly")
  func noScriptFilesThrows() async throws {
    // `episodes/` exists but is empty -- no files match the filePattern.
    let url = try makeProject(cast: nil, scripts: [:])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let cmd = try GenerateCastCommand.parse(["--project", url.path])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  @Test("A missing PROJECT.md file is rejected")
  func missingProjectFileThrows() async throws {
    let missing = FileManager.default.temporaryDirectory
      .appendingPathComponent("does-not-exist-\(UUID().uuidString)")
      .appendingPathComponent("PROJECT.md")
    let cmd = try GenerateCastCommand.parse(["--project", missing.path])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  @Test("Scripts with zero character cues leave PROJECT.md unchanged (no throw)")
  func zeroCharactersDiscoveredLeavesProjectUnchanged() async throws {
    let url = try makeProject(cast: nil, scripts: ["empty.fountain": Self.noCharactersScript])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let before = try String(contentsOf: url, encoding: .utf8)

    let cmd = try GenerateCastCommand.parse(["--project", url.path])
    try await cmd.run()

    let after = try String(contentsOf: url, encoding: .utf8)
    #expect(before == after)
  }
}

// MARK: - PROJECT.md bootstrap (R-TEST-2), via the `cast` orchestrator

/// The bootstrap logic lives in `CastCommand.ensureProjectMarkdown`, which is
/// private, so it is exercised the way a real invocation would reach it: via
/// `CastCommand`'s public `run()`. `--dry-run` is used throughout so the
/// pipeline never reaches the model-backed prompt/vox stages -- the bootstrap
/// and cast-discovery steps are offline and run for real under `--dry-run`
/// (per `CastCommand`'s documented contract), then execution stops.
@Suite("CastCommand PROJECT.md bootstrap — offline")
struct CastCommandBootstrapTests {

  @Test("Bootstrap creates PROJECT.md with inferred title, episodesDir, and filePattern when absent")
  func bootstrapCreatesProjectMarkdown() async throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-bootstrap-\(UUID().uuidString)")
    let projectDir = base.appendingPathComponent("my-cool-podcast")
    let episodesDir = projectDir.appendingPathComponent("episodes")
    try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    try GenerateCastCommandTests.episodeOne.write(
      to: episodesDir.appendingPathComponent("ep1.fountain"), atomically: true, encoding: .utf8)

    let projectFile = projectDir.appendingPathComponent("PROJECT.md")
    #expect(!FileManager.default.fileExists(atPath: projectFile.path))

    let cmd = try CastCommand.parse(["--project", projectFile.path, "--dry-run"])
    try await cmd.run()

    #expect(FileManager.default.fileExists(atPath: projectFile.path))
    let (frontMatter, _) = try ProjectMarkdownParser().parse(fileURL: projectFile)

    // Title inferred from the directory name ("my-cool-podcast" -> "My Cool Podcast").
    #expect(frontMatter.title == "My Cool Podcast")
    // "episodes" subdirectory exists, so it is picked as episodesDir.
    #expect(frontMatter.episodesDir == "episodes")
    #expect(frontMatter.resolvedFilePatterns == ["*.fountain"])

    // The offline cast-discovery stage also ran for real under --dry-run, so the
    // freshly bootstrapped project should already have ALICE and BOB merged in.
    #expect(frontMatter.cast?.map(\.character) == ["ALICE", "BOB"])
  }

  @Test("Bootstrap infers *.txt filePattern for a non-fountain project so generate cast finds the scripts")
  func bootstrapInfersFilePatternForNonFountainProject() async throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-bootstrap-txt-\(UUID().uuidString)")
    let projectDir = base.appendingPathComponent("txt-podcast")
    let episodesDir = projectDir.appendingPathComponent("episodes")
    try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    // Scripts are .txt, not .fountain -- the hard-coded default would filter them out.
    try GenerateCastCommandTests.episodeOne.write(
      to: episodesDir.appendingPathComponent("ep1.txt"), atomically: true, encoding: .utf8)

    let projectFile = projectDir.appendingPathComponent("PROJECT.md")
    let cmd = try CastCommand.parse(["--project", projectFile.path, "--dry-run"])
    try await cmd.run()

    let (frontMatter, _) = try ProjectMarkdownParser().parse(fileURL: projectFile)
    // The inferred pattern must include *.txt so the immediately-following
    // generate cast stage matches the scripts instead of aborting.
    #expect(frontMatter.resolvedFilePatterns.contains("*.txt"))
    // Proof the pattern is actually usable: cast discovery ran for real under
    // --dry-run and merged the characters from the .txt script.
    #expect(frontMatter.cast?.map(\.character) == ["ALICE", "BOB"])
  }

  @Test("Bootstrap falls back to '.' for episodesDir when no episodes/ subdirectory exists")
  func bootstrapInfersDotEpisodesDirWhenNoEpisodesSubfolder() async throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-bootstrap-flat-\(UUID().uuidString)")
    let projectDir = base.appendingPathComponent("flat-project")
    try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    // Script lives directly in the project root -- no "episodes" subfolder.
    try GenerateCastCommandTests.episodeOne.write(
      to: projectDir.appendingPathComponent("ep1.fountain"), atomically: true, encoding: .utf8)

    let projectFile = projectDir.appendingPathComponent("PROJECT.md")
    let cmd = try CastCommand.parse(["--project", projectFile.path, "--dry-run"])
    try await cmd.run()

    let (frontMatter, _) = try ProjectMarkdownParser().parse(fileURL: projectFile)
    #expect(frontMatter.episodesDir == ".")
  }

  @Test("An existing PROJECT.md discovered nearby is left in place, not overwritten by bootstrap")
  func bootstrapLeavesExistingProjectInPlace() async throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-bootstrap-existing-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    // An existing project already lives at the root of `base`.
    let existingFrontMatter = ProjectFrontMatter(
      type: "project",
      title: "Already Bootstrapped",
      author: "Somebody",
      created: Date(timeIntervalSince1970: 0),
      episodesDir: "episodes",
      filePattern: FilePattern("*.fountain")
    )
    let existingProjectFile = base.appendingPathComponent("PROJECT.md")
    try ProjectMarkdownParser().write(
      frontMatter: existingFrontMatter, body: "", to: existingProjectFile)
    let originalContents = try String(contentsOf: existingProjectFile, encoding: .utf8)

    // Request a PROJECT.md that doesn't exist, in a nested subdirectory --
    // ProjectDiscovery.findProjectMd walks up to `base` and finds the existing file.
    let nestedDir = base.appendingPathComponent("nested")
    try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
    let requestedProjectFile = nestedDir.appendingPathComponent("PROJECT.md")

    // Sanity-check the discovery this test relies on, independent of CastCommand.
    #expect(ProjectDiscovery().findProjectMd(from: nestedDir) == existingProjectFile)

    let cmd = try CastCommand.parse(["--project", requestedProjectFile.path, "--dry-run"])
    // The bootstrap step detects the existing project via ProjectDiscovery and
    // leaves it in place, so it does NOT scaffold a competing PROJECT.md at the
    // requested nested path. The subsequent `generate cast` stage then looks for
    // a PROJECT.md at the exact requested path (which still doesn't exist there)
    // and fails cleanly -- it does not silently redirect to the discovered
    // ancestor file.
    await #expect(throws: ValidationError.self) { try await cmd.run() }

    #expect(!FileManager.default.fileExists(atPath: requestedProjectFile.path))
    let afterContents = try String(contentsOf: existingProjectFile, encoding: .utf8)
    #expect(afterContents == originalContents)
  }

  @Test("A PROJECT.md already present at the exact requested path is left untouched")
  func existingProjectAtExactPathIsLeftUntouched() async throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-bootstrap-exact-\(UUID().uuidString)")
    let episodesDir = base.appendingPathComponent("episodes")
    try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    try GenerateCastCommandTests.episodeOne.write(
      to: episodesDir.appendingPathComponent("ep1.fountain"), atomically: true, encoding: .utf8)

    let existingFrontMatter = ProjectFrontMatter(
      type: "project",
      title: "My Existing Project",
      author: "Somebody",
      created: Date(timeIntervalSince1970: 0),
      episodesDir: "episodes",
      filePattern: FilePattern("*.fountain")
    )
    let projectFile = base.appendingPathComponent("PROJECT.md")
    try ProjectMarkdownParser().write(frontMatter: existingFrontMatter, body: "", to: projectFile)

    let cmd = try CastCommand.parse(["--project", projectFile.path, "--dry-run"])
    try await cmd.run()

    let (frontMatter, _) = try ProjectMarkdownParser().parse(fileURL: projectFile)
    // Title/author/episodesDir untouched by bootstrap (it was already present).
    #expect(frontMatter.title == "My Existing Project")
    #expect(frontMatter.author == "Somebody")
    // The cast-discovery stage still ran for real under --dry-run and merged in ALICE/BOB.
    #expect(frontMatter.cast?.map(\.character) == ["ALICE", "BOB"])
  }
}
