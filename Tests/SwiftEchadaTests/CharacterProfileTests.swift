import Foundation
import Testing
import SwiftProyecto
@testable import SwiftEchada

@Suite("CharacterProfile Tests")
struct CharacterProfileTests {

    @Test func createsProfileWithAllFields() {
        let profile = CharacterProfile(
            name: "NARRATOR",
            gender: .male,
            ageRange: "50s",
            description: "Deep, authoritative voice with gravitas",
            voiceTraits: ["deep", "authoritative", "gravitas"],
            summary: "Mature male narrator with commanding presence"
        )

        #expect(profile.name == "NARRATOR")
        #expect(profile.gender == .male)
        #expect(profile.ageRange == "50s")
        #expect(profile.voiceTraits.count == 3)
        #expect(profile.summary.contains("narrator"))
    }

    @Test func voxFormatGenderMapping() {
        let male = CharacterProfile(
            name: "A", gender: .male, ageRange: "30s",
            description: "test", voiceTraits: [], summary: "test"
        )
        #expect(male.voxFormatGender == "male")

        let female = CharacterProfile(
            name: "B", gender: .female, ageRange: "30s",
            description: "test", voiceTraits: [], summary: "test"
        )
        #expect(female.voxFormatGender == "female")

        let nonBinary = CharacterProfile(
            name: "C", gender: .nonBinary, ageRange: "30s",
            description: "test", voiceTraits: [], summary: "test"
        )
        #expect(nonBinary.voxFormatGender == "nonbinary")

        let notSpecified = CharacterProfile(
            name: "D", gender: .notSpecified, ageRange: "30s",
            description: "test", voiceTraits: [], summary: "test"
        )
        #expect(notSpecified.voxFormatGender == "neutral")
    }

    @Test func profileEquality() {
        let a = CharacterProfile(
            name: "TEST", gender: .male, ageRange: "30s",
            description: "desc", voiceTraits: ["deep"], summary: "sum"
        )
        let b = CharacterProfile(
            name: "TEST", gender: .male, ageRange: "30s",
            description: "desc", voiceTraits: ["deep"], summary: "sum"
        )
        #expect(a == b)
    }

    @Test func profileCodable() throws {
        let profile = CharacterProfile(
            name: "NARRATOR", gender: .female, ageRange: "40s",
            description: "Warm mezzo-soprano", voiceTraits: ["warm", "mezzo"],
            summary: "Warm female narrator"
        )

        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(CharacterProfile.self, from: data)
        #expect(decoded == profile)
    }

    @Test func evidenceDefaultsToEmpty() {
        let evidence = CharacterEvidence()
        #expect(evidence.keyDialogue.isEmpty)
        #expect(evidence.stageDirections.isEmpty)
        #expect(evidence.emotionalRange.isEmpty)
    }
}
