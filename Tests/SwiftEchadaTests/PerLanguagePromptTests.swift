import Foundation
import SwiftProyecto
import Testing

@testable import EchadaCLICore

@Suite("Per-language castability (Piece 2 foundation)")
struct PerLanguagePromptTests {

  // MARK: - Criterion 6: localized voice only / no voice at all

  @Test func memberWithLocalizedVoiceOnlyIsCastableForThatLanguage() {
    // Member has voices["es"] but no voiceDescription — castable for "es"
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: nil,
      voices: ["es": "warm spanish narrator"]
    )
    let result = castableLanguages(for: member, requestedLanguages: ["es"])
    #expect(result == ["es"])
  }

  @Test func memberWithNeitherVoiceNorDescriptionIsSkipped() {
    // Member has no voices and no voiceDescription — castable for nothing
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: nil,
      voices: [:]
    )
    let result = castableLanguages(for: member, requestedLanguages: ["es"])
    #expect(result.isEmpty)
  }

  @Test func memberWithEmptyVoiceDescriptionAndNoLocalizedVoiceIsSkipped() {
    // Empty string voiceDescription counts as absent — still not castable
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: "",
      voices: [:]
    )
    let result = castableLanguages(for: member, requestedLanguages: ["es"])
    #expect(result.isEmpty)
  }

  @Test func memberWithLocalizedVoiceNotCastableForOtherLanguageWithNoBase() {
    // Has voices["es"] but no voiceDescription — NOT castable for "en"
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: nil,
      voices: ["es": "warm spanish narrator"]
    )
    let result = castableLanguages(for: member, requestedLanguages: ["en"])
    #expect(result.isEmpty)
  }

  // MARK: - Criterion 7: base voiceDescription only — falls back for all languages

  @Test func memberWithBaseDescriptionOnlyIsCastableForAllRequestedLanguages() {
    // Member has voiceDescription but no localized voices — castable for both es and en
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: "Deep, warm baritone with measured pacing",
      voices: [:]
    )
    let result = castableLanguages(for: member, requestedLanguages: ["es", "en"])
    #expect(Set(result) == Set(["es", "en"]))
  }

  @Test func memberWithBaseDescriptionIsCastableForAllLanguages() {
    // Base prompt is the fallback — should cover any requested language
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: "Cheerful storyteller",
      voices: [:]
    )
    let result = castableLanguages(for: member, requestedLanguages: ["es", "en", "fr"])
    #expect(Set(result) == Set(["es", "en", "fr"]))
  }

  // MARK: - Mixed: localized + base

  @Test func memberWithBothLocalizedAndBaseIsCastableForAll() {
    // Has voices["es"] AND voiceDescription — castable for all requested languages
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: "Warm storyteller",
      voices: ["es": "narrador cálido"]
    )
    let result = castableLanguages(for: member, requestedLanguages: ["es", "en"])
    #expect(Set(result) == Set(["es", "en"]))
  }

  // MARK: - Empty requested languages

  @Test func emptyRequestedLanguagesReturnsEmpty() {
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: "Some description",
      voices: ["es": "voice"]
    )
    let result = castableLanguages(for: member, requestedLanguages: [])
    #expect(result.isEmpty)
  }
}
