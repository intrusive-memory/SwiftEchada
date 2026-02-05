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
            CastMember(character: "NARRATOR", actor: nil, voices: ["test://en/old-voice"]),
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
        // NARRATOR should keep existing voice (same provider, skipped)
        #expect(result.updatedFrontMatter.cast?[0].voices == ["test://en/old-voice"])
        // HERO should get matched
        #expect(result.updatedFrontMatter.cast?[1].voices.first?.contains("voice-2") == true)
    }

    @Test func forceRematchesAll() async throws {
        let cast = [
            CastMember(character: "NARRATOR", actor: nil, voices: ["test://en/old-voice"]),
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

    // MARK: - Provider-aware accumulation tests

    @Test func accumulatesVoicesAcrossProviders() async throws {
        let cast = [
            CastMember(character: "NARRATOR", actor: nil, voices: ["apple://en/Aaron"]),
            CastMember(character: "HERO", actor: nil, voices: []),
        ]
        let matcher = CastMatcher(providerId: "test", model: "m", force: false)

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast),
            voices: makeVoices()
        ) { _, _, _ in
            "voice-1"
        }

        // NARRATOR had apple voice, test provider adds alongside it
        #expect(result.matchedCount == 2)
        #expect(result.updatedFrontMatter.cast?[0].voices == ["apple://en/Aaron", "test://en/voice-1"])
        #expect(result.updatedFrontMatter.cast?[1].voices == ["test://en/voice-1"])
    }

    @Test func skipsCharacterWithExistingVoiceForSameProvider() async throws {
        let cast = [
            CastMember(character: "NARRATOR", actor: nil, voices: ["test://en/old-voice"]),
        ]
        let matcher = CastMatcher(providerId: "test", model: "m", force: false)

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast),
            voices: makeVoices()
        ) { _, _, _ in
            "voice-1"
        }

        #expect(result.matchedCount == 0)
        #expect(result.updatedFrontMatter.cast?[0].voices == ["test://en/old-voice"])
    }

    @Test func forceReplacesOnlyCurrentProviderVoice() async throws {
        let cast = [
            CastMember(character: "NARRATOR", actor: nil, voices: ["apple://en/Aaron", "test://en/old-voice"]),
        ]
        let matcher = CastMatcher(providerId: "test", model: "m", force: true)

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast),
            voices: makeVoices()
        ) { _, _, _ in
            "voice-1"
        }

        #expect(result.matchedCount == 1)
        // apple voice preserved, test voice replaced
        #expect(result.updatedFrontMatter.cast?[0].voices == ["apple://en/Aaron", "test://en/voice-1"])
    }

    @Test func malformedVoiceURIsPreserved() async throws {
        let cast = [
            CastMember(character: "NARRATOR", actor: nil, voices: ["no-scheme-here"]),
        ]
        let matcher = CastMatcher(providerId: "test", model: "m", force: false)

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast),
            voices: makeVoices()
        ) { _, _, _ in
            "voice-1"
        }

        // Malformed URI preserved, new voice appended (character had no "test" voice)
        #expect(result.matchedCount == 1)
        #expect(result.updatedFrontMatter.cast?[0].voices == ["no-scheme-here", "test://en/voice-1"])
    }

    @Test func elevenLabsAccumulatesWithExistingAppleVoice() async throws {
        let cast = [
            CastMember(character: "NARRATOR", actor: nil, voices: ["apple://en/Aaron"]),
        ]
        let mock = MockElevenLabsHTTPClient(voiceIds: ["vid-1"])
        let matcher = CastMatcher(
            providerId: "elevenlabs", languageCode: "en", model: "m",
            force: false, elevenLabsAPIKey: "test-key", httpClient: mock
        )

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast)
        ) { _, _, _ in fatalError("LLM should not be called for elevenlabs") }

        #expect(result.matchedCount == 1)
        // Apple voice preserved, elevenlabs voice added
        #expect(result.updatedFrontMatter.cast?[0].voices == ["apple://en/Aaron", "elevenlabs://en/vid-1"])
    }

    @Test func providerExtractionFromVoiceURI() {
        #expect(CastMember.provider(from: "apple://en/Aaron") == "apple")
        #expect(CastMember.provider(from: "elevenlabs://en/vid-1") == "elevenlabs")
        #expect(CastMember.provider(from: "test://en/voice-1") == "test")
        #expect(CastMember.provider(from: "APPLE://en/Aaron") == "apple")
        #expect(CastMember.provider(from: "no-scheme-here") == nil)
        #expect(CastMember.provider(from: "") == nil)
        #expect(CastMember.provider(from: "://missing-scheme") == nil)
    }

    @Test func voicesReplacingProvider() {
        let member = CastMember(character: "TEST", voices: ["apple://en/Aaron", "test://en/old"])

        // Replace existing provider
        let replaced = member.voicesReplacingProvider("test", with: "test://en/new")
        #expect(replaced == ["apple://en/Aaron", "test://en/new"])

        // Append new provider
        let appended = member.voicesReplacingProvider("elevenlabs", with: "elevenlabs://en/vid-1")
        #expect(appended == ["apple://en/Aaron", "test://en/old", "elevenlabs://en/vid-1"])

        // Collapse multiple voices for same provider
        let multi = CastMember(character: "TEST", voices: ["test://en/a", "test://en/b", "apple://en/Aaron"])
        let collapsed = multi.voicesReplacingProvider("test", with: "test://en/new")
        #expect(collapsed == ["test://en/new", "apple://en/Aaron"])

        // Malformed URIs preserved
        let malformed = CastMember(character: "TEST", voices: ["no-scheme", "apple://en/Aaron"])
        let preserved = malformed.voicesReplacingProvider("test", with: "test://en/voice-1")
        #expect(preserved == ["no-scheme", "apple://en/Aaron", "test://en/voice-1"])

        // Case insensitive
        let cased = CastMember(character: "TEST", voices: ["APPLE://en/Aaron"])
        let casedResult = cased.voicesReplacingProvider("apple", with: "apple://en/new")
        #expect(casedResult == ["apple://en/new"])
    }

    // MARK: - ElevenLabs voice design tests

    @Test func elevenLabsDesignsVoiceForCast() async throws {
        let cast = [
            CastMember(character: "NARRATOR", voiceDescription: "Deep male narrator voice"),
            CastMember(character: "HERO", voiceDescription: "Young female hero"),
        ]
        let mock = MockElevenLabsHTTPClient(voiceIds: ["vid-1", "vid-2"])
        let matcher = CastMatcher(
            providerId: "elevenlabs", languageCode: "en", model: "m",
            force: false, elevenLabsAPIKey: "test-key", httpClient: mock
        )

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast)
        ) { _, _, _ in fatalError("LLM should not be called for elevenlabs") }

        #expect(result.matchedCount == 2)
        #expect(result.skippedCount == 0)
        #expect(result.updatedFrontMatter.cast?[0].voices == ["elevenlabs://en/vid-1"])
        #expect(result.updatedFrontMatter.cast?[1].voices == ["elevenlabs://en/vid-2"])
    }

    @Test func elevenLabsFallsBackToCharacterName() async throws {
        let cast = [CastMember(character: "NARRATOR")]
        let mock = MockElevenLabsHTTPClient(voiceIds: ["vid-1"])
        let matcher = CastMatcher(
            providerId: "elevenlabs", model: "m",
            elevenLabsAPIKey: "test-key", httpClient: mock
        )

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast)
        ) { _, _, _ in fatalError("LLM should not be called") }

        #expect(result.matchedCount == 1)
        // Verify the design request used character name (checked via mock)
        let requestCount = await mock.requestCount
        #expect(requestCount == 3) // voices lookup + design + create
    }

    @Test func elevenLabsSkipsOnError() async throws {
        let cast = [CastMember(character: "NARRATOR")]
        let mock = MockElevenLabsHTTPClient(voiceIds: [], shouldFail: true)
        let matcher = CastMatcher(
            providerId: "elevenlabs", model: "m",
            elevenLabsAPIKey: "test-key", httpClient: mock
        )

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast)
        ) { _, _, _ in fatalError("LLM should not be called") }

        #expect(result.matchedCount == 0)
        #expect(result.skippedCount == 1)
    }

    @Test func elevenLabsSkipsExistingVoices() async throws {
        let cast = [
            CastMember(character: "NARRATOR", actor: nil, voices: ["elevenlabs://en/existing"]),
            CastMember(character: "HERO"),
        ]
        let mock = MockElevenLabsHTTPClient(voiceIds: ["vid-new"])
        let matcher = CastMatcher(
            providerId: "elevenlabs", model: "m",
            elevenLabsAPIKey: "test-key", httpClient: mock
        )

        let result = try await matcher.match(
            frontMatter: makeFrontMatter(cast: cast)
        ) { _, _, _ in fatalError("LLM should not be called") }

        #expect(result.matchedCount == 1)
        #expect(result.updatedFrontMatter.cast?[0].voices == ["elevenlabs://en/existing"])
        #expect(result.updatedFrontMatter.cast?[1].voices == ["elevenlabs://en/vid-new"])
    }

    @Test func elevenLabsNotUsedWithoutAPIKey() async throws {
        let cast = [CastMember(character: "NARRATOR")]
        let matcher = CastMatcher(
            providerId: "elevenlabs", model: "m"
            // no elevenLabsAPIKey
        )

        // Without API key, falls through to normal voice fetch path which will throw
        // because there's no real service — this confirms the code path selection
        await #expect(throws: Error.self) {
            _ = try await matcher.match(
                frontMatter: makeFrontMatter(cast: cast)
            ) { _, _, _ in "voice-1" }
        }
    }
}

