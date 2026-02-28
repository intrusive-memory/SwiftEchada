import Foundation
import Testing
import SwiftProyecto
@testable import SwiftEchada

/// Tests that complex voice prompts survive the full pipeline from PROJECT.md YAML
/// through to the voice design instruction sent to the TTS model.
///
/// Regression test for: voicePrompt field was silently dropped during CastMember
/// deserialization (CodingKeys mismatch), causing all voices to be generated with
/// generic fallback descriptions like "A adult person with a MITCH voice".
@Suite("Voice Prompt Round-Trip Tests")
struct VoicePromptRoundTripTests {

    // MARK: - YAML → CastMember deserialization

    @Test func voicePromptFieldSurvivesYAMLParsing() throws {
        let yaml = """
            ---
            type: project
            title: Test
            author: Test
            created: 2026-01-01T00:00:00Z
            cast:
              - character: MITCH
                voicePrompt: "A warm, sardonic American male voice in his late 40s, smooth baritone with dry wit."
                voices:
                  voxalta: voices/MITCH.vox
            ---
            """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        let cast = try #require(frontMatter.cast)
        #expect(cast.count == 1)

        let mitch = cast[0]
        #expect(mitch.character == "MITCH")

        // This is the critical assertion: voiceDescription must NOT be nil
        let prompt = try #require(mitch.voiceDescription,
            "voicePrompt was silently dropped during YAML parsing — CodingKeys mismatch")
        #expect(prompt.contains("sardonic"))
        #expect(prompt.contains("baritone"))
    }

    @Test func voiceDescriptionFieldAlsoWorks() throws {
        let yaml = """
            ---
            type: project
            title: Test
            author: Test
            created: 2026-01-01T00:00:00Z
            cast:
              - character: GILD
                voiceDescription: "A gruff detective voice, deep baritone."
                voices:
                  voxalta: voices/GILD.vox
            ---
            """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)

        let cast = try #require(frontMatter.cast)
        let gild = cast[0]
        let prompt = try #require(gild.voiceDescription,
            "Legacy voiceDescription field should still be parsed")
        #expect(prompt.contains("gruff"))
    }

    // MARK: - Serialization round-trip

    @Test func voicePromptSurvivesWriteAndReparse() throws {
        let yaml = """
            ---
            type: project
            title: Test
            author: Test
            created: 2026-01-01T00:00:00Z
            cast:
              - character: BILLY
                voicePrompt: "A flamboyant, theatrical gay male voice in his mid 40s, born into wealth. Bright, warm tenor with dramatic flair."
                voices:
                  voxalta: voices/BILLY.vox
            ---
            """

        let parser = ProjectMarkdownParser()

        // Parse original
        let (frontMatter, body) = try parser.parse(content: yaml)
        let originalPrompt = try #require(frontMatter.cast?.first?.voiceDescription)
        #expect(originalPrompt.contains("flamboyant"))

        // Re-serialize
        let regenerated = parser.generate(frontMatter: frontMatter, body: body)

        // Re-parse the regenerated content
        let (reparsed, _) = try parser.parse(content: regenerated)
        let roundTrippedPrompt = try #require(reparsed.cast?.first?.voiceDescription,
            "voicePrompt must survive write → re-parse round-trip")
        #expect(roundTrippedPrompt.contains("flamboyant"),
            "Rich prompt content lost during serialization round-trip")
        #expect(roundTrippedPrompt.contains("theatrical"))
    }
}
