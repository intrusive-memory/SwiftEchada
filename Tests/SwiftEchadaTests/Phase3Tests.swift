import Testing
import Foundation
import SwiftData
@testable import SwiftEchada

// MARK: - Phase 3 Tests: Casting Relationship & Workflow

/// Comprehensive test suite for Phase 3 - targeting 90% coverage
/// Focus: Casting workflow, audition tracking, queries and reports
struct Phase3Tests {

    // MARK: - Casting Relationship Tests

    @Test("Cast actor to character updates status")
    func testCastActorUpdatesStatus() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        let actor = TestFixtures.createProfessionalActor()

        try repos.characters.create(character)
        try repos.actors.create(actor)

        #expect(character.castingStatus == .notCast)

        try repos.casting.cast(actor, as: character)

        #expect(character.castingStatus == .cast)
        #expect(repos.casting.getActors(for: character).count == 1)
    }

    @Test("Uncast character resets status and removes actors")
    func testUncastCharacterResetsStatus() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        let actor = TestFixtures.createProfessionalActor()

        try repos.characters.create(character)
        try repos.actors.create(actor)
        try repos.casting.cast(actor, as: character)

        #expect(character.castingStatus == .cast)

        try repos.casting.uncast(character)

        #expect(character.castingStatus == .notCast)
        #expect(repos.casting.getActors(for: character).isEmpty)
    }

    @Test("Multiple actors can audition for same character")
    func testMultipleActorsAudition() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        let actors = TestFixtures.createMultipleActors()

        try repos.characters.create(character)
        try repos.actors.createBatch(actors)

        for actor in actors {
            try repos.casting.linkActorToCharacter(actor, character)
        }

        let linkedActors = repos.casting.getActors(for: character)
        #expect(linkedActors.count == actors.count)
    }

    @Test("Single actor can be cast to multiple roles")
    func testActorMultipleRoles() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let actor = TestFixtures.createProfessionalActor()
        let characters = TestFixtures.createMultipleCharacters()

        try repos.actors.create(actor)
        try repos.characters.createBatch(characters)

        for character in characters {
            try repos.casting.linkActorToCharacter(actor, character)
        }

        let linkedCharacters = repos.casting.getCharacters(for: actor)
        #expect(linkedCharacters.count == characters.count)
    }

    // MARK: - Casting Status Workflow Tests

    @Test("Casting status transitions from notCast to auditioned")
    func testStatusTransitionToAuditioned() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        try repos.characters.create(character)

        #expect(character.castingStatus == .notCast)

        try repos.characters.updateCastingStatus(character, to: .auditioned)
        #expect(character.castingStatus == .auditioned)
    }

    @Test("Casting status transitions from auditioned to callback")
    func testStatusTransitionToCallback() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        character.castingStatus = .auditioned

        try repos.characters.create(character)
        try repos.characters.updateCastingStatus(character, to: .callback)

        #expect(character.castingStatus == .callback)
    }

    @Test("Casting status transitions from callback to cast")
    func testStatusTransitionToCast() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        character.castingStatus = .callback

        try repos.characters.create(character)
        try repos.characters.updateCastingStatus(character, to: .cast)

        #expect(character.castingStatus == .cast)
    }

    @Test("Casting status can be set to offered")
    func testStatusOffered() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        try repos.characters.create(character)

        try repos.characters.updateCastingStatus(character, to: .offered)
        #expect(character.castingStatus == .offered)
    }

    // MARK: - Casting Queries Tests

    @Test("Find all uncast characters")
    func testFindUncastCharacters() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        try repos.characters.createBatch(characters)

        // Cast one character
        let actor = TestFixtures.createProfessionalActor()
        try repos.actors.create(actor)
        try repos.casting.cast(actor, as: characters.first!)

        let uncast = try repos.characters.findByCastingStatus(.notCast)
        #expect(uncast.count == characters.count - 1)
    }

    @Test("Find all cast characters")
    func testFindCastCharacters() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        let actors = TestFixtures.createMultipleActors()

        try repos.characters.createBatch(characters)
        try repos.actors.createBatch(actors)

        // Cast two characters
        try repos.casting.cast(actors[0], as: characters[0])
        try repos.casting.cast(actors[1], as: characters[1])

        let cast = try repos.characters.findByCastingStatus(.cast)
        #expect(cast.count == 2)
    }

    @Test("Find characters in audition process")
    func testFindAuditionedCharacters() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        try repos.characters.createBatch(characters)

        // Set some to auditioned
        try repos.characters.updateCastingStatus(characters[0], to: .auditioned)
        try repos.characters.updateCastingStatus(characters[1], to: .auditioned)

        let auditioned = try repos.characters.findByCastingStatus(.auditioned)
        #expect(auditioned.count == 2)
    }

    @Test("Count characters by casting status")
    func testCountByCastingStatus() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        try repos.characters.createBatch(characters)

        // Update statuses
        try repos.characters.updateCastingStatus(characters[0], to: .auditioned)
        try repos.characters.updateCastingStatus(characters[1], to: .cast)

        #expect(try repos.characters.count(withStatus: .notCast) == 2)
        #expect(try repos.characters.count(withStatus: .auditioned) == 1)
        #expect(try repos.characters.count(withStatus: .cast) == 1)
    }

    // MARK: - Integration: Parse and Cast Workflow

    @Test("Full workflow: Parse screenplay, cast actors")
    func testFullCastingWorkflow() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        // 1. Parse screenplay
        let service = ScreenplayParserService()
        let characters = try await service.parseScreenplay(from: Fijos.sampleScreenplay)
        try repos.characters.createBatch(characters)

        #expect(characters.count > 0, "Should have parsed some characters")

        // 2. Create actor pool
        let actors = TestFixtures.createMultipleActors()
        try repos.actors.createBatch(actors)

        // 3. Audition actors for major speaking roles (using the first character as our target)
        let speakingCharacters = try repos.characters.findSpeakingCharacters()
        #expect(speakingCharacters.count > 0, "Should have speaking characters")

        let targetCharacter = speakingCharacters.first!

        for actor in actors.prefix(2) {
            try repos.casting.linkActorToCharacter(actor, targetCharacter)
        }
        try repos.characters.updateCastingStatus(targetCharacter, to: .auditioned)

        // 4. Cast selected actor
        try repos.casting.cast(actors.first!, as: targetCharacter)

        // 5. Verify workflow
        #expect(targetCharacter.castingStatus == .cast)
        #expect(repos.casting.getActors(for: targetCharacter).count == 2)

        let castCharacters = try repos.characters.findByCastingStatus(.cast)
        #expect(castCharacters.count == 1)
    }

    // MARK: - Edge Cases and Validation

    @Test("Cannot link same actor to character twice")
    func testPreventDuplicateLinks() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        let actor = TestFixtures.createProfessionalActor()

        try repos.characters.create(character)
        try repos.actors.create(actor)

        try repos.casting.linkActorToCharacter(actor, character)
        try repos.casting.linkActorToCharacter(actor, character) // Should not duplicate

        let linkedActors = repos.casting.getActors(for: character)
        #expect(linkedActors.count == 1)
    }

    @Test("Unlinking non-existent actor is safe")
    func testUnlinkNonExistentActor() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        let actor = TestFixtures.createProfessionalActor()

        try repos.characters.create(character)
        try repos.actors.create(actor)

        // Try to unlink without linking first - should not crash
        try repos.casting.unlinkActorFromCharacter(actor, character)

        let linkedActors = repos.casting.getActors(for: character)
        #expect(linkedActors.isEmpty)
    }

    @Test("Timestamps update when casting changes")
    func testTimestampsOnCastingChanges() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        let actor = TestFixtures.createProfessionalActor()

        try repos.characters.create(character)
        try repos.actors.create(actor)

        let originalCharacterTime = character.updatedAt
        let originalActorTime = actor.updatedAt

        try await Task.sleep(for: .milliseconds(10))

        try repos.casting.linkActorToCharacter(actor, character)

        #expect(character.updatedAt > originalCharacterTime)
        #expect(actor.updatedAt > originalActorTime)
    }

    // MARK: - Casting Report Tests

    @Test("Generate casting progress report")
    func testCastingProgressReport() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        let actors = TestFixtures.createMultipleActors()

        try repos.characters.createBatch(characters)
        try repos.actors.createBatch(actors)

        // Simulate casting process
        try repos.casting.cast(actors[0], as: characters[0])
        try repos.characters.updateCastingStatus(characters[1], to: .auditioned)
        try repos.characters.updateCastingStatus(characters[2], to: .offered)

        // Generate report data
        let totalCharacters = try repos.characters.count()
        let castCount = try repos.characters.count(withStatus: .cast)
        let auditionedCount = try repos.characters.count(withStatus: .auditioned)
        let offeredCount = try repos.characters.count(withStatus: .offered)
        let notCastCount = try repos.characters.count(withStatus: .notCast)

        #expect(totalCharacters == 4)
        #expect(castCount == 1)
        #expect(auditionedCount == 1)
        #expect(offeredCount == 1)
        #expect(notCastCount == 1)
        #expect(castCount + auditionedCount + offeredCount + notCastCount == totalCharacters)
    }

    @Test("Identify available actors for specific role")
    func testAvailableActorsForRole() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        // Create character requiring specific skills
        let character = TestFixtures.createLeadCharacter()
        character.requiredSkills = ["Piano", "Stage combat"]

        try repos.characters.create(character)

        // Create actors with various skills
        let actors = TestFixtures.createMultipleActors()
        try repos.actors.createBatch(actors)

        // Find actors with piano skill
        let pianoActors = try repos.actors.findBySkill("Piano")
        #expect(pianoActors.count > 0)
    }

    @Test("Track multiple actors for callback stage")
    func testCallbackTracking() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        let actors = TestFixtures.createMultipleActors()

        try repos.characters.create(character)
        try repos.actors.createBatch(actors)

        // Link multiple actors to character for callback
        for actor in actors.prefix(3) {
            try repos.casting.linkActorToCharacter(actor, character)
        }

        try repos.characters.updateCastingStatus(character, to: .callback)

        #expect(character.castingStatus == .callback)
        #expect(repos.casting.getActors(for: character).count == 3)
    }

    // MARK: - Business Logic Tests

    @Test("Casting a character with existing actors keeps them linked")
    func testCastingKeepsExistingLinks() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        let actors = TestFixtures.createMultipleActors()

        try repos.characters.create(character)
        try repos.actors.createBatch(actors)

        // Link multiple actors
        for actor in actors.prefix(3) {
            try repos.casting.linkActorToCharacter(actor, character)
        }

        #expect(repos.casting.getActors(for: character).count == 3)

        // Cast specific actor
        try repos.casting.cast(actors[0], as: character)

        // All actors should still be linked
        #expect(repos.casting.getActors(for: character).count == 3)
        #expect(character.castingStatus == .cast)
    }

    @Test("Find leads that need casting")
    func testFindLeadsNeedingCasting() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let characters = [
            TestFixtures.createLeadCharacter(),
            TestFixtures.createSupportingCharacter(),
            TestFixtures.createLeadCharacter()
        ]

        try repos.characters.createBatch(characters)

        // Cast one lead
        let actor = TestFixtures.createProfessionalActor()
        try repos.actors.create(actor)
        try repos.casting.cast(actor, as: characters[0])

        // Find uncast leads
        let allLeads = try repos.characters.findByType(.lead)
        let uncastLeads = allLeads.filter { $0.castingStatus == .notCast }

        #expect(allLeads.count == 2)
        #expect(uncastLeads.count == 1)
    }

    @Test("Generate character breakdown with casting info")
    func testCharacterBreakdown() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        let character = TestFixtures.createLeadCharacter()
        let actors = TestFixtures.createMultipleActors()

        try repos.characters.create(character)
        try repos.actors.createBatch(actors)

        // Add casting info
        for actor in actors.prefix(2) {
            try repos.casting.linkActorToCharacter(actor, character)
        }
        try repos.characters.updateCastingStatus(character, to: .callback)

        // Breakdown data
        #expect(character.name != "")
        #expect(character.characterType == .lead)
        #expect(character.totalScenes > 0)
        #expect(character.dialogueCount > 0)
        #expect(character.castingStatus == .callback)
        #expect(repos.casting.getActors(for: character).count == 2)
    }
}
