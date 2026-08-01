import Foundation
import NaturalLanguage
import SwiftVoxAlta
import Testing

@testable import EchadaCLICore

/// Coverage for the curated voice-audition sentences.
///
/// These replace `FoundationModelSentenceTests`, which asked Apple's on-device
/// Foundation Model for a sentence and then asserted `NLLanguageRecognizer`
/// agreed on its language. That test was doubly non-deterministic — the model's
/// output varied per run, and language detection on a single short sentence is
/// unreliable — so it failed intermittently for es/it/pt and was skipped
/// entirely on CI, where Apple Intelligence isn't provisioned.
///
/// Everything here is pure data validation: no model, no network, no
/// availability gate, and identical results on every machine including CI.
@Suite("Curated audition sentences")
struct AuditionSentenceTests {

  /// Every language the TTS model supports must have curated sentences —
  /// otherwise a voice that *can* be synthesized has nothing to audition with.
  static let ttsSupportedLanguages = ["zh", "en", "de", "it", "pt", "es", "ja", "ko", "fr", "ru"]

  @Test("Every TTS-supported language has audition sentences", arguments: ttsSupportedLanguages)
  func coversEveryTTSLanguage(_ code: String) throws {
    let sentence = try AuditionSentence.auditionSentence(language: code)
    #expect(!sentence.isEmpty, "no audition sentence for '\(code)'")
  }

