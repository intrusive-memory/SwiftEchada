import Foundation
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// Automatic migration of a pre-v5 PROJECT.md: the legacy `cast:` block moves
/// into CAST.md, the original is backed up, and only the `cast:` lines change.
@Suite("Automatic project migration (offline)")
struct ProjectMigrationTests {

  private static let legacyProjectMd = """
    ---
    type: podcast
    title: Migration Fixture
    author: Test
    created: 2026-01-01T00:00:00Z
    introFile: audio/intro.m4a
    cast:
      - character: NARRATOR
        voicePrompt: Deep authoritative British baritone.
        voices:
          voxalta: voices/NARRATOR.vox
      - character: THE PRACTITIONER
        voicePrompt: Anxious, rapid-fire tenor.
        bio: A developer.
    tts:
      model: 1.7b
    ---

    # Migration Fixture
    """

  private static let expectedMigratedProjectMd = """
    ---
    schemaVersion: 5
    type: podcast
    title: Migration Fixture
    author: Test
    created: 2026-01-01T00:00:00Z
    introFile: audio/intro.m4a
    tts:
      model: 1.7b
    ---

    # Migration Fixture
    """

  /// Writes `projectMd` into a fresh temp directory, plus CAST.md when `cast`
  /// is given. Returns the PROJECT.md URL; the caller removes the directory.
  private func makeProject(
    projectMd: String = legacyProjectMd, cast: [SwiftReparto.CastMember]? = nil
  ) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("migration-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let projectURL = dir.appendingPathComponent("PROJECT.md")
    try projectMd.write(to: projectURL, atomically: true, encoding: .utf8)
    if let cast {
      try CastMarkdownParser().write(
        document: CastDocument(cast: cast), to: dir.appendingPathComponent("CAST.md"))
    }
    return projectURL
  }

  private func castURL(for projectURL: URL) -> URL {
    projectURL.deletingLastPathComponent().appendingPathComponent("CAST.md")
  }

  private func read(_ url: URL) throws -> String {
    try String(contentsOf: url, encoding: .utf8)
  }

  @Test("A legacy project seeds CAST.md, keeps a backup, and loses only its cast: lines")
  func migratesLegacyProject() throws {
    let projectURL = try makeProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    let outcome = try ProjectMigration.migrateIfNeeded(
      projectURL: projectURL, castName: "CAST.md")

    #expect(outcome.migrated)
    #expect(outcome.membersAdded == 2)
    #expect(outcome.conflicts.isEmpty)
    #expect(try read(projectURL) == Self.expectedMigratedProjectMd)

    let backup = try #require(outcome.backupURL)
    #expect(backup.lastPathComponent == "PROJECT.md.bak")
    #expect(try read(backup) == Self.legacyProjectMd)

    let cast = try CastMarkdownParser().parse(fileURL: castURL(for: projectURL)).cast
    #expect(cast.map(\.character) == ["NARRATOR", "THE PRACTITIONER"])
    #expect(cast[0].voices == ["voxalta": ["voices/NARRATOR.vox"]])
    #expect(try cast[1][extra: "bio"]?.decode(String.self) == "A developer.")
  }

  @Test("An existing CAST.md keeps its values and gains only the members it lacked")
  func existingCastIsAuthoritative() throws {
    let projectURL = try makeProject(cast: [
      SwiftReparto.CastMember(character: "Narrator", voicePrompt: "Tuned by hand.")
    ])
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    let outcome = try ProjectMigration.migrateIfNeeded(
      projectURL: projectURL, castName: "CAST.md")

    #expect(outcome.membersAdded == 1)
    #expect(outcome.conflicts.contains { $0.contains("voicePrompt") })

    let cast = try CastMarkdownParser().parse(fileURL: castURL(for: projectURL)).cast
    #expect(cast.map(\.character) == ["Narrator", "THE PRACTITIONER"])
    #expect(cast[0].voicePrompt == "Tuned by hand.")
    // Empty fields are filled from the legacy block.
    #expect(cast[0].voices == ["voxalta": ["voices/NARRATOR.vox"]])
    #expect(try read(projectURL) == Self.expectedMigratedProjectMd)
  }

  @Test("A dry run reports the migration and writes nothing")
  func dryRunWritesNothing() throws {
    let projectURL = try makeProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    let outcome = try ProjectMigration.migrateIfNeeded(
      projectURL: projectURL, castName: "CAST.md", dryRun: true)

    #expect(outcome.migrated)
    #expect(outcome.backupURL == nil)
    #expect(try read(projectURL) == Self.legacyProjectMd)
    #expect(!FileManager.default.fileExists(atPath: castURL(for: projectURL).path))
  }

  @Test("A project with no cast: block is never written")
  func currentProjectIsUntouched() throws {
    let projectURL = try makeProject(projectMd: Self.expectedMigratedProjectMd)
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    let outcome = try ProjectMigration.migrateIfNeeded(
      projectURL: projectURL, castName: "CAST.md")

    #expect(outcome == ProjectMigration.Outcome())
    #expect(try read(projectURL) == Self.expectedMigratedProjectMd)
    #expect(!FileManager.default.fileExists(atPath: castURL(for: projectURL).path))
  }

  @Test("Migrating again is a no-op, and an earlier backup is never overwritten")
  func repeatRunsAreSafe() throws {
    let projectURL = try makeProject()
    let dir = projectURL.deletingLastPathComponent()
    defer { try? FileManager.default.removeItem(at: dir) }
    let earlier = dir.appendingPathComponent("PROJECT.md.bak")
    try "earlier backup".write(to: earlier, atomically: true, encoding: .utf8)

    let first = try ProjectMigration.migrateIfNeeded(projectURL: projectURL, castName: "CAST.md")
    #expect(first.backupURL?.lastPathComponent == "PROJECT.md.bak.1")
    #expect(try read(earlier) == "earlier backup")

    let second = try ProjectMigration.migrateIfNeeded(projectURL: projectURL, castName: "CAST.md")
    #expect(!second.migrated)
    #expect(try read(projectURL) == Self.expectedMigratedProjectMd)
  }

  @Test("echada cast --dry-run migrates a legacy project and discovers nobody")
  func castPipelineMigrates() async throws {
    let projectURL = try makeProject()
    let dir = projectURL.deletingLastPathComponent()
    defer { try? FileManager.default.removeItem(at: dir) }
    let episodes = dir.appendingPathComponent("episodes")
    try FileManager.default.createDirectory(at: episodes, withIntermediateDirectories: true)
    try "INT. ROOM - DAY\n\nHOST\nWelcome back.\n".write(
      to: episodes.appendingPathComponent("ep1.fountain"), atomically: true, encoding: .utf8)

    try await CastCommand.parse(["--project", projectURL.path, "--dry-run"]).run()

    #expect(try read(projectURL) == Self.expectedMigratedProjectMd)
    let cast = try CastMarkdownParser().parse(fileURL: castURL(for: projectURL)).cast
    #expect(cast.map(\.character) == ["NARRATOR", "THE PRACTITIONER"])
  }

  @Test("generate vox --dry-run describes the migration without performing it")
  func voxDryRunDoesNotMigrate() async throws {
    let projectURL = try makeProject(cast: [SwiftReparto.CastMember(character: "NARRATOR")])
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    try await GenerateVoxCommand.parse(["--project", projectURL.path, "--dry-run"]).run()

    #expect(try read(projectURL) == Self.legacyProjectMd)
  }
}
