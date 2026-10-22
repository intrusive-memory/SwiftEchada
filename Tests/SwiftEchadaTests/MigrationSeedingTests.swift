import ArgumentParser
import CryptoKit
import Foundation
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// Seeding fidelity for the automatic migration → CAST.md (EC-7), exercised against
/// the byte-for-byte copy of the real 309-line `confessions/PROJECT.md`
/// fixture: when CAST.md is absent and PROJECT.md carries a legacy `cast:`
/// block, that roster seeds the new CAST.md verbatim -- `voicePrompt`, the
/// undeclared `bio:` key, and the scalar `voices:` pointers all survive, and
/// no field the legacy members never had (`gender`, `actor`, `language`,
/// `portrait`) is invented. PROJECT.md is migrated once, on the first run, and
/// never written again.
@Suite("Migration — CAST.md seeding from the confessions fixture (offline)")
struct MigrationSeedingTests {

  /// A script whose CHARACTER cues cover the three legacy cast members plus a
  /// newly-appearing one (PRODUCER), so a run both matches every seeded member
  /// and discovers a genuinely new character to merge on top.
  static let confessionsScript = """
    INT. THE WIRE - NIGHT

    A cursor blinks in the dark.

    NARRATOR
    In the beginning, there was the terminal.

    THE PRACTITIONER
    Did I break the build again?

    ESPECTRO FAMILIAR
    The build was never whole, apprentice.

    PRODUCER
    We need this by Thursday.
    """

  /// Copies the confessions fixture into a fresh temp project directory as
  /// PROJECT.md, with an `episodes/` folder containing `confessionsScript`.
  /// Returns the PROJECT.md URL; caller removes the directory via `defer`.
  private func makeConfessionsProject() throws -> URL {
    let fixture = try #require(
      Bundle.module.url(
        forResource: "confessions-PROJECT",
        withExtension: "md",
        subdirectory: "Fixtures"))

    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-seeding-\(UUID().uuidString)")
    let episodesDir = dir.appendingPathComponent("episodes")
    try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
    try Self.confessionsScript.write(
      to: episodesDir.appendingPathComponent("ep1.fountain"), atomically: true, encoding: .utf8)

    let projectURL = dir.appendingPathComponent("PROJECT.md")
    try FileManager.default.copyItem(at: fixture, to: projectURL)
    return projectURL
  }

  private func sha256(of url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private func castURL(_ projectURL: URL) -> URL {
    projectURL.deletingLastPathComponent().appendingPathComponent("CAST.md")
  }

  // MARK: - Seeding fidelity (EC-7)

  @Test("Seeding carries bio, voicePrompt, and voices.voxalta from the legacy cast into CAST.md")
  func seedingCarriesEveryLegacyField() async throws {
    let projectURL = try makeConfessionsProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    _ = try ProjectMigration.migrateIfNeeded(projectURL: projectURL, castName: "CAST.md")

    let document = try CastMarkdownParser().parse(fileURL: castURL(projectURL))
    let byName = Dictionary(
      uniqueKeysWithValues: document.cast.map { ($0.character, $0) })

    // Seeded legacy members keep document order; nothing is discovered from
    // the script (EC-P11).
    #expect(
      document.cast.map(\.character) == ["NARRATOR", "ESPECTRO FAMILIAR", "THE PRACTITIONER"])

    // The full voicePrompt on ESPECTRO FAMILIAR survives verbatim.
    let espectro = try #require(byName["ESPECTRO FAMILIAR"])
    #expect(
      espectro.voicePrompt
        == "Methodical, unhurried male voice with ancient wisdom. Calm and deliberate cadence, "
        + "as though this entity has existed for thousands of years and will exist for thousands "
        + "more. Never rushed. Precise articulation. Quiet authority without force.")

    // The undeclared `bio:` key rides through extraKeys.
    let practitioner = try #require(byName["THE PRACTITIONER"])
    let bio = try practitioner[extra: "bio"]?.decode(String.self)
    #expect(bio?.hasPrefix("Neurodivergent (ADHD), gay Gen X developer") == true)

    // The scalar `voxalta:` pointers survive (normalized to the array form).
    #expect(byName["NARRATOR"]?.voices == ["voxalta": ["voices/NARRATOR.vox"]])
    #expect(espectro.voices == ["voxalta": ["voices/ESPECTRO_FAMILIAR.vox"]])
    #expect(practitioner.voices == ["voxalta": ["voices/THE_PRACTITIONER.vox"]])
  }

  @Test("Seeding invents no fields: absent gender/actor/language/portrait keys stay absent")
  func seedingInventsNoFields() async throws {
    let projectURL = try makeConfessionsProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    _ = try ProjectMigration.migrateIfNeeded(projectURL: projectURL, castName: "CAST.md")

    // The confessions cast has no actor, gender, language, or portrait -- the
    // emitted CAST.md must not contain those keys at all: never `null`, never
    // an empty string.
    let emitted = try String(contentsOf: castURL(projectURL), encoding: .utf8)
    #expect(!emitted.contains("gender:"))
    #expect(!emitted.contains("actor:"))
    #expect(!emitted.contains("language:"))
    #expect(!emitted.contains("portrait:"))

    // And the typed view agrees.
    let document = try CastMarkdownParser().parse(fileURL: castURL(projectURL))
    for member in document.cast {
      #expect(member.gender == nil)
      #expect(member.actor == nil)
      #expect(member.language == nil)
      #expect(member[extra: "portrait"] == nil)
    }
  }

  // MARK: - PROJECT.md is migrated once

  @Test("The first run migrates PROJECT.md; later runs leave it untouched")
  func projectMdMigratedOnce() async throws {
    let projectURL = try makeConfessionsProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let shaBefore = try sha256(of: projectURL)

    _ = try ProjectMigration.migrateIfNeeded(projectURL: projectURL, castName: "CAST.md")

    #expect(try sha256(of: projectURL.appendingPathExtension("bak")) == shaBefore)
    let shaMigrated = try sha256(of: projectURL)
    #expect(shaMigrated != shaBefore)

    // A second run (against the now-existing CAST.md) leaves it untouched.
    _ = try ProjectMigration.migrateIfNeeded(projectURL: projectURL, castName: "CAST.md")
    #expect(try sha256(of: projectURL) == shaMigrated)
  }

  // MARK: - Idempotency

  @Test("Two consecutive runs produce byte-identical CAST.md")
  func consecutiveRunsAreByteIdentical() async throws {
    let projectURL = try makeConfessionsProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    _ = try ProjectMigration.migrateIfNeeded(projectURL: projectURL, castName: "CAST.md")
    let firstBytes = try Data(contentsOf: castURL(projectURL))

    _ = try ProjectMigration.migrateIfNeeded(projectURL: projectURL, castName: "CAST.md")
    let secondBytes = try Data(contentsOf: castURL(projectURL))

    #expect(firstBytes == secondBytes)
  }

  // MARK: - --dry-run writes nothing

  @Test("A dry-run migration creates no CAST.md and leaves PROJECT.md untouched")
  func dryRunWritesNoCastMd() async throws {
    let projectURL = try makeConfessionsProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let shaBefore = try sha256(of: projectURL)

    _ = try ProjectMigration.migrateIfNeeded(
      projectURL: projectURL, castName: "CAST.md", dryRun: true)

    #expect(!FileManager.default.fileExists(atPath: castURL(projectURL).path))
    #expect(try sha256(of: projectURL) == shaBefore)
  }
}
