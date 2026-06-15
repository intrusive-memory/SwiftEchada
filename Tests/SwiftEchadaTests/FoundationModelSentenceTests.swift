import Foundation
import FoundationModels
import NaturalLanguage
import Testing

@testable import EchadaCLICore

/// Exercises the on-device Foundation Model audition-sentence source against real
/// Apple Intelligence. echada now sources every voice-audition sentence from this
/// path (no curated fallback pools), so these tests verify it actually produces
/// an in-language sentence for each non-English language and fails loudly when it
/// can't.
///
/// CI runs on Apple silicon (`macos-26`) with Apple Intelligence available, so
/// the model path runs end-to-end here — it is not mocked.
@Suite("FoundationModelSentence — on-device in-language generation")
struct FoundationModelSentenceTests {

  /// The non-English languages under test, paired with the `NLLanguage` we expect
  /// `NLLanguageRecognizer` to detect from the generated sentence.
  static let languages: [(code: String, expected: NLLanguage)] = [
    ("es", .spanish),
    ("pt", .portuguese),
    ("it", .italian),
    ("de", .german),
  ]

  /// Apple Intelligence must be provisioned on the host. If this fails, the
  /// environment is misconfigured (AI disabled / unsupported host) — fix the
  /// runner, don't delete the test: echada hard-requires the on-device model.
  @Test("Apple Intelligence is available on this host")
  func appleIntelligenceAvailable() throws {
    try FoundationModelSentence.requireAvailable()
    #expect(SystemLanguageModel.default.isAvailable)
  }

  @Test(
    "Generates a sanitized, in-language audition sentence per language",
    arguments: languages)
  func generatesInLanguageSentence(_ entry: (code: String, expected: NLLanguage)) async throws {
    let model = SystemLanguageModel.default
    try #require(model.isAvailable)
    try #require(model.supportsLocale(Locale(identifier: entry.code)))

    let sentence = try await FoundationModelSentence.auditionSentence(language: entry.code)

    // Sanitization contract: single, non-empty line free of wrapping quotes and
    // stacked terminal punctuation (which destabilizes Qwen3-TTS conditioning).
    #expect(!sentence.isEmpty)
    #expect(!sentence.contains("\n"))
    #expect(sentence.first != "\"" && sentence.last != "\"")
    #expect(!sentence.contains("...") && !sentence.contains("!!"))

    // The whole point of the feature: the sentence is actually in the requested
    // language, not English.
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(sentence)
    #expect(
      recognizer.dominantLanguage == entry.expected,
      """
      Expected \(entry.code) (\(entry.expected.rawValue)) but detected \
      \(recognizer.dominantLanguage?.rawValue ?? "nil"): \(sentence)
      """)
  }

  @Test("A regional subtag still produces an in-language sentence")
  func regionalSubtagGeneratesSpanish() async throws {
    let model = SystemLanguageModel.default
    try #require(model.isAvailable)

    let sentence = try await FoundationModelSentence.auditionSentence(language: "es-MX")
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(sentence)
    #expect(recognizer.dominantLanguage == .spanish, "Detected non-Spanish: \(sentence)")
  }

  @Test("An unsupported language throws a clear configuration error")
  func unsupportedLanguageThrows() async {
    // "zz" is not a real language Apple Intelligence supports.
    await #expect(throws: FoundationModelSentenceError.self) {
      _ = try await FoundationModelSentence.auditionSentence(language: "zz")
    }
  }
}
