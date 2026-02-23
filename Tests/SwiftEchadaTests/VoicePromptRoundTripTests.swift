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

    private let analyzer = CharacterAnalyzer()

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

    // MARK: - CastMember → CharacterAnalyzer uses the prompt

    @Test func analyzerReceivesVoicePromptNotCharacterName() async throws {
        let complexPrompt = """
            A warm, sardonic American male voice in his late 40s to early 50s, \
            with the measured cadence of an experienced journalist. Smooth baritone, \
            unhurried and deliberately precise. Dry wit delivered with understated elegance.
            """

        let member = CastMember(
            character: "MITCH",
            gender: .male,
            voiceDescription: complexPrompt,
            voices: ["voxalta": "voices/MITCH.vox"]
        )

        // Capture what the analyzer sends to the LLM
        nonisolated(unsafe) var capturedUserPrompt: String?

        let profile = try await analyzer.analyze(member: member) { userPrompt, _ in
            capturedUserPrompt = userPrompt
            // Return valid JSON so we can inspect what the LLM received
            return """
                {
                  "name": "MITCH",
                  "gender": "male",
                  "ageRange": "late 40s",
                  "description": "\(complexPrompt.replacingOccurrences(of: "\n", with: " "))",
                  "voiceTraits": ["warm", "sardonic", "baritone", "unhurried", "precise"],
                  "summary": "Experienced journalist with smooth baritone and dry wit"
                }
                """
        }

        // The LLM prompt must contain the complex description, not just "MITCH"
        let prompt = try #require(capturedUserPrompt)
        #expect(prompt.contains("sardonic"),
            "Analyzer should send the full voice prompt to the LLM, not just the character name")
        #expect(prompt.contains("baritone"))
        #expect(prompt.contains("journalist"))

        // The resulting profile should carry the rich description through
        #expect(profile.description.contains("sardonic"))
        #expect(profile.voiceTraits.contains("baritone"))
    }

    @Test func analyzerFallsBackToCharacterNameWhenNoPrompt() async throws {
        let member = CastMember(
            character: "MITCH",
            voices: ["voxalta": "voices/MITCH.vox"]
        )

        nonisolated(unsafe) var capturedUserPrompt: String?

        _ = try await analyzer.analyze(member: member) { userPrompt, _ in
            capturedUserPrompt = userPrompt
            throw NSError(domain: "test", code: 1)
        }

        // Without a voiceDescription, it falls back to character name
        let prompt = try #require(capturedUserPrompt)
        #expect(prompt.contains("MITCH"))
        #expect(!prompt.contains("sardonic"),
            "Should not contain rich description when voiceDescription is nil")
    }

    // MARK: - Full round-trip: YAML → parse → analyze → compose

    @Test func fullPipelinePreservesComplexPrompt() async throws {
        let yaml = """
            ---
            type: project
            title: Test
            author: Test
            created: 2026-01-01T00:00:00Z
            cast:
              - character: OLIVIA
                voicePrompt: "A commanding, imperious Black woman's voice in her 60s -- self-possessed, elegant, and unafraid of silence. Sharp, precise diction. A velvet hammer."
                voices:
                  voxalta: voices/OLIVIA.vox
            ---
            """

        let parser = ProjectMarkdownParser()
        let (frontMatter, _) = try parser.parse(content: yaml)
        let cast = try #require(frontMatter.cast)
        let member = cast[0]

        // Verify the prompt survived parsing
        let voiceDesc = try #require(member.voiceDescription)
        #expect(voiceDesc.contains("imperious"))
        #expect(voiceDesc.contains("velvet hammer"))

        // Verify the analyzer passes it through (not the character name)
        nonisolated(unsafe) var capturedPrompt: String?
        _ = try await analyzer.analyze(member: member) { userPrompt, _ in
            capturedPrompt = userPrompt
            throw NSError(domain: "test", code: 1) // force fallback to inspect raw behavior
        }

        let sent = try #require(capturedPrompt)
        #expect(sent.contains("imperious"),
            "Full pipeline: voicePrompt from YAML must reach the LLM query")
        #expect(sent.contains("velvet hammer"))
        #expect(!sent.contains("Voice description: OLIVIA"),
            "Must not degrade to character name as the voice description")
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
