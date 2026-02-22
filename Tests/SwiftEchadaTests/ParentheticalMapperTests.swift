import Foundation
import Testing
@testable import SwiftEchada

@Suite("ParentheticalMapper Tests")
struct ParentheticalMapperTests {

    private let mapper = ParentheticalMapper()

    // MARK: - Static Mappings

    @Test func mapsWhispering() async {
        let result = await mapper.map("(whispering)")
        #expect(result == "speak in a whisper")
    }

    @Test func mapsAngrily() async {
        let result = await mapper.map("angrily")
        #expect(result == "speak angrily with intensity")
    }

    @Test func mapsSadly() async {
        let result = await mapper.map("(sadly)")
        #expect(result == "speak with sadness and sorrow")
    }

    @Test func mapsContd() async {
        let result = await mapper.map("(cont'd)")
        #expect(result == "continue speaking naturally")
    }

    @Test func mapsCrying() async {
        let result = await mapper.map("crying")
        #expect(result == "speak while crying")
    }

    @Test func mapsShouting() async {
        let result = await mapper.map("(SHOUTING)")
        #expect(result == "speak loudly as if shouting")
    }

    // MARK: - Blocking Parentheticals

    @Test func blocksBeat() async {
        let result = await mapper.map("(beat)")
        #expect(result == nil)
    }

    @Test func blocksSilence() async {
        let result = await mapper.map("silence")
        #expect(result == nil)
    }

    @Test func blocksLongPause() async {
        let result = await mapper.map("(long pause)")
        #expect(result == nil)
    }

    // MARK: - Unmapped Parentheticals

    @Test func unmappedReturnsGenericInstruct() async {
        let result = await mapper.map("(enigmatically)")
        #expect(result == "speak enigmatically")
    }

    // MARK: - LLM Fallback

    @Test func usesLLMFallback() async {
        let result = await mapper.map("(with a twinkle in her eye)") { _, _ in
            "speak with playful warmth and mischief"
        }
        #expect(result == "speak with playful warmth and mischief")
    }

    @Test func llmFallbackBlocksOnBLOCK() async {
        let result = await mapper.map("(stares silently)") { _, _ in
            "BLOCK"
        }
        #expect(result == nil)
    }

    @Test func llmFallbackHandlesError() async {
        let result = await mapper.map("(mysteriously)") { _, _ in
            throw NSError(domain: "test", code: 1)
        }
        #expect(result == "speak mysteriously")
    }

    // MARK: - Normalization

    @Test func normalizesWhitespace() async {
        let result = await mapper.map("(  whispering  )")
        #expect(result == "speak in a whisper")
    }

    @Test func handlesCaseInsensitive() async {
        let result = await mapper.map("(ANGRILY)")
        #expect(result == "speak angrily with intensity")
    }
}
