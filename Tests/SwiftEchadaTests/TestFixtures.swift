import Foundation
@testable import SwiftEchada

// MARK: - Test Fixtures

/// Provides test data for unit tests
public enum TestFixtures {

    // MARK: - Character Fixtures

    public static func createSampleCharacter(
        name: String = "John Doe",
        type: CharacterType = .lead
    ) -> Character {
        Character(
            name: name,
            aliases: ["Johnny", "JD"],
            age: "35",
            gender: "Male",
            physicalDescription: "Tall, athletic build, brown hair",
            personalityTraits: "Brave, loyal, quick-witted",
            background: "Former detective turned private investigator",
            relationships: "Brother to Jane Doe, mentor to Tim Smith",
            characterArc: "Learns to trust others again after betrayal",
            firstAppearance: "1",
            lastAppearance: "120",
            totalScenes: 45,
            dialogueCount: 180,
            notableDialogue: ["We need to talk.", "This ends now."],
            characterType: type,
            castingStatus: .notCast,
            castingNotes: "Looking for strong dramatic actor",
            castingAgeRange: "30-40",
            requiredSkills: ["Stage combat", "Driving"],
            physicalRequirements: "Must be comfortable with stunts",
            unionRequirements: "SAG-AFTRA preferred",
            availabilityDates: "March-June 2025"
        )
    }

    public static func createLeadCharacter() -> Character {
        createSampleCharacter(name: "Sarah Connor", type: .lead)
    }

    public static func createSupportingCharacter() -> Character {
        Character(
            name: "Jane Smith",
            totalScenes: 15,
            dialogueCount: 45,
            characterType: .supporting
        )
    }

    public static func createFeaturedCharacter() -> Character {
        Character(
            name: "Bob Wilson",
            totalScenes: 5,
            dialogueCount: 12,
            characterType: .featured
        )
    }

    public static func createBackgroundCharacter() -> Character {
        Character(
            name: "Extra #1",
            totalScenes: 3,
            dialogueCount: 0,
            characterType: .background
        )
    }

    public static func createMultipleCharacters() -> [Character] {
        return [
            createLeadCharacter(),
            createSupportingCharacter(),
            createFeaturedCharacter(),
            createBackgroundCharacter()
        ]
    }

    // MARK: - Actor Fixtures

    public static func createSampleActor(
        name: String = "Tom Hanks",
        level: ExperienceLevel = .professional
    ) -> Actor {
        let dob = Calendar.current.date(
            from: DateComponents(year: 1980, month: 6, day: 15)
        )!

        return Actor(
            fullName: name,
            stageName: "T. Hanks",
            photoPath: "/photos/tom_hanks.jpg",
            additionalPhotos: ["/photos/tom1.jpg", "/photos/tom2.jpg"],
            dateOfBirth: dob,
            gender: "Male",
            ethnicity: "Caucasian",
            heightInches: 72,
            build: "Average",
            unionStatus: "SAG-AFTRA",
            agentName: "Jane Agent",
            agencyName: "Big Talent Agency",
            agentContact: "jane@bigtalent.com",
            managerInfo: "Manager: Bob Manager",
            resumeURL: "https://example.com/resume",
            reelURL: "https://example.com/reel",
            imdbLink: "https://imdb.com/name/nm0000158",
            socialMedia: ["twitter": "@tomhanks", "instagram": "@tomhanks"],
            websiteURL: "https://tomhanks.com",
            specialSkills: ["Piano", "Running", "Accents"],
            languages: ["English": "Native", "Spanish": "Conversational"],
            accents: ["Southern", "British", "New York"],
            training: "Juilliard School, Method Acting",
            experienceLevel: level,
            genreExperience: ["Drama", "Comedy", "Action"],
            availabilityStart: Date(),
            availabilityEnd: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
            location: "Los Angeles, CA",
            willingToRelocate: true,
            willingToTravel: true,
            workAuthorization: "US Citizen",
            dayRate: 5000.00,
            conflicts: "None"
        )
    }

