import Foundation
import SwiftProyecto
import Testing

@testable import SwiftEchada

@Suite("SampleSentenceGenerator Tests")
struct SampleSentenceGeneratorTests {

  private let generator = SampleSentenceGenerator()

  @Test func generatesFromDescription() async throws {
    let sentence = try await generator.generate(
      characterName: "NARRATOR",
      description: "Deep, authoritative baritone"
    ) { _, _ in
      "This closure is ignored."
    }

    #expect(SampleSentenceGenerator.quotes.contains(sentence))
  }

  @Test func generatesFromProfile() async throws {
    let profile = CharacterProfile(
      name: "HERO",
      gender: .female,
      ageRange: "20s",
      description: "Young, energetic voice",
      voiceTraits: ["energetic", "clear", "confident"],
      summary: "Young female hero with confident diction"
    )

    let sentence = try await generator.generate(from: profile) { _, _ in
      "This closure is ignored."
    }

    #expect(SampleSentenceGenerator.quotes.contains(sentence))
  }

  @Test func defaultSentenceFromQuotes() {
    let sentence = SampleSentenceGenerator.defaultSentence(for: "VILLAIN")
    #expect(SampleSentenceGenerator.quotes.contains(sentence))
  }

  @Test func randomQuoteReturnsFromPool() {
    for _ in 0..<10 {
      let quote = SampleSentenceGenerator.randomQuote()
      #expect(SampleSentenceGenerator.quotes.contains(quote))
    }
  }

  // MARK: - Language-aware quotes

  @Test func randomQuoteSpanishReturnsSpanish() {
    for _ in 0..<10 {
      let quote = SampleSentenceGenerator.randomQuote(language: "es")
      #expect(SampleSentenceGenerator.quotesES.contains(quote))
    }
  }

  @Test func randomQuoteEnglishMatchesDefaultPool() {
    for _ in 0..<10 {
      let quote = SampleSentenceGenerator.randomQuote(language: "en")
      #expect(SampleSentenceGenerator.quotes.contains(quote))
    }
  }

  @Test func unknownLanguageFallsBackToEnglish() {
    for _ in 0..<10 {
      let quote = SampleSentenceGenerator.randomQuote(language: "xx")
      #expect(SampleSentenceGenerator.quotes.contains(quote))
    }
  }

  @Test func regionSubtagResolvesToBaseLanguage() {
    for _ in 0..<10 {
      let quote = SampleSentenceGenerator.randomQuote(language: "es-MX")
      #expect(SampleSentenceGenerator.quotesES.contains(quote))
    }
  }

  @Test func defaultSentenceWithLanguageSpanish() {
    let sentence = SampleSentenceGenerator.defaultSentence(for: "VILLANO", language: "es")
    #expect(SampleSentenceGenerator.quotesES.contains(sentence))
  }

  @Test func zeroArgOverloadsUnchanged() {
    // Source-compat: the no-language overloads still draw from the English pool.
    #expect(SampleSentenceGenerator.quotes.contains(SampleSentenceGenerator.randomQuote()))
    #expect(
      SampleSentenceGenerator.quotes.contains(
        SampleSentenceGenerator.defaultSentence(for: "X")))
  }
}
