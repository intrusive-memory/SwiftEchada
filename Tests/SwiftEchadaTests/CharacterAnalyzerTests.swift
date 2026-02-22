import Foundation
import Testing
import SwiftProyecto
@testable import SwiftEchada

@Suite("CharacterAnalyzer Tests")
struct CharacterAnalyzerTests {

    private let analyzer = CharacterAnalyzer()

    @Test func parsesValidJSON() async throws {
        let member = CastMember(
            character: "NARRATOR",
            gender: .male,
            voiceDescription: "Deep authoritative baritone",
            voices: [:]
        )

        let profile = try await analyzer.analyze(member: member) { _, _ in
            """
            {
              "name": "NARRATOR",
              "gender": "male",
              "ageRange": "50s",
              "description": "Deep authoritative baritone with gravitas",
              "voiceTraits": ["deep", "authoritative", "gravitas"],
              "summary": "Mature male narrator with commanding presence"
            }
            """
        }

        #expect(profile.name == "NARRATOR")
        #expect(profile.gender == .male)
        #expect(profile.ageRange == "50s")
        #expect(profile.voiceTraits.count == 3)
    }

    @Test func parsesJSONInCodeBlock() async throws {
        let member = CastMember(character: "HERO", voices: [:])

        let profile = try await analyzer.analyze(member: member) { _, _ in
            """
            ```json
            {
              "name": "HERO",
              "gender": "female",
              "ageRange": "20s",
              "description": "Young energetic voice",
              "voiceTraits": ["energetic", "clear"],
              "summary": "Young female hero"
            }
            ```
            """
        }

        #expect(profile.name == "HERO")
        #expect(profile.gender == .female)
    }

    @Test func fallsBackOnInvalidJSON() async throws {
        let member = CastMember(
            character: "VILLAIN",
            gender: .male,
            voiceDescription: "Menacing, low, gravelly",
            voices: [:]
        )

        let profile = try await analyzer.analyze(member: member) { _, _ in
            "This is not valid JSON at all"
        }

        // Heuristic fallback
        #expect(profile.name == "VILLAIN")
        #expect(profile.gender == .male)
        #expect(profile.ageRange == "adult")
        #expect(profile.description == "Menacing, low, gravelly")
    }

    @Test func fallsBackOnQueryError() async throws {
        let member = CastMember(
            character: "SIDEKICK",
            voiceDescription: "Cheerful and bright",
            voices: [:]
        )

        let profile = try await analyzer.analyze(member: member) { _, _ in
            throw NSError(domain: "test", code: 1)
        }

        #expect(profile.name == "SIDEKICK")
        #expect(profile.gender == .notSpecified)
        #expect(profile.description == "Cheerful and bright")
    }

    @Test func usesCharacterNameWhenNoDescription() async throws {
        let member = CastMember(character: "MYSTERIOUS STRANGER", voices: [:])

        let profile = try await analyzer.analyze(member: member) { _, _ in
            throw NSError(domain: "test", code: 1)
        }

        #expect(profile.description == "MYSTERIOUS STRANGER")
    }
}
