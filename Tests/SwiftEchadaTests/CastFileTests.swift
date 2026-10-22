import ArgumentParser
import Foundation
import SwiftProyecto
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// Offline coverage for locating CAST.md (`CastFile`, EC-13 / OQ-1) and the
/// `cast` orchestrator's PROJECT.md bootstrap step (`CastCommand`, R-TEST-2).
///
/// Everything here runs against fixture Fountain text and temp-directory
/// PROJECT.md files -- no LLM/ML model is ever invoked. echada 3.0.0 no longer
/// discovers cast members (EC-P11); the roster comes from
/// `personaje cast-discover`.
@Suite("CastFile + PROJECT.md bootstrap — offline")
struct CastFileTests {

  // MARK: - Fixture Fountain text

  /// Two characters, standard Fountain cue formatting.
  static let episodeOne = """
    INT. HOUSE - DAY

    Some action description sets the scene.

    ALICE
    Hello there, friend.

    BOB
    Good morning to you too.
    """

  static func castURL(besides projectURL: URL) -> URL {
    projectURL.deletingLastPathComponent().appendingPathComponent("CAST.md")
  }

  /// Reads the roster out of the CAST.md beside the given PROJECT.md.
  static func readCast(besides projectURL: URL) throws -> [SwiftReparto.CastMember] {
    try CastMarkdownParser().parse(fileURL: castURL(besides: projectURL)).cast
  }

  // MARK: - --cast filename override (EC-13, OQ-1)

  @Test("--cast resolves to that filename inside the project directory")
  func castOptionOverridesFilename() throws {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-file-\(UUID().uuidString)")
    let url = try CastFile.resolve(named: "ROSTER.md", in: dir)
    #expect(url == dir.appendingPathComponent("ROSTER.md", isDirectory: false))
  }

  @Test(
    "--cast rejects values with path separators or that escape the project directory",
    arguments: ["sub/CAST.md", "../CAST.md", "..", ".", "", "/tmp/CAST.md", "a\\b.md"])
  func castOptionRejectsPathTraversal(value: String) {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-file-\(UUID().uuidString)")
    #expect(throws: ValidationError.self) { try CastFile.resolve(named: value, in: dir) }
  }

  @Test("matchKey ignores case and collapses whitespace")
  func matchKeyIsCaseAndWhitespaceInsensitive() {
    #expect(CastFile.matchKey("  The   Practitioner ") == CastFile.matchKey("the practitioner"))
    #expect(CastFile.matchKey("ALICE") != CastFile.matchKey("ALICIA"))
  }

  @Test("--cast resolves inside a /private project directory before CAST.md exists")
  func castFileResolvesUnderPrivatePrefix() throws {
    // `standardizedFileURL` strips `/private` only from paths that exist, so a
    // not-yet-created CAST.md under `/private/tmp` used to look like it escaped
    // its directory and every stage failed.
    let dir = URL(fileURLWithPath: "/private/tmp/echada-private-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let castURL = try CastFile.resolve(named: "CAST.md", in: dir)
    #expect(castURL.lastPathComponent == "CAST.md")
    #expect(
      castURL.deletingLastPathComponent().standardizedFileURL.path == dir.standardizedFileURL.path)
  }
}

// MARK: - PROJECT.md bootstrap (R-TEST-2), via the `cast` orchestrator

