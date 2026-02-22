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
            "The shadows grew long as evening settled over the ancient city."
        }

        #expect(sentence == "The shadows grew long as evening settled over the ancient city.")
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
            "I will not let fear dictate my choices any longer."
        }

        #expect(sentence.contains("fear"))
    }

    @Test func stripsQuotesFromResponse() async throws {
        let sentence = try await generator.generate(
            characterName: "TEST",
            description: "test"
        ) { _, _ in
            "\"Hello there, how are you doing today?\""
        }

        #expect(!sentence.hasPrefix("\""))
        #expect(!sentence.hasSuffix("\""))
    }

    @Test func fallsBackOnEmptyResponse() async throws {
        let sentence = try await generator.generate(
            characterName: "NARRATOR",
            description: "test"
        ) { _, _ in
            "   "
        }

        #expect(sentence.contains("NARRATOR"))
        #expect(sentence.contains("preview"))
    }

    @Test func defaultSentenceIncludesName() {
        let sentence = SampleSentenceGenerator.defaultSentence(for: "VILLAIN")
        #expect(sentence.contains("VILLAIN"))
    }
}
