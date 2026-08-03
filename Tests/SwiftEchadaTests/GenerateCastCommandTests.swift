import ArgumentParser
import Foundation
import SwiftProyecto
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// Offline coverage for `generate cast` (`GenerateCastCommand`, R-TEST-1) and the
/// `cast` orchestrator's PROJECT.md bootstrap step (`CastCommand`, R-TEST-2).
///
/// Everything here runs against fixture Fountain text and temp-directory
/// PROJECT.md files -- no LLM/ML model is ever invoked, matching the
/// heuristic-only, no-model contract of both `generate cast` and the bootstrap.
///
/// Since the CAST.md extraction (Sortie 4), `generate cast` writes the roster to
/// `CAST.md` beside PROJECT.md and never modifies PROJECT.md itself. A legacy
/// `cast:` block in PROJECT.md seeds the first CAST.md write (EC-7).
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
  /// the given scripts, and a PROJECT.md with the given (optional) legacy
  /// `cast:` block. Returns the PROJECT.md URL. Caller removes the parent
  /// directory via `defer`.
  private func makeProject(
    cast: [ProyectoCastMember]? = nil,
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

  static func castURL(besides projectURL: URL) -> URL {
    projectURL.deletingLastPathComponent().appendingPathComponent("CAST.md")
  }

  /// Reads the roster out of the CAST.md beside the given PROJECT.md.
  static func readCast(besides projectURL: URL) throws -> [SwiftReparto.CastMember] {
    try CastMarkdownParser().parse(fileURL: castURL(besides: projectURL)).cast
  }

  // MARK: - Discovery: names found, sorted, and de-duplicated

  @Test(
    "Discovers characters across scripts into CAST.md, de-duplicated and sorted, with no other fields set"
  )
  func discoversCharactersSortedAndUnique() async throws {
    let url = try makeProject(
      cast: nil,
      scripts: ["ep1.fountain": Self.episodeOne, "ep2.fountain": Self.episodeTwo])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let projectBefore = try String(contentsOf: url, encoding: .utf8)

    let cmd = try GenerateCastCommand.parse(["--project", url.path])
    try await cmd.run()

    let cast = try Self.readCast(besides: url)
    // ALICE, BOB, DAVE -- BOB appears in both scripts but must not be duplicated.
    #expect(cast.map(\.character) == ["ALICE", "BOB", "DAVE"])
    for member in cast {
      #expect(member.actor == nil)
      #expect(member.voicePrompt == nil)
      #expect(member.voices.isEmpty)
      #expect(member.language == nil)
    }

    // PROJECT.md is read-only to this command.
    #expect(try String(contentsOf: url, encoding: .utf8) == projectBefore)
  }

  // MARK: - Default merge: no clobbering of downstream fields

  @Test(
    "Default merge seeds the legacy cast, adds newly-discovered characters, and touches no existing field"
  )
  func defaultMergePreservesExistingFields() async throws {
    let existing = [
      ProyectoCastMember(
        character: "ALICE",
        actor: "Jane",
        voiceDescription: "A warm, measured female narrator.",
        voices: ["voxalta": ["alice.vox"]],
        language: "en"
      ),
      // EVE is not discovered by either script this run -- default merge must not drop it.
      ProyectoCastMember(character: "EVE", actor: "Existing Actor"),
    ]
    let url = try makeProject(
      cast: existing,
      scripts: ["ep1.fountain": Self.episodeOne, "ep2.fountain": Self.episodeTwo])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let projectBefore = try String(contentsOf: url, encoding: .utf8)

    let cmd = try GenerateCastCommand.parse(["--project", url.path])
    try await cmd.run()

    let cast = try Self.readCast(besides: url)
    let byName = Dictionary(uniqueKeysWithValues: cast.map { ($0.character, $0) })

    // Seeded legacy order first (ALICE, EVE), then newly-discovered appended
    // in sorted order (BOB, DAVE). Additive merge never reorders the roster.
    #expect(cast.map(\.character) == ["ALICE", "EVE", "BOB", "DAVE"])

    // ALICE's downstream fields must survive untouched.
    let alice = try #require(byName["ALICE"])
    #expect(alice.actor == "Jane")
    #expect(alice.voicePrompt == "A warm, measured female narrator.")
    #expect(alice.voices == ["voxalta": ["alice.vox"]])
    #expect(alice.language == "en")

    // EVE (not present in any script) is preserved by default, not dropped.
    let eve = try #require(byName["EVE"])
    #expect(eve.actor == "Existing Actor")

    // BOB and DAVE are brand new -- empty downstream fields.
    let bob = try #require(byName["BOB"])
    #expect(bob.actor == nil)
    #expect(bob.voices.isEmpty)

    // The legacy `cast:` block in PROJECT.md is left byte-for-byte in place.
    #expect(try String(contentsOf: url, encoding: .utf8) == projectBefore)
  }

  // MARK: - --force: re-sync to discovered set, keep fields for survivors, drop the rest

  @Test(
    "--force re-syncs to exactly the discovered characters, dropping missing ones but keeping fields for survivors"
  )
  func forceResyncsAndDropsMissingCharacters() async throws {
    let existing = [
      ProyectoCastMember(
        character: "ALICE",
        actor: "Jane",
        voiceDescription: "A warm, measured female narrator.",
        voices: ["voxalta": ["alice.vox"]],
        language: "en"
      ),
      ProyectoCastMember(character: "EVE", actor: "Existing Actor"),
    ]
    let url = try makeProject(
      cast: existing,
      scripts: ["ep1.fountain": Self.episodeOne, "ep2.fountain": Self.episodeTwo])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let cmd = try GenerateCastCommand.parse(["--project", url.path, "--force"])
    try await cmd.run()

    let cast = try Self.readCast(besides: url)
    let byName = Dictionary(uniqueKeysWithValues: cast.map { ($0.character, $0) })

    // Only what's discovered this run survives -- EVE is dropped.
    #expect(cast.map(\.character) == ["ALICE", "BOB", "DAVE"])
    #expect(byName["EVE"] == nil)

    // ALICE persists and keeps her downstream fields.
    let alice = try #require(byName["ALICE"])
    #expect(alice.actor == "Jane")
    #expect(alice.voicePrompt == "A warm, measured female narrator.")
    #expect(alice.voices == ["voxalta": ["alice.vox"]])
    #expect(alice.language == "en")

    // BOB and DAVE are newly discovered -- empty downstream fields.
    let dave = try #require(byName["DAVE"])
    #expect(dave.actor == nil)
    #expect(dave.voices.isEmpty)
  }

  // MARK: - --dry-run writes nothing

  @Test("--dry-run previews the roster and writes neither CAST.md nor PROJECT.md")
  func dryRunWritesNothing() async throws {
    let existing = [ProyectoCastMember(character: "ALICE", actor: "Jane")]
    let url = try makeProject(
      cast: existing,
      scripts: ["ep1.fountain": Self.episodeOne, "ep2.fountain": Self.episodeTwo])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let before = try String(contentsOf: url, encoding: .utf8)

    let cmd = try GenerateCastCommand.parse(["--project", url.path, "--dry-run"])
    try await cmd.run()

    let after = try String(contentsOf: url, encoding: .utf8)
    #expect(before == after)
    #expect(!FileManager.default.fileExists(atPath: Self.castURL(besides: url).path))
  }

  @Test("--dry-run combined with --force still writes nothing")
  func dryRunWithForceWritesNothing() async throws {
    let existing = [ProyectoCastMember(character: "ALICE", actor: "Jane")]
    let url = try makeProject(
      cast: existing,
      scripts: ["ep1.fountain": Self.episodeOne])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let before = try String(contentsOf: url, encoding: .utf8)

    let cmd = try GenerateCastCommand.parse(["--project", url.path, "--dry-run", "--force"])
    try await cmd.run()

    let after = try String(contentsOf: url, encoding: .utf8)
    #expect(before == after)
    #expect(!FileManager.default.fileExists(atPath: Self.castURL(besides: url).path))
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

  @Test("Scripts with zero character cues and no legacy cast create no CAST.md (no throw)")
  func zeroCharactersDiscoveredLeavesProjectUnchanged() async throws {
    let url = try makeProject(cast: nil, scripts: ["empty.fountain": Self.noCharactersScript])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let before = try String(contentsOf: url, encoding: .utf8)

    let cmd = try GenerateCastCommand.parse(["--project", url.path])
    try await cmd.run()

    let after = try String(contentsOf: url, encoding: .utf8)
    #expect(before == after)
    #expect(!FileManager.default.fileExists(atPath: Self.castURL(besides: url).path))
  }

  @Test("--force with zero discovered characters writes an empty roster to CAST.md")
  func forceWithZeroCharactersClearsStaleCast() async throws {
    // The legacy cast is entirely stale: the only script has no character cues,
    // so a --force re-sync ("exactly the characters found" = none) must produce
    // an empty roster rather than carrying the stale entries into CAST.md.
    let existing = [
      ProyectoCastMember(character: "ALICE", actor: "Jane"),
      ProyectoCastMember(character: "EVE", actor: "Existing Actor"),
    ]
    let url = try makeProject(
      cast: existing, scripts: ["empty.fountain": Self.noCharactersScript])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let projectBefore = try String(contentsOf: url, encoding: .utf8)

    let cmd = try GenerateCastCommand.parse(["--project", url.path, "--force"])
    try await cmd.run()

    #expect(try Self.readCast(besides: url).isEmpty)
    // The legacy block in PROJECT.md itself is still never touched.
    #expect(try String(contentsOf: url, encoding: .utf8) == projectBefore)
  }

  // MARK: - --cast filename override (EC-13, OQ-1)

  @Test("--cast overrides the filename inside the project directory")
  func castOptionOverridesFilename() async throws {
    let url = try makeProject(cast: nil, scripts: ["ep1.fountain": Self.episodeOne])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let cmd = try GenerateCastCommand.parse(["--project", url.path, "--cast", "ROSTER.md"])
    try await cmd.run()

    let rosterURL = url.deletingLastPathComponent().appendingPathComponent("ROSTER.md")
    let document = try CastMarkdownParser().parse(fileURL: rosterURL)
    #expect(document.cast.map(\.character) == ["ALICE", "BOB"])
    #expect(!FileManager.default.fileExists(atPath: Self.castURL(besides: url).path))
  }

  @Test(
    "--cast rejects values with path separators or that escape the project directory",
    arguments: ["sub/CAST.md", "../CAST.md", "..", ".", "", "/tmp/CAST.md", "a\\b.md"])
  func castOptionRejectsPathTraversal(value: String) async throws {
    let url = try makeProject(cast: nil, scripts: ["ep1.fountain": Self.episodeOne])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    let cmd = try GenerateCastCommand.parse(["--project", url.path, "--cast", value])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  @Test("generate cast --help lists the --cast option")
  func helpListsCastOption() {
    let help = GenerateCastCommand.helpMessage()
    #expect(help.contains("--cast"))
  }
}

// MARK: - PROJECT.md bootstrap (R-TEST-2), via the `cast` orchestrator

/// The bootstrap logic lives in `CastCommand.ensureProjectMarkdown`, which is
/// private, so it is exercised the way a real invocation would reach it: via
/// `CastCommand`'s public `run()`. `--dry-run` is used throughout so the
/// pipeline never reaches the model-backed prompt/vox stages -- the bootstrap
/// and cast-discovery steps are offline and run for real under `--dry-run`
/// (per `CastCommand`'s documented contract), then execution stops. The cast
/// stage writes its roster to CAST.md beside the (possibly just-bootstrapped)
/// PROJECT.md.
@Suite("CastCommand PROJECT.md bootstrap — offline")
struct CastCommandBootstrapTests {

  @Test(
    "Bootstrap creates PROJECT.md with inferred title, episodesDir, and filePattern when absent")
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

    // The cast stage writes the roster to CAST.md, never into PROJECT.md.
    #expect(try LegacyProjectCastReader.readCast(fileURL: projectFile).isEmpty)
    let roster = try GenerateCastCommandTests.readCast(besides: projectFile)
    #expect(roster.map(\.character) == ["ALICE", "BOB"])
  }

  @Test(
    "Bootstrap infers *.txt filePattern for a non-fountain project so generate cast finds the scripts"
  )
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
    // --dry-run and wrote the characters from the .txt script to CAST.md.
    let roster = try GenerateCastCommandTests.readCast(besides: projectFile)
    #expect(roster.map(\.character) == ["ALICE", "BOB"])
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

  @Test("Bootstrap does NOT ascend to an ancestor PROJECT.md; it scaffolds the project asked for")
  func bootstrapDoesNotAscendToAncestorProject() async throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-bootstrap-ancestor-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    // An UNRELATED project lives one level up (a sibling fixture / monorepo root).
    let ancestorFrontMatter = ProjectFrontMatter(
      type: "project",
      title: "Already Bootstrapped",
      author: "Somebody",
      created: Date(timeIntervalSince1970: 0),
      episodesDir: "episodes",
      filePattern: FilePattern("*.fountain")
    )
    let ancestorProjectFile = base.appendingPathComponent("PROJECT.md")
    try ProjectMarkdownParser().write(
      frontMatter: ancestorFrontMatter, body: "", to: ancestorProjectFile)
    let ancestorOriginal = try String(contentsOf: ancestorProjectFile, encoding: .utf8)

    // The caller explicitly targets a fresh project in a nested subdirectory that
    // has its own script but no PROJECT.md yet.
    let nestedDir = base.appendingPathComponent("nested")
    try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)
    try GenerateCastCommandTests.episodeOne.write(
      to: nestedDir.appendingPathComponent("ep1.fountain"), atomically: true, encoding: .utf8)
    let requestedProjectFile = nestedDir.appendingPathComponent("PROJECT.md")
    #expect(!FileManager.default.fileExists(atPath: requestedProjectFile.path))

    let cmd = try CastCommand.parse(["--project", requestedProjectFile.path, "--dry-run"])
    // Bootstrap stays captive to the requested directory: the ancestor PROJECT.md
    // must NOT suppress scaffolding the project the caller asked for here.
    try await cmd.run()

    // The requested project was scaffolded (and its offline cast discovered
    // into the nested directory's own CAST.md).
    #expect(FileManager.default.fileExists(atPath: requestedProjectFile.path))
    let (frontMatter, _) = try ProjectMarkdownParser().parse(fileURL: requestedProjectFile)
    #expect(frontMatter.title == "Nested")
    let roster = try GenerateCastCommandTests.readCast(besides: requestedProjectFile)
    #expect(roster.map(\.character) == ["ALICE", "BOB"])

    // The unrelated ancestor is left byte-for-byte untouched, and no CAST.md
    // appears beside it.
    let ancestorAfter = try String(contentsOf: ancestorProjectFile, encoding: .utf8)
    #expect(ancestorAfter == ancestorOriginal)
    #expect(
      !FileManager.default.fileExists(
        atPath: GenerateCastCommandTests.castURL(besides: ancestorProjectFile).path))
  }

  @Test("An existing PROJECT.md in the project's own directory is left in place, not overwritten")
  func bootstrapLeavesSameDirectoryProjectInPlace() async throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-bootstrap-sibling-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    // A canonical PROJECT.md already lives in this very directory.
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

    // The caller points `--project` at a DIFFERENT filename in the same directory.
    let requestedProjectFile = base.appendingPathComponent("custom.md")

    let cmd = try CastCommand.parse(["--project", requestedProjectFile.path, "--dry-run"])
    // Bootstrap sees the sibling PROJECT.md in this directory and leaves it in
    // place, so it does NOT scaffold a competing `custom.md`. The subsequent
    // `generate cast` stage then looks for `custom.md` (which still doesn't
    // exist) and fails cleanly.
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
    let originalContents = try String(contentsOf: projectFile, encoding: .utf8)

    let cmd = try CastCommand.parse(["--project", projectFile.path, "--dry-run"])
    try await cmd.run()

    // PROJECT.md is byte-for-byte untouched -- bootstrap skipped it (already
    // present) and the cast stage never writes it.
    let afterContents = try String(contentsOf: projectFile, encoding: .utf8)
    #expect(afterContents == originalContents)

    // The cast-discovery stage still ran for real under --dry-run and wrote
    // ALICE/BOB to CAST.md.
    let roster = try GenerateCastCommandTests.readCast(besides: projectFile)
    #expect(roster.map(\.character) == ["ALICE", "BOB"])
  }
}
