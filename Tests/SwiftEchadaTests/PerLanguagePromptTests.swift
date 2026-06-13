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

  // MARK: - Criterion 8: Per-language prompt selection

  @Test func promptSelectionUsesLocalizedVoiceWhenAvailable() {
    // Member has voices["es"] AND a base voiceDescription.
    // Prompt for "es" should be the localized value; for "fr" (absent) the base.
    let localizedEs = "narrador cálido con tono profundo"
    let base = "Deep, warm baritone with measured pacing"
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: base,
      voices: ["es": localizedEs]
    )

    // "es" → localized value
    let promptForEs = member.voice(for: "es") ?? member.voiceDescription
    #expect(promptForEs == localizedEs)

    // "fr" → falls back to base
    let promptForFr = member.voice(for: "fr") ?? member.voiceDescription
    #expect(promptForFr == base)
  }

  @Test func promptSelectionFallsBackToBaseWhenLocalizedAbsent() {
    // Member has only a base voiceDescription — all languages fall back to it.
    let base = "Cheerful storyteller with animated delivery"
    let member = CastMember(
      character: "TELLER",
      voiceDescription: base,
      voices: [:]
    )

    let promptForEn = member.voice(for: "en") ?? member.voiceDescription
    #expect(promptForEn == base)

    let promptForEs = member.voice(for: "es") ?? member.voiceDescription
    #expect(promptForEs == base)
  }

  @Test func promptSelectionEnglishDefaultPathUnchangedWithNoLocalizedPromptNoAccent() {
    // English default path: no localized "en" entry, no accent.
    // voice(for:"en") is nil → falls back to voiceDescription → composeVoicePrompt(base, nil) == base.
    // The resulting voice string is byte-for-byte identical to voiceDescription.
    let base = "Calm, authoritative narrator"
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: base,
      voices: [:]
    )

    let selected = member.voice(for: "en") ?? member.voiceDescription
    let composed = composeVoicePrompt(base: selected!, accent: nil)
    #expect(composed == base)
  }

  // MARK: - Criterion 9: --accent composes onto the SELECTED (possibly localized) prompt

  @Test func accentComposesOntoLocalizedPromptNotBase() {
    // When voices["es"] is set, accent must be composed onto the localized "es" prompt,
    // not the base voiceDescription.
    let localizedEs = "narrador cálido con tono profundo"
    let base = "Deep, warm baritone"
    let accent = "slow southern drawl"
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: base,
      voices: ["es": localizedEs]
    )

    let selectedEs = member.voice(for: "es") ?? member.voiceDescription
    let composedEs = composeVoicePrompt(base: selectedEs!, accent: accent)

    // Must contain the LOCALIZED prompt, not the base
    #expect(composedEs.contains(localizedEs))
    #expect(composedEs.contains(accent))
    // Must NOT be built from base when localized is available
    #expect(!composedEs.hasPrefix(base))
  }

  @Test func accentComposesOntoBaseWhenNoLocalizedPromptExists() {
    // When no localized entry exists for the language, accent is composed onto the base.
    let base = "Warm, measured narrator"
    let accent = "clipped British RP"
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: base,
      voices: [:]
    )

    let selectedFr = member.voice(for: "fr") ?? member.voiceDescription
    let composedFr = composeVoicePrompt(base: selectedFr!, accent: accent)

    #expect(composedFr.contains(base))
    #expect(composedFr.contains(accent))
  }

  @Test func noAccentOnLocalizedPromptReturnsLocalizedVerbatim() {
    // No accent → composeVoicePrompt returns base verbatim → selected localized prompt unchanged.
    let localizedEs = "narrador cálido"
    let base = "Deep baritone"
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: base,
      voices: ["es": localizedEs]
    )

    let selected = member.voice(for: "es") ?? member.voiceDescription
    let composed = composeVoicePrompt(base: selected!, accent: nil)
    #expect(composed == localizedEs)
  }
}