/// The bootstrap logic lives in `CastCommand.ensureProjectMarkdown`, which is
/// private, so it is exercised the way a real invocation would reach it: via
/// `CastCommand`'s public `run()`. `--dry-run` is used throughout so the
/// pipeline never reaches the model-backed prompt/vox stages -- the bootstrap
/// and migration steps are offline and run for real under `--dry-run` (per
/// `CastCommand`'s documented contract), then execution stops. Bootstrap
/// creates an empty CAST.md beside the (possibly just-bootstrapped)
/// PROJECT.md; echada never fills it from the scripts (EC-P11).
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

    try CastFileTests.episodeOne.write(
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

    // The roster lives in CAST.md, never in PROJECT.md, and echada does not
    // discover members from the script.
    #expect(try LegacyProjectCastReader.readCast(fileURL: projectFile).isEmpty)
    let roster = try CastFileTests.readCast(besides: projectFile)
    #expect(roster.isEmpty)
  }

  @Test(
    "Bootstrap infers *.txt filePattern for a non-fountain project so the scripts are found"
  )
  func bootstrapInfersFilePatternForNonFountainProject() async throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-bootstrap-txt-\(UUID().uuidString)")
    let projectDir = base.appendingPathComponent("txt-podcast")
    let episodesDir = projectDir.appendingPathComponent("episodes")
    try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    // Scripts are .txt, not .fountain -- the hard-coded default would filter them out.
    try CastFileTests.episodeOne.write(
      to: episodesDir.appendingPathComponent("ep1.txt"), atomically: true, encoding: .utf8)

    let projectFile = projectDir.appendingPathComponent("PROJECT.md")
    let cmd = try CastCommand.parse(["--project", projectFile.path, "--dry-run"])
    try await cmd.run()

    let (frontMatter, _) = try ProjectMarkdownParser().parse(fileURL: projectFile)
    // The inferred pattern must include *.txt so `generate prompt` can read
    // dialogue from the scripts.
    #expect(frontMatter.resolvedFilePatterns.contains("*.txt"))
  }

  @Test("Bootstrap falls back to '.' for episodesDir when no episodes/ subdirectory exists")
  func bootstrapInfersDotEpisodesDirWhenNoEpisodesSubfolder() async throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-bootstrap-flat-\(UUID().uuidString)")
    let projectDir = base.appendingPathComponent("flat-project")
    try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }

    // Script lives directly in the project root -- no "episodes" subfolder.
    try CastFileTests.episodeOne.write(
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
    try CastFileTests.episodeOne.write(
      to: nestedDir.appendingPathComponent("ep1.fountain"), atomically: true, encoding: .utf8)
    let requestedProjectFile = nestedDir.appendingPathComponent("PROJECT.md")
    #expect(!FileManager.default.fileExists(atPath: requestedProjectFile.path))

    let cmd = try CastCommand.parse(["--project", requestedProjectFile.path, "--dry-run"])
    // Bootstrap stays captive to the requested directory: the ancestor PROJECT.md
    // must NOT suppress scaffolding the project the caller asked for here.
    try await cmd.run()

    // The requested project was scaffolded, with its own (empty) CAST.md.
    #expect(FileManager.default.fileExists(atPath: requestedProjectFile.path))
    let (frontMatter, _) = try ProjectMarkdownParser().parse(fileURL: requestedProjectFile)
    #expect(frontMatter.title == "Nested")
    #expect(
      FileManager.default.fileExists(
        atPath: CastFileTests.castURL(besides: requestedProjectFile).path))

    // The unrelated ancestor is left byte-for-byte untouched, and no CAST.md
    // appears beside it.
    let ancestorAfter = try String(contentsOf: ancestorProjectFile, encoding: .utf8)
    #expect(ancestorAfter == ancestorOriginal)
    #expect(
      !FileManager.default.fileExists(
        atPath: CastFileTests.castURL(besides: ancestorProjectFile).path))
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
    // place, so it does NOT scaffold a competing `custom.md`, and the pipeline
    // fails cleanly naming the PROJECT.md it found.
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

    try CastFileTests.episodeOne.write(
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
    // present).
    let afterContents = try String(contentsOf: projectFile, encoding: .utf8)
    #expect(afterContents == originalContents)

    // An empty CAST.md was bootstrapped beside it.
    let roster = try CastFileTests.readCast(besides: projectFile)
    #expect(roster.isEmpty)
  }

  @Test("An empty roster stops the pipeline with the cast-discover advice")
  func emptyRosterStopsThePipeline() async throws {
    let base = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-empty-roster-\(UUID().uuidString)")
    let episodesDir = base.appendingPathComponent("episodes")
    try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: base) }
    try CastFileTests.episodeOne.write(
      to: episodesDir.appendingPathComponent("ep1.fountain"), atomically: true, encoding: .utf8)

    let projectFile = base.appendingPathComponent("PROJECT.md")
    let cmd = try CastCommand.parse(["--project", projectFile.path])
    do {
      try await cmd.run()
      Issue.record("expected an empty-roster error")
    } catch let error as ValidationError {
      #expect(error.message.contains("personaje cast-discover"))
    }
  }
}