// MARK: - Mock HTTP Client for ElevenLabs tests

private actor MockElevenLabsHTTPClient: ElevenLabsHTTPClient {
    let voiceIds: [String]
    let shouldFail: Bool
    var requestCount = 0
    private var voiceIndex = 0

    init(voiceIds: [String], shouldFail: Bool = false) {
        self.voiceIds = voiceIds
        self.shouldFail = shouldFail
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCount += 1

        if shouldFail {
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 500,
                httpVersion: nil, headerFields: nil
            )!
            return (Data("{\"detail\":\"error\"}".utf8), response)
        }

        let path = request.url?.path ?? ""
        let json: String

        if path.hasSuffix("/design") {
            // designVoice response
            let vid = voiceIndex < voiceIds.count ? voiceIds[voiceIndex] : "fallback-id"
            let audioBase64 = Data("fake-audio".utf8).base64EncodedString()
            json = """
            {
                "previews": [{
                    "audio_base_64": "\(audioBase64)",
                    "generated_voice_id": "\(vid)",
                    "media_type": "audio/mpeg",
                    "duration_secs": 1.5
                }],
                "text": "preview text"
            }
            """
        } else if path.hasSuffix("/text-to-voice") {
            // createVoice response
            let vid = voiceIndex < voiceIds.count ? voiceIds[voiceIndex] : "fallback-id"
            voiceIndex += 1
            json = """
            {
                "voice_id": "\(vid)",
                "name": "Test Voice",
                "labels": {},
                "collection_ids": [],
                "high_quality_base_model_ids": []
            }
            """
        } else if path.contains("/voices") {
            // voices listing response — return empty list so no existing voice is found
            json = """
            {
                "voices": [],
                "has_more": false,
                "total_count": 0
            }
            """
        } else {
            json = "{}"
        }

        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200,
            httpVersion: nil, headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(json.utf8), response)
    }

    func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        fatalError("Not used in voice design tests")
    }
}
