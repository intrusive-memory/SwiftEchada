import Foundation
import Testing
import SwiftProyecto
@testable import SwiftEchada

private actor CallCounter {
    var count = 0
    func increment() -> Int {
        count += 1
        return count
    }
}

private actor PromptCapture {
    var value = ""
    func set(_ prompt: String) {
        value = prompt
    }
}

@Suite("VoiceDescriptionEnricher Tests")
struct VoiceDescriptionEnricherTests {

    private let enricher = VoiceDescriptionEnricher()

    @Test func enrichesMissingDescriptions() async {
        let cast = [
            CastMember(character: "NARRATOR", voices: [:]),
            CastMember(character: "HERO", voices: [:]),
        ]

        let counter = CallCounter()
        let result = await enricher.enrich(
            cast: cast,
            genre: "Drama"
        ) { _, _ in
            let n = await counter.increment()
            return n == 1
                ? "Deep, authoritative baritone with gravitas"
                : "Young, energetic alto with confident diction"
        }

        #expect(result.enrichedCount == 2)
        #expect(result.skippedCount == 0)
        #expect(result.updatedCast[0].voiceDescription == "Deep, authoritative baritone with gravitas")
        #expect(result.updatedCast[1].voiceDescription == "Young, energetic alto with confident diction")
    }

    @Test func skipsExistingDescriptions() async {
        let cast = [
            CastMember(character: "NARRATOR", voiceDescription: "Already described", voices: [:]),
            CastMember(character: "HERO", voices: [:]),
        ]

        let counter = CallCounter()
        let result = await enricher.enrich(
            cast: cast,
            genre: "Drama"
        ) { _, _ in
            await counter.increment()
            return "New description"
        }

        let callCount = await counter.count
        #expect(callCount == 1) // Only HERO should be queried
        #expect(result.enrichedCount == 1)
        #expect(result.updatedCast[0].voiceDescription == "Already described")
        #expect(result.updatedCast[1].voiceDescription == "New description")
    }

    @Test func skipsEmptyDescriptionStrings() async {
        let cast = [
            CastMember(character: "NARRATOR", voiceDescription: "", voices: [:]),
        ]

        let result = await enricher.enrich(
            cast: cast,
            genre: "Comedy"
        ) { _, _ in
            "Warm, humorous baritone"
        }

        #expect(result.enrichedCount == 1)
        #expect(result.updatedCast[0].voiceDescription == "Warm, humorous baritone")
    }

    @Test func handlesLLMFailureGracefully() async {
        let cast = [
            CastMember(character: "NARRATOR", voices: [:]),
            CastMember(character: "HERO", voices: [:]),
        ]

        let counter = CallCounter()
        let result = await enricher.enrich(
            cast: cast,
            genre: "Drama"
        ) { _, _ in
            let n = await counter.increment()
            if n == 1 {
                throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "LLM unavailable"])
            }
            return "Fallback description"
        }

        #expect(result.enrichedCount == 1)
        #expect(result.skippedCount == 1)
        #expect(result.updatedCast[0].voiceDescription == nil) // Failed, kept nil
        #expect(result.updatedCast[1].voiceDescription == "Fallback description")
    }

    @Test func handlesEmptyLLMResponse() async {
        let cast = [
            CastMember(character: "NARRATOR", voices: [:]),
        ]

        let result = await enricher.enrich(
            cast: cast,
            genre: "Drama"
        ) { _, _ in
            "   " // Whitespace-only response
        }

        #expect(result.enrichedCount == 0)
        #expect(result.skippedCount == 1)
        #expect(result.updatedCast[0].voiceDescription == nil)
    }

    @Test func preservesExistingVoices() async {
        let cast = [
            CastMember(
                character: "NARRATOR",
                voices: ["apple": "com.apple.voice.premium.en-US.Aaron"]
            ),
        ]

        let result = await enricher.enrich(
            cast: cast,
            genre: "Drama"
        ) { _, _ in
            "Deep baritone"
        }

        #expect(result.enrichedCount == 1)
        #expect(result.updatedCast[0].voices == ["apple": "com.apple.voice.premium.en-US.Aaron"])
        #expect(result.updatedCast[0].voiceDescription == "Deep baritone")
    }

    @Test func includesActorHintInPrompt() async {
        let cast = [
            CastMember(character: "NARRATOR", actor: "Morgan Freeman", voices: [:]),
        ]

        let capture = PromptCapture()
        let result = await enricher.enrich(
            cast: cast,
            genre: "Documentary"
        ) { userPrompt, _ in
            await capture.set(userPrompt)
            return "Deep, warm baritone inspired by Morgan Freeman"
        }

        #expect(result.enrichedCount == 1)
        let prompt = await capture.value
        #expect(prompt.contains("Morgan Freeman"))
    }

    @Test func includesGenderInPrompt() async {
        let cast = [
            CastMember(character: "HERO", gender: .female, voices: [:]),
        ]

        let capture = PromptCapture()
        _ = await enricher.enrich(
            cast: cast,
            genre: "Action"
        ) { userPrompt, _ in
            await capture.set(userPrompt)
            return "Strong, assertive mezzo-soprano"
        }

        let prompt = await capture.value
        #expect(prompt.contains("Female"))
    }

    @Test func handlesEmptyCast() async {
        let result = await enricher.enrich(
            cast: [],
            genre: "Drama"
        ) { _, _ in
            "Should not be called"
        }

        #expect(result.enrichedCount == 0)
        #expect(result.skippedCount == 0)
        #expect(result.updatedCast.isEmpty)
    }
}
