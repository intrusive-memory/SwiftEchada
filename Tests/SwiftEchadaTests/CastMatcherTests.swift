import Foundation
import Testing
import SwiftHablare
import SwiftProyecto
@testable import SwiftEchada

private actor CallCounter {
    var count = 0
    func increment() -> Int {
        count += 1
        return count
    }
}

@Suite("CastMatcher Tests")
struct CastMatcherTests {

    private func makeFrontMatter(cast: [CastMember]?) -> ProjectFrontMatter {
        ProjectFrontMatter(
            title: "Test", author: "A", created: Date(),
            genre: "Drama", cast: cast
        )
    }

    private func makeVoices() -> [Voice] {
        [
            Voice(id: "voice-1", name: "Alice", description: nil, providerId: "test", language: "en", gender: "female"),
            Voice(id: "voice-2", name: "Bob", description: nil, providerId: "test", language: "en", gender: "male"),
            Voice(id: "voice-3", name: "Charlie", description: nil, providerId: "test", language: "es", gender: "male"),
        ]
    }

    @Test func matchesVoicesToCast() async throws {
        let cast = [
            CastMember(character: "NARRATOR", actor: nil, voices: []),
            CastMember(character: "HERO", actor: nil, voices: []),
        ]
        let matcher = CastMatcher(providerId: "test", languageCode: "en", model: "m", force: false)

        let counter = CallCounter()
        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast),
            voices: makeVoices()
        ) { _, _, _ in
            let n = await counter.increment()
            return n <= 1 ? "voice-1" : "voice-2"
        }

        #expect(result.matchedCount == 2)
        #expect(result.skippedCount == 0)
        #expect(result.updatedFrontMatter.cast?[0].voices == ["test://en/voice-1"])
        #expect(result.updatedFrontMatter.cast?[1].voices == ["test://en/voice-2"])
    }

    @Test func skipsExistingVoicesWhenNotForced() async throws {
        let cast = [
            CastMember(character: "NARRATOR", actor: nil, voices: ["existing://voice"]),
            CastMember(character: "HERO", actor: nil, voices: []),
        ]
        let matcher = CastMatcher(providerId: "test", model: "m", force: false)

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast),
            voices: makeVoices()
        ) { _, _, _ in
            "voice-2"
        }

        #expect(result.matchedCount == 1)
        #expect(result.skippedCount == 0)
        // NARRATOR should keep existing voice
        #expect(result.updatedFrontMatter.cast?[0].voices == ["existing://voice"])
        // HERO should get matched
        #expect(result.updatedFrontMatter.cast?[1].voices.first?.contains("voice-2") == true)
    }

    @Test func forceRematchesAll() async throws {
        let cast = [
            CastMember(character: "NARRATOR", actor: nil, voices: ["existing://voice"]),
        ]
        let matcher = CastMatcher(providerId: "test", model: "m", force: true)

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast),
            voices: makeVoices()
        ) { _, _, _ in
            "voice-1"
        }

        #expect(result.matchedCount == 1)
        #expect(result.updatedFrontMatter.cast?[0].voices == ["test://en/voice-1"])
    }

    @Test func throwsOnEmptyVoices() async throws {
        let cast = [CastMember(character: "NARRATOR")]
        let matcher = CastMatcher(providerId: "test", model: "m")

        await #expect(throws: CastMatcherError.self) {
            _ = try await matcher.match(
                frontMatter: makeFrontMatter(cast: cast),
                voices: []
            ) { _, _, _ in "voice-1" }
        }
    }

    @Test func throwsOnNoCastMembers() async throws {
        let matcher = CastMatcher(providerId: "test", model: "m")

        await #expect(throws: CastMatcherError.self) {
            _ = try await matcher.match(
                frontMatter: makeFrontMatter(cast: nil),
                voices: makeVoices()
            ) { _, _, _ in "voice-1" }
        }

        await #expect(throws: CastMatcherError.self) {
            _ = try await matcher.match(
                frontMatter: makeFrontMatter(cast: []),
                voices: makeVoices()
            ) { _, _, _ in "voice-1" }
        }
    }

    @Test func retriesOnInvalidVoiceId() async throws {
        let cast = [CastMember(character: "NARRATOR")]
        let matcher = CastMatcher(providerId: "test", model: "m")

        let counter = CallCounter()
        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast),
            voices: makeVoices()
        ) { _, _, _ in
            let n = await counter.increment()
            return n == 1 ? "invalid-id" : "voice-1"
        }

        let finalCount = await counter.count
        #expect(finalCount == 2)
        #expect(result.matchedCount == 1)
    }

    @Test func skipsAfterRetryFails() async throws {
        let cast = [CastMember(character: "NARRATOR")]
        let matcher = CastMatcher(providerId: "test", model: "m")

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast),
            voices: makeVoices()
        ) { _, _, _ in
            "never-valid"
        }

        #expect(result.matchedCount == 0)
        #expect(result.skippedCount == 1)
    }

    @Test func skipsOnQueryError() async throws {
        let cast = [CastMember(character: "NARRATOR")]
        let matcher = CastMatcher(providerId: "test", model: "m")

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast),
            voices: makeVoices()
        ) { _, _, _ in
            throw CastMatcherError.noCastMembers // any error
        }

        #expect(result.matchedCount == 0)
        #expect(result.skippedCount == 1)
    }

    @Test func usesLanguageCodeFallback() async throws {
        let cast = [CastMember(character: "NARRATOR")]
        let voicesNoLang = [
            Voice(id: "v1", name: "Test", description: nil, providerId: "test", language: nil),
        ]
        let matcher = CastMatcher(providerId: "test", languageCode: "fr", model: "m")

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast),
            voices: voicesNoLang
        ) { _, _, _ in "v1" }

        #expect(result.updatedFrontMatter.cast?[0].voices == ["test://fr/v1"])
    }
}
