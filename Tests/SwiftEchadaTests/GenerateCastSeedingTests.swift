import ArgumentParser
import CryptoKit
import Foundation
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// Seeding fidelity for `generate cast` → CAST.md (EC-7), exercised against
/// the byte-for-byte copy of the real 309-line `confessions/PROJECT.md`
/// fixture: when CAST.md is absent and PROJECT.md carries a legacy `cast:`
/// block, that roster seeds the new CAST.md verbatim -- `voicePrompt`, the
/// undeclared `bio:` key, and the scalar `voices:` pointers all survive, and
/// no field the legacy members never had (`gender`, `actor`, `language`,
/// `portrait`) is invented. PROJECT.md itself is never written: its SHA-256
/// must be identical before and after every run.
@Suite("generate cast — CAST.md seeding from the confessions fixture (offline)")
struct GenerateCastSeedingTests {

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

    let cmd = try GenerateCastCommand.parse(["--project", projectURL.path])
    try await cmd.run()

    let document = try CastMarkdownParser().parse(fileURL: castURL(projectURL))
    let byName = Dictionary(
      uniqueKeysWithValues: document.cast.map { ($0.character, $0) })

    // Seeded legacy members lead the roster in document order; the
    // newly-discovered PRODUCER is appended after them.
    #expect(
      document.cast.map(\.character) == [
        "NARRATOR", "ESPECTRO FAMILIAR", "THE PRACTITIONER", "PRODUCER",
      ])

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

    // The newly-discovered member carries only its name.
    let producer = try #require(byName["PRODUCER"])
    #expect(producer.voicePrompt == nil)
    #expect(producer.voices.isEmpty)
    #expect(producer.extraKeys.isEmpty)
  }

  @Test("Seeding invents no fields: absent gender/actor/language/portrait keys stay absent")
  func seedingInventsNoFields() async throws {
    let projectURL = try makeConfessionsProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    let cmd = try GenerateCastCommand.parse(["--project", projectURL.path])
    try await cmd.run()

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

  // MARK: - PROJECT.md is never written

  @Test("PROJECT.md's SHA-256 is identical before and after generate cast")
  func projectMdShaUnchanged() async throws {
    let projectURL = try makeConfessionsProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let shaBefore = try sha256(of: projectURL)

    let cmd = try GenerateCastCommand.parse(["--project", projectURL.path])
    try await cmd.run()

    #expect(try sha256(of: projectURL) == shaBefore)

    // A second run (against the now-existing CAST.md) leaves it untouched too.
    let again = try GenerateCastCommand.parse(["--project", projectURL.path])
    try await again.run()
    #expect(try sha256(of: projectURL) == shaBefore)
  }

  // MARK: - Idempotency

  @Test("Two consecutive runs produce byte-identical CAST.md")
  func consecutiveRunsAreByteIdentical() async throws {
    let projectURL = try makeConfessionsProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }

    let first = try GenerateCastCommand.parse(["--project", projectURL.path])
    try await first.run()
    let firstBytes = try Data(contentsOf: castURL(projectURL))

    let second = try GenerateCastCommand.parse(["--project", projectURL.path])
    try await second.run()
    let secondBytes = try Data(contentsOf: castURL(projectURL))

    #expect(firstBytes == secondBytes)
  }

  // MARK: - --force re-sync

  @Test("--force re-syncs CAST.md to the current source, keeping fields for survivors")
  func forceResyncsSeededRoster() async throws {
    let projectURL = try makeConfessionsProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let shaBefore = try sha256(of: projectURL)

    // First run: seed + merge (NARRATOR, ESPECTRO FAMILIAR, THE PRACTITIONER,
    // PRODUCER).
    let seed = try GenerateCastCommand.parse(["--project", projectURL.path])
    try await seed.run()

    // The source material shrinks to a single NARRATOR scene.
    let episodesDir = projectURL.deletingLastPathComponent().appendingPathComponent("episodes")
    let narratorOnly = """
      INT. THE WIRE - NIGHT

      The wire hums alone.

      NARRATOR
      Everyone else has gone home.
      """
    try narratorOnly.write(
      to: episodesDir.appendingPathComponent("ep1.fountain"), atomically: true, encoding: .utf8)

    let force = try GenerateCastCommand.parse(["--project", projectURL.path, "--force"])
    try await force.run()

    let document = try CastMarkdownParser().parse(fileURL: castURL(projectURL))
    #expect(document.cast.map(\.character) == ["NARRATOR"])

    // The survivor keeps every seeded field.
    let narrator = try #require(document.cast.first)
    #expect(narrator.voicePrompt?.hasPrefix("Deep authoritative British baritone") == true)
    #expect(narrator.voices == ["voxalta": ["voices/NARRATOR.vox"]])

    // PROJECT.md is still untouched, --force or not.
    #expect(try sha256(of: projectURL) == shaBefore)
  }

  // MARK: - --dry-run writes nothing

  @Test("--dry-run creates no CAST.md and leaves PROJECT.md untouched")
  func dryRunWritesNoCastMd() async throws {
    let projectURL = try makeConfessionsProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let shaBefore = try sha256(of: projectURL)

    let cmd = try GenerateCastCommand.parse(["--project", projectURL.path, "--dry-run"])
    try await cmd.run()

    #expect(!FileManager.default.fileExists(atPath: castURL(projectURL).path))
    #expect(try sha256(of: projectURL) == shaBefore)
  }
}