    public static func createProfessionalActor() -> Actor {
        createSampleActor(name: "Meryl Streep", level: .professional)
    }

    public static func createStarActor() -> Actor {
        createSampleActor(name: "Denzel Washington", level: .star)
    }

    public static func createIntermediateActor() -> Actor {
        Actor(
            fullName: "Jane Newcomer",
            experienceLevel: .intermediate,
            location: "New York, NY"
        )
    }

    public static func createBeginnerActor() -> Actor {
        Actor(
            fullName: "Fresh Face",
            experienceLevel: .beginner,
            location: "Chicago, IL"
        )
    }

    public static func createMultipleActors() -> [Actor] {
        return [
            createProfessionalActor(),
            createStarActor(),
            createIntermediateActor(),
            createBeginnerActor()
        ]
    }

    public static func createAvailableActor() -> Actor {
        let now = Date()
        let later = Calendar.current.date(byAdding: .month, value: 3, to: now)!

        return Actor(
            fullName: "Available Actor",
            experienceLevel: .professional,
            availabilityStart: now,
            availabilityEnd: later,
            location: "Los Angeles, CA"
        )
    }

    public static func createUnavailableActor() -> Actor {
        let morePast = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        let past = Calendar.current.date(byAdding: .month, value: -1, to: Date())!

        return Actor(
            fullName: "Unavailable Actor",
            experienceLevel: .professional,
            availabilityStart: morePast,
            availabilityEnd: past,
            location: "Los Angeles, CA"
        )
    }

    // MARK: - Character with Invalid Data

    public static func createCharacterWithEmptyName() -> Character {
        Character(name: "", characterType: .lead)
    }

    public static func createCharacterWithInvalidScenes() -> Character {
        Character(
            name: "Invalid",
            totalScenes: -5,
            dialogueCount: 10,
            characterType: .lead
        )
    }

    public static func createCharacterWithInvalidDialogue() -> Character {
        Character(
            name: "Invalid",
            totalScenes: 10,
            dialogueCount: -5,
            characterType: .lead
        )
    }

    // MARK: - Actor with Invalid Data

    public static func createActorWithEmptyName() -> Actor {
        Actor(fullName: "")
    }

    public static func createActorWithInvalidHeight() -> Actor {
        Actor(
            fullName: "Too Tall",
            heightInches: 120
        )
    }

    public static func createActorWithInvalidAvailability() -> Actor {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: -10, to: start)!

        return Actor(
            fullName: "Bad Dates",
            availabilityStart: start,
            availabilityEnd: end
        )
    }

    // MARK: - Characters for Classification Testing

    public static func createLeadCharacterForClassification() -> Character {
        // 20+ dialogue, 10+ scenes
        Character(
            name: "Lead Character",
            totalScenes: 12,
            dialogueCount: 25,
            characterType: .lead
        )
    }

    public static func createSupportingCharacterForClassification() -> Character {
        // 10+ dialogue OR 5+ scenes
        Character(
            name: "Supporting Character",
            totalScenes: 3,
            dialogueCount: 12,
            characterType: .supporting
        )
    }

    public static func createFeaturedCharacterForClassification() -> Character {
        // dialogueCount > 0 but < 10
        Character(
            name: "Featured Character",
            totalScenes: 2,
            dialogueCount: 5,
            characterType: .featured
        )
    }

    public static func createBackgroundCharacterForClassification() -> Character {
        // sceneCount > 0, dialogueCount == 0
        Character(
            name: "Background Character",
            totalScenes: 2,
            dialogueCount: 0,
            characterType: .background
        )
    }

    public static func createExtraCharacterForClassification() -> Character {
        // sceneCount == 0, dialogueCount == 0
        Character(
            name: "Extra Character",
            totalScenes: 0,
            dialogueCount: 0,
            characterType: .extra
        )
    }
}