  @Test("Curated languages match the TTS-supported set exactly")
  func coverageMatchesExactly() {
    #expect(
      Set(AuditionSentence.supportedLanguages) == Set(Self.ttsSupportedLanguages),
      "curated set \(AuditionSentence.supportedLanguages) drifted from the TTS-supported set")
  }

  /// Selection must be deterministic — the audition audio is the voice-lock
  /// reference, so varying text would vary the resulting `.vox` embedding.
  @Test("Selection is deterministic", arguments: ttsSupportedLanguages)
  func deterministic(_ code: String) throws {
    let first = try AuditionSentence.auditionSentence(language: code)
    let second = try AuditionSentence.auditionSentence(language: code)
    #expect(first == second)
  }

  @Test(
    "Regional tags and language names resolve to their base language",
    arguments: [
      ("es-MX", "es"), ("es_MX", "es"), ("pt-BR", "pt"), ("de-AT", "de"),
      ("it-IT", "it"), ("EN-GB", "en"), ("English", "en"), ("japanese", "ja"),
      // Dialects collapse to the language they are spoken in. These carry a
      // literal underscore, so they only resolve if the alias lookup happens
      // before `_` is normalized to `-` — otherwise they split to a bare
      // `beijing`/`sichuan` and throw.
      ("beijing_dialect", "zh"), ("beijingDialect", "zh"), ("beijing", "zh"),
      ("sichuan_dialect", "zh"), ("sichuanDialect", "zh"), ("sichuan", "zh"),
      // `auto` means "let the model infer"; English is the historical default.
      ("auto", "en"),
    ])
  func resolvesToBaseLanguage(_ input: String, _ expected: String) throws {
    #expect(AuditionSentence.baseCode(input) == expected)

    let viaTag = try AuditionSentence.auditionSentence(language: input)
    let viaBase = try AuditionSentence.auditionSentence(language: expected)
    #expect(viaTag == viaBase, "'\(input)' should audition as '\(expected)'")
  }

  /// The parity gate that matters operationally.
  ///
  /// `CastVoiceGenerator` resolves the audition sentence *before* building the
  /// `TTSLanguage`, and outside the per-character `do`/`catch` — so any input
  /// `TTSLanguage` accepts but this table misses aborts the **entire cast run**
  /// instead of skipping one character. Driving it from `allCases` means adding
  /// a TTS language fails here until it has sentences, rather than in the field.
  @Test(
    "Every TTSLanguage case has an audition sentence",
    arguments: TTSLanguage.allCases)
  func parityWithTTSLanguage(_ language: TTSLanguage) throws {
    // PROJECT.md and `--language` can carry either spelling.
    for tag in Set([language.rawValue, language.modelName]) {
      let sentence = try AuditionSentence.auditionSentence(language: tag)
      #expect(!sentence.isEmpty, "no audition sentence for TTSLanguage '\(tag)'")
    }
  }

  /// Same guarantee, stated over concrete user-facing spellings: if
  /// `TTSLanguage` accepts the tag, the audition must not be what rejects it.
  @Test(
    "Tags TTSLanguage accepts never abort the audition",
    arguments: [
      "en", "es-MX", "pt-BR", "zh", "ru", "auto",
      "beijing", "beijing_dialect", "beijingDialect",
      "sichuan", "sichuan_dialect", "sichuanDialect",
      "English", "japanese", "korean",
    ])
  func acceptsEverythingTTSLanguageAccepts(_ tag: String) throws {
    // Precondition: TTSLanguage really does accept this tag, so a failure below
    // is a genuine divergence and not a bad test input.
    _ = try TTSLanguage(languageCode: tag)

    let sentence = try AuditionSentence.auditionSentence(language: tag)
    #expect(!sentence.isEmpty, "'\(tag)' resolves for TTS but has no audition sentence")
  }

  /// The sentence contract, enforced against the data rather than sanitized at
  /// runtime: no quotes, ellipses, em dashes, or stacked punctuation, all of
  /// which destabilize Qwen3-TTS speaker conditioning.
  @Test("Every curated sentence satisfies the TTS text contract")
  func sentenceContract() {
    let forbidden: [Character] = ["\"", "“", "”", "«", "»", "—", "\n", "\t"]
    let stackable: Set<Character> = [".", "!", "?", ",", ";", ":"]

    for (code, pool) in AuditionSentence.pools {
      #expect(!pool.isEmpty, "\(code): empty pool")

      for sentence in pool {
        #expect(
          sentence == sentence.trimmingCharacters(in: .whitespacesAndNewlines),
          "\(code): untrimmed whitespace in: \(sentence)")

        for character in forbidden {
          #expect(
            !sentence.contains(character),
            "\(code): forbidden character '\(character)' in: \(sentence)")
        }

        #expect(!sentence.contains("..."), "\(code): ellipsis in: \(sentence)")

        var previous: Character?
        for character in sentence {
          if let prev = previous, stackable.contains(character), stackable.contains(prev) {
            Issue.record("\(code): stacked punctuation '\(prev)\(character)' in: \(sentence)")
            break
          }
          previous = character
        }
      }
    }
  }

  /// Sentences must be long enough to exercise a voice and short enough to stay
  /// a quick audition. CJK languages are measured in characters, since they are
  /// not space-delimited.
  @Test("Every curated sentence is a usable audition length")
  func sentenceLength() {
    let characterCounted: Set<String> = ["zh", "ja", "ko"]

    for (code, pool) in AuditionSentence.pools {
      for sentence in pool {
        if characterCounted.contains(code) {
          let count = sentence.count
          #expect(count >= 15 && count <= 90, "\(code): \(count) chars in: \(sentence)")
        } else {
          let words = sentence.split(whereSeparator: \.isWhitespace).count
          #expect(words >= 12 && words <= 30, "\(code): \(words) words in: \(sentence)")
        }
      }
    }
  }

  @Test("Pools contain no duplicate sentences")
  func noDuplicates() {
    for (code, pool) in AuditionSentence.pools {
      #expect(Set(pool).count == pool.count, "\(code): duplicate sentences in pool")
    }
    let all = AuditionSentence.pools.values.flatMap { $0 }
    #expect(Set(all).count == all.count, "the same sentence appears under two languages")
  }

  @Test("Alternate variants are selectable and wrap safely")
  func variantSelection() throws {
    let pool = try #require(AuditionSentence.pools["en"])

    for index in pool.indices {
      #expect(try AuditionSentence.auditionSentence(language: "en", variant: index) == pool[index])
    }
    // Out-of-range and negative indices wrap rather than trap.
    #expect(try AuditionSentence.auditionSentence(language: "en", variant: pool.count) == pool[0])
    #expect(
      try AuditionSentence.auditionSentence(language: "en", variant: -1) == pool[pool.count - 1])
  }

  @Test("An uncurated language throws with the supported list")
  func unsupportedLanguageThrows() {
    #expect(throws: AuditionSentenceError.self) {
      try AuditionSentence.auditionSentence(language: "xx")
    }

    do {
      _ = try AuditionSentence.auditionSentence(language: "xx")
      Issue.record("expected a throw for an uncurated language")
    } catch let error as AuditionSentenceError {
      let message = error.errorDescription ?? ""
      #expect(message.contains("xx"))
      #expect(message.contains("en"), "error should name the supported languages")
    } catch {
      Issue.record("unexpected error type: \(error)")
    }
  }

  /// A light sanity check that each sentence is plausibly in its stated
  /// language. `NLLanguageRecognizer` is unreliable on single short sentences —
  /// that unreliability is what made the old tests flaky — so this only asserts
  /// the correct language is among the top hypotheses, and only for
  /// space-delimited languages. It is a typo net, not a correctness gate.
  @Test("Sentences are plausibly in their stated language")
  func plausiblyInLanguage() {
    let expected: [String: NLLanguage] = [
      "en": .english, "es": .spanish, "fr": .french,
      "it": .italian, "pt": .portuguese, "de": .german, "ru": .russian,
    ]

    for (code, language) in expected {
      guard let pool = AuditionSentence.pools[code] else { continue }
      for sentence in pool {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sentence)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        #expect(
          hypotheses[language] != nil,
          "\(code): '\(language.rawValue)' not among top hypotheses for: \(sentence)")
      }
    }
  }
}
