import Foundation
import SwiftProyecto
import Testing

@testable import EchadaCLICore

/// Deterministic, model-free passthrough coverage for non-English languages
/// (Spanish, Portuguese, Italian, German) across the pure hops of the
/// voice-generation pipeline:
///
///   `--language` flag → `resolvedLanguages()` → `castableLanguages(_:)`
///     → `localizedVoicePrompt(for:language:)` → `voxLanguageTag(for:)` (storage)
///
/// The audition-sentence source (`FoundationModelSentence.auditionSentence`) and
/// the TTS forward pass (`Qwen3TTSModel.generate(language:)`) are exercised
/// separately — the former by ``FoundationModelSentenceTests`` against on-device
/// Apple Intelligence, the latter by the integration test. Everything below is
/// pure and runs anywhere.
@Suite("Non-English language passthrough (es, pt, it, de)")
struct NonEnglishPassthroughTests {

  /// The four non-English languages under test.
  static let languages = ["es", "pt", "it", "de"]

  /// Regional subtags that must resolve to their base language.
  static let regionalToBase: [(regional: String, base: String)] = [
    ("es-MX", "es"), ("pt-BR", "pt"), ("it-IT", "it"), ("de-AT", "de"),
  ]

  // MARK: - Storage-tag passthrough (voxLanguageTag)

  @Test(
    "voxLanguageTag preserves a non-English tag verbatim (never collapses to the en default path)",
    arguments: languages)
  func nonEnglishKeepsStorageTag(_ language: String) {
    // Non-English never maps to the language-less default path used by "en".
    #expect(voxLanguageTag(for: language) == language)
    #expect(voxLanguageTag(for: language) != nil)
    // Only "en"/"EN" collapse to nil — an uppercased non-English code stays tagged.
    #expect(voxLanguageTag(for: language.uppercased()) != nil)
  }

  @Test("Regional subtags keep a non-nil storage tag", arguments: regionalToBase.map(\.regional))
  func regionalSubtagKeepsStorageTag(_ regional: String) {
    #expect(voxLanguageTag(for: regional) == regional)
  }

  // MARK: - CLI parsing passthrough (CastCommand.resolvedLanguages)

  @Test("resolvedLanguages preserves each non-English code in order")
  func resolvedLanguagesPreservesNonEnglish() throws {
    let cmd = try CastCommand.parse([
      "--language", "es", "--language", "pt", "--language", "it", "--language", "de",
    ])
    #expect(try cmd.resolvedLanguages() == ["es", "pt", "it", "de"])
  }

  @Test("resolvedLanguages lowercases non-English codes")
  func resolvedLanguagesLowercasesNonEnglish() throws {
    let cmd = try CastCommand.parse([
      "--language", "ES", "--language", "PT", "--language", "IT", "--language", "DE",
    ])
    #expect(try cmd.resolvedLanguages() == ["es", "pt", "it", "de"])
  }

  // MARK: - Castability passthrough (castableLanguages)

  @Test("A member with a base voice prompt is castable for every non-English language")
  func baseDescriptionCastableForAllNonEnglish() {
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: "a warm, measured narrator",
      voices: [:]
    )
    #expect(castableLanguages(for: member, requestedLanguages: Self.languages) == Self.languages)
  }

  @Test("A member with only a localized voice is castable for that language", arguments: languages)
  func localizedVoiceCastableForItsLanguage(_ language: String) {
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: nil,
      voices: [language: "localized \(language) voice"]
    )
    #expect(castableLanguages(for: member, requestedLanguages: [language]) == [language])
  }

  // MARK: - Prompt-selection passthrough (localizedVoicePrompt)

  @Test("localizedVoicePrompt returns the language-specific prompt", arguments: languages)
  func localizedPromptSelectedPerLanguage(_ language: String) {
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: "base english prompt",
      voices: [language: "prompt for \(language)"]
    )
    #expect(localizedVoicePrompt(for: member, language: language) == "prompt for \(language)")
  }

  @Test("Regional subtag falls back to the base-language prompt", arguments: regionalToBase)
  func regionalSubtagResolvesToBasePrompt(_ pair: (regional: String, base: String)) {
    // e.g. a request for "pt-BR" picks up a documented voices["pt"] entry.
    let member = CastMember(
      character: "NARRATOR",
      voiceDescription: nil,
      voices: [pair.base: "prompt for \(pair.base)"]
    )
    #expect(localizedVoicePrompt(for: member, language: pair.regional) == "prompt for \(pair.base)")
  }
}
