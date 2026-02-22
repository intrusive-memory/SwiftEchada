import Foundation
import Testing
import SwiftProyecto
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
}
