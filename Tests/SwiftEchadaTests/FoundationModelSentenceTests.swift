import Foundation
import FoundationModels
import NaturalLanguage
import Testing

@testable import EchadaCLICore

/// Exercises the on-device Foundation Model audition-sentence source against real
/// Apple Intelligence. echada sources every voice-audition sentence from this
/// path (no curated fallback pools), so these tests verify it produces an
/// in-language sentence for each non-English language.
///
/// **Availability gate.** Apple Intelligence is not provisioned on GitHub-hosted
/// CI runners (`macos-26` reports `SystemLanguageModel.isAvailable == false` —
/// it requires device opt-in, a signed-in Apple Account, and on-device model
/// downloads that ephemeral hosted runners don't have). The generation tests
/// are therefore gated with `.enabled(if: SystemLanguageModel.default.isAvailable)`:
/// they **skip (not fail) on hosted CI** and run end-to-end only locally, on a
/// developer machine with Apple Intelligence enabled, or on a self-hosted
/// Apple-Intelligence-provisioned runner — this repo's `tests.yml` does not
/// provision one, so hosted CI runs never exercise these assertions (accepted,
/// per OPERATION GENERAL MUSTER's resolved OQ-4; see `Docs/build-and-test.md`).
/// The throwing-contract test below runs everywhere — it asserts a
/// `FoundationModelSentenceError` is raised whether the failure is "AI
/// unavailable" or "locale unsupported".
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

  @Test(
    "Generates a sanitized, in-language audition sentence per language",
    .enabled(if: SystemLanguageModel.default.isAvailable),
    arguments: languages)
  func generatesInLanguageSentence(_ entry: (code: String, expected: NLLanguage)) async throws {
    let model = SystemLanguageModel.default
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

  @Test(
    "A regional subtag still produces an in-language sentence",
    .enabled(if: SystemLanguageModel.default.isAvailable))
  func regionalSubtagGeneratesSpanish() async throws {
    let sentence = try await FoundationModelSentence.auditionSentence(language: "es-MX")
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(sentence)
    #expect(recognizer.dominantLanguage == .spanish, "Detected non-Spanish: \(sentence)")
  }

  @Test("An unusable request throws a clear configuration error")
  func unusableRequestThrows() async {
    // Runs everywhere: where Apple Intelligence is unavailable this throws
    // `.appleIntelligenceUnavailable`; where it is available, "zz" is not a
    // supported locale so it throws `.unsupportedLanguage`. Both are
    // FoundationModelSentenceError — the throwing contract holds either way.
    await #expect(throws: FoundationModelSentenceError.self) {
      _ = try await FoundationModelSentence.auditionSentence(language: "zz")
    }
  }
}
