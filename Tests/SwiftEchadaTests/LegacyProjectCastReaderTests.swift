import Foundation
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// Tests for the temporary legacy `cast:` read path (EC-6).
///
/// The fixture is a byte-for-byte copy of a real 309-line
/// `confessions/PROJECT.md`: `type: project`, three cast members, scalar
/// `voices:` pointers, one `bio:`, a `tts:` block, and a large
/// `episodes_index` appSection — the exact shape the legacy reader must
/// survive without consuming anything but `cast:`.
@Suite("LegacyProjectCastReader Tests")
struct LegacyProjectCastReaderTests {

  private func fixtureURL() throws -> URL {
    try #require(
      Bundle.module.url(
        forResource: "confessions-PROJECT",
        withExtension: "md",
        subdirectory: "Fixtures"))
  }

  // MARK: - Fixture round-trip

  @Test func fixtureYieldsAllThreeCharacters() throws {
    let cast = try LegacyProjectCastReader.readCast(fileURL: fixtureURL())
    #expect(cast.map(\.character) == ["NARRATOR", "ESPECTRO FAMILIAR", "THE PRACTITIONER"])
  }

  @Test func fixtureBioSurvivesIntoExtraKeys() throws {
    let cast = try LegacyProjectCastReader.readCast(fileURL: fixtureURL())
    let practitioner = try #require(cast.first { $0.character == "THE PRACTITIONER" })
    let bio = try practitioner[extra: "bio"]?.decode(String.self)
    #expect(bio?.hasPrefix("Neurodivergent (ADHD), gay Gen X developer") == true)

    // The bio belongs to THE PRACTITIONER alone.
    for member in cast where member.character != "THE PRACTITIONER" {
      #expect(member[extra: "bio"] == nil)
    }
  }

  @Test func fixtureScalarVoicesSurviveAsSinglePointers() throws {
    let cast = try LegacyProjectCastReader.readCast(fileURL: fixtureURL())

    // Scalar `voxalta: voices/X.vox` decodes to a one-element pointer list
    // (RQ-3), and the already-relative path comes through untouched (D-7).
    #expect(cast[0].voices == ["voxalta": ["voices/NARRATOR.vox"]])
    #expect(cast[1].voice(for: "voxalta") == "voices/ESPECTRO_FAMILIAR.vox")
    #expect(cast[2].voice(for: "voxalta") == "voices/THE_PRACTITIONER.vox")
  }

  @Test func fixtureVoicePromptsSurvive() throws {
    let cast = try LegacyProjectCastReader.readCast(fileURL: fixtureURL())
    #expect(cast[0].voicePrompt?.hasPrefix("Deep authoritative British baritone") == true)
    for member in cast {
      #expect(member.voicePrompt?.isEmpty == false)
    }
  }

  @Test func projectLevelKeysAreNotConsumedIntoCast() throws {
    // `episodes_index` and `tts` are project-level keys; the read path must
    // ignore them, not fold them into any member's extraKeys.
    let cast = try LegacyProjectCastReader.readCast(fileURL: fixtureURL())
    for member in cast {
      #expect(member[extra: "episodes_index"] == nil)
      #expect(member[extra: "tts"] == nil)
      #expect(member[extra: "introFile"] == nil)
      #expect(member[extra: "outroFile"] == nil)
    }
  }

  // MARK: - Absent cast

  @Test func castlessProjectYieldsEmptyArrayWithoutThrowing() throws {
    let content = """
      ---
      type: project
      title: No Cast Here
      episodesDir: episodes
      tts:
        model: 1.7b
      ---

      # A project that has already migrated its roster to CAST.md
      """
    let cast = try LegacyProjectCastReader.readCast(content: content)
    #expect(cast.isEmpty)
  }

  // MARK: - RQ-3 leniencies inherited from SwiftReparto

  @Test func voiceDescriptionAliasAndArrayVoicesDecode() throws {
    let content = """
      ---
      type: project
      cast:
        - character: ALIAS
          voiceDescription: "Legacy alias for voicePrompt."
          voices:
            voxalta:
              - voices/A.vox
              - voices/B.vox
      ---
      """
    let cast = try LegacyProjectCastReader.readCast(content: content)
    let member = try #require(cast.first)
    #expect(member.voicePrompt == "Legacy alias for voicePrompt.")
    #expect(member.voices["voxalta"] == ["voices/A.vox", "voices/B.vox"])
  }
}
