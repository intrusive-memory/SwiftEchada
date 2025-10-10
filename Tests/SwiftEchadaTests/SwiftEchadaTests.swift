import Testing
import Foundation
import SwiftData
@testable import SwiftEchada

// MARK: - Phase 0 Tests: Foundation & Setup

/// Test suite for SwiftEchada Phase 0 gate criteria
struct SwiftEchadaTests {

    // MARK: - Basic Setup Tests

    @Test("Version information is available")
    func testVersionInfo() async throws {
        #expect(SwiftEchada.version == "0.1.0")
        #expect(SwiftEchada.phase == "Phase 0: Foundation & Setup")
    }

    // MARK: - SwiftData Configuration Tests

    @Test("SwiftData configuration initializes successfully")
    func testSwiftDataConfiguration() async throws {
        // Test in-memory configuration
        let config = try SwiftEchadaConfiguration(inMemory: true)
        #expect(config.modelContainer != nil)
    }

    @Test("SwiftData model context can be created")
    func testModelContextCreation() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        #expect(context != nil)
    }

    // MARK: - Character Model Tests

    @Test("Character can be created with required fields")
    func testCharacterCreation() async throws {
        let character = Character(
            name: "John Doe",
            characterType: .lead
        )

        #expect(character.name == "John Doe")
        #expect(character.characterType == .lead)
        #expect(character.aliases.isEmpty)
        #expect(character.totalScenes == 0)
        #expect(character.dialogueCount == 0)
    }

    @Test("Character can be created with all fields")
    func testCharacterCreationWithAllFields() async throws {
        let character = Character(
            name: "Sarah Connor",
            aliases: ["Sarah", "Connor"],
            age: "30s",
            gender: "Female",
            physicalDescription: "Strong, determined warrior",
            firstAppearance: "1",
            lastAppearance: "45",
            totalScenes: 42,
            dialogueCount: 156,
            characterType: .lead
        )

        #expect(character.name == "Sarah Connor")
        #expect(character.aliases == ["Sarah", "Connor"])
        #expect(character.age == "30s")
        #expect(character.gender == "Female")
        #expect(character.physicalDescription == "Strong, determined warrior")
        #expect(character.firstAppearance == "1")
        #expect(character.lastAppearance == "45")
        #expect(character.totalScenes == 42)
        #expect(character.dialogueCount == 156)
        #expect(character.characterType == .lead)
    }

    @Test("Character persists to SwiftData store")
    func testCharacterPersistence() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)

        let character = Character(
            name: "Test Character",
            characterType: .supporting
        )

        context.insert(character)
        try context.save()

        // Fetch back from store
        let descriptor = FetchDescriptor<Character>(
            predicate: #Predicate { $0.name == "Test Character" }
        )
        let fetchedCharacters = try context.fetch(descriptor)

        #expect(fetchedCharacters.count == 1)
        #expect(fetchedCharacters.first?.name == "Test Character")
        #expect(fetchedCharacters.first?.characterType == .supporting)
    }

    @Test("Multiple characters can be stored and queried")
    func testMultipleCharactersPersistence() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)

        let characters = [
            Character(name: "Alice", characterType: .lead),
            Character(name: "Bob", characterType: .supporting),
            Character(name: "Charlie", characterType: .featured)
        ]

        for character in characters {
            context.insert(character)
        }
        try context.save()

        // Fetch all characters
        let descriptor = FetchDescriptor<Character>()
        let fetchedCharacters = try context.fetch(descriptor)

        #expect(fetchedCharacters.count == 3)

        // Verify names
        let names = fetchedCharacters.map { $0.name }.sorted()
        #expect(names == ["Alice", "Bob", "Charlie"])
    }

    // MARK: - SwiftGuion Integration Tests

    @Test("ScreenplayParserService can be initialized")
    func testParserServiceCreation() async throws {
        let service = ScreenplayParserService()
        #expect(service != nil)
    }

    @Test("Sample screenplay file exists")
    func testSampleScreenplayExists() async throws {
        let testBundle = Bundle.module
        let resourceURL = testBundle.url(
            forResource: "sample",
            withExtension: "fountain",
            subdirectory: "Resources"
        )

        #expect(resourceURL != nil, "Sample screenplay should exist in Resources")

        if let url = resourceURL {
            let fileExists = FileManager.default.fileExists(atPath: url.path)
            #expect(fileExists, "Sample screenplay file should be accessible")
        }
    }

    @Test("Parser can extract characters from sample screenplay")
    func testScreenplayParsing() async throws {
        let testBundle = Bundle.module

        guard let resourceURL = testBundle.url(
            forResource: "sample",
            withExtension: "fountain",
            subdirectory: "Resources"
        ) else {
            Issue.record("Sample screenplay not found")
            return
        }

        let service = ScreenplayParserService()
        let characters = try await service.parseScreenplay(from: resourceURL)

        // Our sample script has SARAH, MARK, and BARISTA
        #expect(characters.count == 3, "Should extract 3 characters from sample screenplay")

        let characterNames = characters.map { $0.name }.sorted()
        #expect(characterNames.contains("SARAH"), "Should find SARAH")
        #expect(characterNames.contains("MARK"), "Should find MARK")
        #expect(characterNames.contains("BARISTA"), "Should find BARISTA")
    }

    @Test("Parsed characters have dialogue counts")
    func testParsedCharactersHaveDialogue() async throws {
        let testBundle = Bundle.module

        guard let resourceURL = testBundle.url(
            forResource: "sample",
            withExtension: "fountain",
            subdirectory: "Resources"
        ) else {
            Issue.record("Sample screenplay not found")
            return
        }

        let service = ScreenplayParserService()
        let characters = try await service.parseScreenplay(from: resourceURL)

        // All speaking characters should have dialogue count > 0
        let speakingCharacters = characters.filter { $0.dialogueCount > 0 }
        #expect(speakingCharacters.count >= 2, "At least 2 characters should have dialogue")
    }

    @Test("Character type classification works")
    func testCharacterTypeClassification() async throws {
        let testBundle = Bundle.module

        guard let resourceURL = testBundle.url(
            forResource: "sample",
            withExtension: "fountain",
            subdirectory: "Resources"
        ) else {
            Issue.record("Sample screenplay not found")
            return
        }

        let service = ScreenplayParserService()
        let characters = try await service.parseScreenplay(from: resourceURL)

        // Verify that characters are classified
        for character in characters {
            #expect(
                [.lead, .supporting, .featured, .background, .extra].contains(character.characterType),
                "Character should have a valid type classification"
            )
        }
    }

    // MARK: - Integration Test: Full Workflow

    @Test("Full workflow: Parse screenplay and persist to SwiftData")
    func testFullWorkflow() async throws {
        // 1. Set up SwiftData
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)

        // 2. Parse screenplay
        let testBundle = Bundle.module
        guard let resourceURL = testBundle.url(
            forResource: "sample",
            withExtension: "fountain",
            subdirectory: "Resources"
        ) else {
            Issue.record("Sample screenplay not found")
            return
        }

        let service = ScreenplayParserService()
        let characters = try await service.parseScreenplay(from: resourceURL)

        // 3. Persist characters
        for character in characters {
            context.insert(character)
        }
        try context.save()

        // 4. Query back from store
        let descriptor = FetchDescriptor<Character>()
        let persistedCharacters = try context.fetch(descriptor)

        // 5. Verify
        #expect(persistedCharacters.count == characters.count)
        #expect(persistedCharacters.count > 0, "Should have persisted at least one character")

        // Verify we can query by name
        if let firstCharacter = characters.first {
            let characterName = firstCharacter.name
            let nameDescriptor = FetchDescriptor<Character>(
                predicate: #Predicate { $0.name == characterName }
            )
            let found = try context.fetch(nameDescriptor)
            #expect(found.count == 1)
            #expect(found.first?.name == firstCharacter.name)
        }
    }
}
