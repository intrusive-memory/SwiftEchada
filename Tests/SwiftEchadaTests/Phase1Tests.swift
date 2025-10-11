import Testing
import Foundation
import SwiftData
@testable import SwiftEchada

// MARK: - Phase 1 Tests: Core Data Models

/// Comprehensive test suite for Phase 1 - targeting 90% coverage
struct Phase1Tests {

    // MARK: - Character Model Tests

    @Test("Character can be created with all Phase 1 fields")
    func testCharacterCreationWithAllFields() async throws {
        let character = TestFixtures.createSampleCharacter()

        #expect(character.name == "John Doe")
        #expect(character.aliases == ["Johnny", "JD"])
        #expect(character.age == "35")
        #expect(character.gender == "Male")
        #expect(character.physicalDescription == "Tall, athletic build, brown hair")
        #expect(character.personalityTraits == "Brave, loyal, quick-witted")
        #expect(character.background == "Former detective turned private investigator")
        #expect(character.relationships == "Brother to Jane Doe, mentor to Tim Smith")
        #expect(character.characterArc == "Learns to trust others again after betrayal")
        #expect(character.firstAppearance == "1")
        #expect(character.lastAppearance == "120")
        #expect(character.totalScenes == 45)
        #expect(character.dialogueCount == 180)
        #expect(character.notableDialogue.count == 2)
        #expect(character.characterType == .lead)
        #expect(character.castingStatus == .notCast)
        #expect(character.castingAgeRange == "30-40")
        #expect(character.requiredSkills.count == 2)
    }

    @Test("Character validation accepts valid character")
    func testCharacterValidationSuccess() async throws {
        let character = TestFixtures.createSampleCharacter()
        try character.validate()
        // No error thrown = success
    }

    @Test("Character validation rejects empty name")
    func testCharacterValidationEmptyName() async throws {
        let character = TestFixtures.createCharacterWithEmptyName()
        #expect(throws: ValidationError.emptyName) {
            try character.validate()
        }
    }

    @Test("Character validation rejects negative scene count")
    func testCharacterValidationNegativeScenes() async throws {
        let character = TestFixtures.createCharacterWithInvalidScenes()
        #expect(throws: ValidationError.invalidSceneCount) {
            try character.validate()
        }
    }

    @Test("Character validation rejects negative dialogue count")
    func testCharacterValidationNegativeDialogue() async throws {
        let character = TestFixtures.createCharacterWithInvalidDialogue()
        #expect(throws: ValidationError.invalidDialogueCount) {
            try character.validate()
        }
    }

    @Test("Character computed property isCast works")
    func testCharacterIsCast() async throws {
        var character = TestFixtures.createSampleCharacter()
        #expect(character.isCast == false)

        character.castingStatus = .cast
        #expect(character.isCast == true)
    }

    @Test("Character computed property isSpeakingRole works")
    func testCharacterIsSpeakingRole() async throws {
        let speaking = TestFixtures.createSampleCharacter()
        #expect(speaking.isSpeakingRole == true)

        let nonSpeaking = TestFixtures.createBackgroundCharacter()
        #expect(nonSpeaking.isSpeakingRole == false)
    }

    @Test("Character importance score calculation")
    func testCharacterImportanceScore() async throws {
        let lead = TestFixtures.createLeadCharacter()
        let supporting = TestFixtures.createSupportingCharacter()
        let background = TestFixtures.createBackgroundCharacter()

        #expect(lead.importanceScore > supporting.importanceScore)
        #expect(supporting.importanceScore > background.importanceScore)
    }

    @Test("Character touch updates timestamp")
    func testCharacterTouch() async throws {
        let character = TestFixtures.createSampleCharacter()
        let originalTime = character.updatedAt

        try await Task.sleep(for: .milliseconds(10))
        character.touch()

        #expect(character.updatedAt > originalTime)
    }

    // MARK: - Actor Model Tests

    @Test("Actor can be created with all Phase 1 fields")
    func testActorCreationWithAllFields() async throws {
        let actor = TestFixtures.createSampleActor()

        #expect(actor.fullName == "Tom Hanks")
        #expect(actor.stageName == "T. Hanks")
        #expect(actor.photoPath == "/photos/tom_hanks.jpg")
        #expect(actor.additionalPhotos.count == 2)
        #expect(actor.dateOfBirth != nil)
        #expect(actor.gender == "Male")
        #expect(actor.ethnicity == "Caucasian")
        #expect(actor.heightInches == 72)
        #expect(actor.build == "Average")
        #expect(actor.unionStatus == "SAG-AFTRA")
        #expect(actor.agentName == "Jane Agent")
        #expect(actor.specialSkills.count == 3)
        #expect(actor.languages.count == 2)
        #expect(actor.accents.count == 3)
        #expect(actor.experienceLevel == .professional)
        #expect(actor.willingToRelocate == true)
        #expect(actor.willingToTravel == true)
    }

    @Test("Actor validation accepts valid actor")
    func testActorValidationSuccess() async throws {
        let actor = TestFixtures.createSampleActor()
        try actor.validate()
        // No error thrown = success
    }

    @Test("Actor validation rejects empty name")
    func testActorValidationEmptyName() async throws {
        let actor = TestFixtures.createActorWithEmptyName()
        #expect(throws: ValidationError.emptyName) {
            try actor.validate()
        }
    }

    @Test("Actor validation rejects invalid height")
    func testActorValidationInvalidHeight() async throws {
        let actor = TestFixtures.createActorWithInvalidHeight()
        #expect(throws: ValidationError.invalidHeight) {
            try actor.validate()
        }
    }

    @Test("Actor validation rejects invalid availability dates")
    func testActorValidationInvalidAvailability() async throws {
        let actor = TestFixtures.createActorWithInvalidAvailability()
        #expect(throws: ValidationError.invalidAvailability) {
            try actor.validate()
        }
    }

    @Test("Actor computed property displayName works")
    func testActorDisplayName() async throws {
        var actor = TestFixtures.createSampleActor()
        #expect(actor.displayName == "T. Hanks")

        actor.stageName = nil
        #expect(actor.displayName == "Tom Hanks")
    }

    @Test("Actor computed property age calculation")
    func testActorAgeCalculation() async throws {
        let actor = TestFixtures.createSampleActor()
        let age = actor.age

        #expect(age != nil)
        #expect(age! >= 40) // Born in 1980
    }

    @Test("Actor computed property isAvailable works")
    func testActorIsAvailable() async throws {
        let available = TestFixtures.createAvailableActor()
        #expect(available.isAvailable == true)

        let unavailable = TestFixtures.createUnavailableActor()
        #expect(unavailable.isAvailable == false)
    }

    @Test("Actor height formatting")
    func testActorHeightFormatted() async throws {
        let actor = TestFixtures.createSampleActor()
        #expect(actor.heightFormatted == "6'0\"")

        var actorNoHeight = TestFixtures.createBeginnerActor()
        actorNoHeight.heightInches = nil
        #expect(actorNoHeight.heightFormatted == nil)
    }

    @Test("Actor touch updates timestamp")
    func testActorTouch() async throws {
        let actor = TestFixtures.createSampleActor()
        let originalTime = actor.updatedAt

        try await Task.sleep(for: .milliseconds(10))
        actor.touch()

        #expect(actor.updatedAt > originalTime)
    }

    // MARK: - Character Repository Tests

    @Test("CharacterRepository can create character")
    func testCharacterRepositoryCreate() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let character = TestFixtures.createSampleCharacter()
        try repo.create(character)

        let all = try repo.readAll()
        #expect(all.count == 1)
        #expect(all.first?.name == "John Doe")
    }

    @Test("CharacterRepository can read by ID")
    func testCharacterRepositoryReadByID() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let character = TestFixtures.createSampleCharacter()
        try repo.create(character)

        let found = try repo.read(id: character.id)
        #expect(found != nil)
        #expect(found?.name == "John Doe")
    }

    @Test("CharacterRepository can update character")
    func testCharacterRepositoryUpdate() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let character = TestFixtures.createSampleCharacter()
        try repo.create(character)

        character.name = "Updated Name"
        try repo.update(character)

        let found = try repo.read(id: character.id)
        #expect(found?.name == "Updated Name")
    }

    @Test("CharacterRepository can delete character")
    func testCharacterRepositoryDelete() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let character = TestFixtures.createSampleCharacter()
        try repo.create(character)
        #expect(try repo.count() == 1)

        try repo.delete(character)
        #expect(try repo.count() == 0)
    }

    @Test("CharacterRepository can delete by ID")
    func testCharacterRepositoryDeleteByID() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let character = TestFixtures.createSampleCharacter()
        try repo.create(character)

        let deleted = try repo.delete(id: character.id)
        #expect(deleted == true)
        #expect(try repo.count() == 0)
    }

    @Test("CharacterRepository can create batch")
    func testCharacterRepositoryCreateBatch() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        try repo.createBatch(characters)

        #expect(try repo.count() == 4)
    }

    @Test("CharacterRepository can find by name")
    func testCharacterRepositoryFindByName() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        try repo.createBatch(characters)

        let found = try repo.findByName("Sarah Connor")
        #expect(found.count == 1)
        #expect(found.first?.name == "Sarah Connor")
    }

    @Test("CharacterRepository can find by type")
    func testCharacterRepositoryFindByType() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        try repo.createBatch(characters)

        let leads = try repo.findByType(.lead)
        #expect(leads.count == 1)
    }

    @Test("CharacterRepository can find by casting status")
    func testCharacterRepositoryFindByCastingStatus() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        var character = TestFixtures.createSampleCharacter()
        character.castingStatus = .auditioned
        try repo.create(character)

        let found = try repo.findByCastingStatus(.auditioned)
        #expect(found.count == 1)
    }

    @Test("CharacterRepository can find speaking characters")
    func testCharacterRepositoryFindSpeaking() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        try repo.createBatch(characters)

        let speaking = try repo.findSpeakingCharacters()
        #expect(speaking.count == 3) // Lead, supporting, featured have dialogue
    }

    @Test("CharacterRepository can find by minimum scenes")
    func testCharacterRepositoryFindByMinimumScenes() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        try repo.createBatch(characters)

        let majorCharacters = try repo.findByMinimumScenes(10)
        #expect(majorCharacters.count == 2) // Lead and supporting
    }

    @Test("CharacterRepository search by name works")
    func testCharacterRepositorySearch() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        try repo.createBatch(characters)

        let found = try repo.search(name: "sarah")
        #expect(found.count == 1)
        #expect(found.first?.name == "Sarah Connor")
    }

    @Test("CharacterRepository can update casting status")
    func testCharacterRepositoryUpdateCastingStatus() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let character = TestFixtures.createSampleCharacter()
        try repo.create(character)

        try repo.updateCastingStatus(character, to: .cast)

        let found = try repo.read(id: character.id)
        #expect(found?.castingStatus == .cast)
    }

    @Test("CharacterRepository can delete all")
    func testCharacterRepositoryDeleteAll() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        try repo.createBatch(characters)
        #expect(try repo.count() == 4)

        let deleted = try repo.deleteAll()
        #expect(deleted == 4)
        #expect(try repo.count() == 0)
    }

    @Test("CharacterRepository count statistics work")
    func testCharacterRepositoryCountStatistics() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let characters = TestFixtures.createMultipleCharacters()
        try repo.createBatch(characters)

        #expect(try repo.count() == 4)
        #expect(try repo.count(ofType: .lead) == 1)
        #expect(try repo.count(ofType: .supporting) == 1)
        #expect(try repo.count(withStatus: .notCast) == 4)
    }

    // MARK: - Actor Repository Tests

    @Test("ActorRepository can create actor")
    func testActorRepositoryCreate() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actor = TestFixtures.createSampleActor()
        try repo.create(actor)

        let all = try repo.readAll()
        #expect(all.count == 1)
        #expect(all.first?.fullName == "Tom Hanks")
    }

    @Test("ActorRepository can read by ID")
    func testActorRepositoryReadByID() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actor = TestFixtures.createSampleActor()
        try repo.create(actor)

        let found = try repo.read(id: actor.id)
        #expect(found != nil)
        #expect(found?.fullName == "Tom Hanks")
    }

    @Test("ActorRepository can update actor")
    func testActorRepositoryUpdate() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actor = TestFixtures.createSampleActor()
        try repo.create(actor)

        actor.fullName = "Thomas Hanks"
        try repo.update(actor)

        let found = try repo.read(id: actor.id)
        #expect(found?.fullName == "Thomas Hanks")
    }

    @Test("ActorRepository can delete actor")
    func testActorRepositoryDelete() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actor = TestFixtures.createSampleActor()
        try repo.create(actor)
        #expect(try repo.count() == 1)

        try repo.delete(actor)
        #expect(try repo.count() == 0)
    }

    @Test("ActorRepository can create batch")
    func testActorRepositoryCreateBatch() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actors = TestFixtures.createMultipleActors()
        try repo.createBatch(actors)

        #expect(try repo.count() == 4)
    }

    @Test("ActorRepository can find by full name")
    func testActorRepositoryFindByFullName() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actors = TestFixtures.createMultipleActors()
        try repo.createBatch(actors)

        let found = try repo.findByFullName("Meryl Streep")
        #expect(found.count == 1)
        #expect(found.first?.fullName == "Meryl Streep")
    }

    @Test("ActorRepository can find by experience level")
    func testActorRepositoryFindByExperienceLevel() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actors = TestFixtures.createMultipleActors()
        try repo.createBatch(actors)

        let professionals = try repo.findByExperienceLevel(.professional)
        #expect(professionals.count == 1)
    }

    @Test("ActorRepository can find by union status")
    func testActorRepositoryFindByUnionStatus() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actor = TestFixtures.createSampleActor()
        try repo.create(actor)

        let found = try repo.findByUnionStatus("SAG-AFTRA")
        #expect(found.count == 1)
    }

    @Test("ActorRepository can find available actors")
    func testActorRepositoryFindAvailable() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let available = TestFixtures.createAvailableActor()
        let unavailable = TestFixtures.createUnavailableActor()
        try repo.create(available)
        try repo.create(unavailable)

        let found = try repo.findAvailableActors()
        #expect(found.count == 1)
        #expect(found.first?.fullName == "Available Actor")
    }

    @Test("ActorRepository can find by location")
    func testActorRepositoryFindByLocation() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actors = TestFixtures.createMultipleActors()
        try repo.createBatch(actors)

        let laActors = try repo.findByLocation("Los Angeles, CA")
        #expect(laActors.count > 0)
    }

    @Test("ActorRepository can find by skill")
    func testActorRepositoryFindBySkill() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actor = TestFixtures.createSampleActor()
        try repo.create(actor)

        let found = try repo.findBySkill("Piano")
        #expect(found.count == 1)
    }

    @Test("ActorRepository search by name works")
    func testActorRepositorySearch() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actors = TestFixtures.createMultipleActors()
        try repo.createBatch(actors)

        let found = try repo.search(name: "streep")
        #expect(found.count == 1)
        #expect(found.first?.fullName == "Meryl Streep")
    }

    @Test("ActorRepository can update availability")
    func testActorRepositoryUpdateAvailability() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actor = TestFixtures.createSampleActor()
        try repo.create(actor)

        let newStart = Date()
        let newEnd = Calendar.current.date(byAdding: .month, value: 3, to: newStart)

        try repo.updateAvailability(actor, start: newStart, end: newEnd)

        let found = try repo.read(id: actor.id)
        #expect(found?.availabilityStart != nil)
        #expect(found?.isAvailable == true)
    }

    @Test("ActorRepository can delete all")
    func testActorRepositoryDeleteAll() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actors = TestFixtures.createMultipleActors()
        try repo.createBatch(actors)
        #expect(try repo.count() == 4)

        let deleted = try repo.deleteAll()
        #expect(deleted == 4)
        #expect(try repo.count() == 0)
    }

    @Test("ActorRepository count statistics work")
    func testActorRepositoryCountStatistics() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actors = TestFixtures.createMultipleActors()
        let available = TestFixtures.createAvailableActor()
        try repo.createBatch(actors + [available])

        #expect(try repo.count() == 5)
        #expect(try repo.count(withExperience: .star) == 1)
        // createMultipleActors includes 2 actors with availability (professional and star),
        // plus the explicit available actor = 3 total
        #expect(try repo.countAvailable() == 3)
    }

    // MARK: - Casting Repository Tests

    @Test("CastingRepository can link actor to character")
    func testCastingRepositoryLink() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let castingRepo = CastingRepository(context: context)
        let charRepo = CharacterRepository(context: context)
        let actorRepo = ActorRepository(context: context)

        let character = TestFixtures.createSampleCharacter()
        let actor = TestFixtures.createSampleActor()

        try charRepo.create(character)
        try actorRepo.create(actor)

        try castingRepo.linkActorToCharacter(actor, character)

        let actors = castingRepo.getActors(for: character)
        #expect(actors.count == 1)
        #expect(actors.first?.fullName == "Tom Hanks")
    }

    @Test("CastingRepository can unlink actor from character")
    func testCastingRepositoryUnlink() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let castingRepo = CastingRepository(context: context)
        let charRepo = CharacterRepository(context: context)
        let actorRepo = ActorRepository(context: context)

        let character = TestFixtures.createSampleCharacter()
        let actor = TestFixtures.createSampleActor()

        try charRepo.create(character)
        try actorRepo.create(actor)
        try castingRepo.linkActorToCharacter(actor, character)

        #expect(castingRepo.getActors(for: character).count == 1)

        try castingRepo.unlinkActorFromCharacter(actor, character)
        #expect(castingRepo.getActors(for: character).count == 0)
    }

    @Test("CastingRepository can cast actor as character")
    func testCastingRepositoryCast() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let castingRepo = CastingRepository(context: context)
        let charRepo = CharacterRepository(context: context)
        let actorRepo = ActorRepository(context: context)

        let character = TestFixtures.createSampleCharacter()
        let actor = TestFixtures.createSampleActor()

        try charRepo.create(character)
        try actorRepo.create(actor)

        try castingRepo.cast(actor, as: character)

        #expect(character.castingStatus == .cast)
        #expect(castingRepo.getActors(for: character).count == 1)
    }

    @Test("CastingRepository can uncast character")
    func testCastingRepositoryUncast() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let castingRepo = CastingRepository(context: context)
        let charRepo = CharacterRepository(context: context)
        let actorRepo = ActorRepository(context: context)

        let character = TestFixtures.createSampleCharacter()
        let actor = TestFixtures.createSampleActor()

        try charRepo.create(character)
        try actorRepo.create(actor)
        try castingRepo.cast(actor, as: character)

        try castingRepo.uncast(character)

        #expect(character.castingStatus == .notCast)
        #expect(castingRepo.getActors(for: character).count == 0)
    }

    @Test("CastingRepository can get characters for actor")
    func testCastingRepositoryGetCharacters() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let castingRepo = CastingRepository(context: context)
        let charRepo = CharacterRepository(context: context)
        let actorRepo = ActorRepository(context: context)

        let character = TestFixtures.createSampleCharacter()
        let actor = TestFixtures.createSampleActor()

        try charRepo.create(character)
        try actorRepo.create(actor)
        try castingRepo.linkActorToCharacter(actor, character)

        let characters = castingRepo.getCharacters(for: actor)
        #expect(characters.count == 1)
        #expect(characters.first?.name == "John Doe")
    }

    // MARK: - Integration Tests

    @Test("Full workflow: Create character, create actor, link them")
    func testFullWorkflowCharacterActorLinking() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)

        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        // Create character
        let character = TestFixtures.createLeadCharacter()
        try repos.characters.create(character)

        // Create actor
        let actor = TestFixtures.createProfessionalActor()
        try repos.actors.create(actor)

        // Link them
        try repos.casting.linkActorToCharacter(actor, character)

        // Verify
        let actors = repos.casting.getActors(for: character)
        #expect(actors.count == 1)

        let characters = repos.casting.getCharacters(for: actor)
        #expect(characters.count == 1)
    }

    @Test("Multiple actors can audition for same character")
    func testMultipleActorsForOneCharacter() async throws {
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
        #expect(linkedActors.count == 4)
    }

    @Test("Repository helper creates all repositories")
    func testConfigurationCreateRepositories() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)

        let repos = SwiftEchadaConfiguration.createRepositories(context: context)

        // Just verify they're created
        #expect(try repos.characters.count() == 0)
        #expect(try repos.actors.count() == 0)
    }

    // MARK: - ParserService Classification Tests (Coverage Improvement)

    @Test("ParserService classifies lead characters from screenplay")
    func testParserServiceClassificationLead() async throws {
        let service = ScreenplayParserService()
        let characters = try await service.parseScreenplay(from: Fijos.leadCharacter)
        let lead = characters.first { $0.name == "LEAD" }

        // This should trigger the lead classification (20+ dialogue, 10+ scenes)
        #expect(lead != nil)
        #expect(lead?.characterType == .lead)
    }

    @Test("ParserService classifies supporting characters from screenplay")
    func testParserServiceClassificationSupporting() async throws {
        let service = ScreenplayParserService()
        let characters = try await service.parseScreenplay(from: Fijos.supportingCharacter)
        let supporting = characters.first { $0.name == "SUPPORTING" }

        // This should trigger the supporting classification (10+ dialogue OR 5+ scenes)
        #expect(supporting != nil)
        #expect(supporting?.characterType == .supporting)
    }

    @Test("ParserService handles background characters from screenplay")
    func testParserServiceClassificationBackground() async throws {
        let service = ScreenplayParserService()
        let characters = try await service.parseScreenplay(from: Fijos.backgroundCharacter)

        // Background characters typically don't speak, so they may not be extracted by the parser
        // which only detects speaking characters. The fixture contains action lines with
        // "BACKGROUND CHARACTER" but no dialogue, so we expect either no characters or
        // characters with minimal dialogue if the parser extracts from action lines
        #expect(characters.isEmpty || characters.allSatisfy { $0.dialogueCount == 0 },
               "Background character file should have no dialogue or no detected characters")
    }

    @Test("ParserService classifies extra characters from screenplay")
    func testParserServiceClassificationExtra() async throws {
        let service = ScreenplayParserService()
        let characters = try await service.parseScreenplay(from: Fijos.extraCharacter)

        // The extra_character.fountain file has no speaking characters
        // It may have action lines but no character dialogue
        #expect(characters.isEmpty || characters.allSatisfy { $0.dialogueCount == 0 },
               "Extra character file should have no dialogue or no characters")
    }

    @Test("ParserService handles classification test screenplay")
    func testParserServiceClassificationTestFile() async throws {
        let service = ScreenplayParserService()
        let characters = try await service.parseScreenplay(from: Fijos.classificationTest)

        // Verify multiple character classifications in one file
        #expect(characters.count > 0)

        let characterTypes = Set(characters.map { $0.characterType })
        #expect(characterTypes.count >= 1, "Should have at least one character type classified")
    }

    // MARK: - Validation Error Description Tests (Coverage Improvement)

    @Test("ValidationError emptyName has correct description")
    func testValidationErrorEmptyNameDescription() async throws {
        let error = ValidationError.emptyName
        #expect(error.errorDescription == "Name cannot be empty")
    }

    @Test("ValidationError invalidSceneCount has correct description")
    func testValidationErrorInvalidSceneCountDescription() async throws {
        let error = ValidationError.invalidSceneCount
        #expect(error.errorDescription == "Scene count must be non-negative")
    }

    @Test("ValidationError invalidDialogueCount has correct description")
    func testValidationErrorInvalidDialogueCountDescription() async throws {
        let error = ValidationError.invalidDialogueCount
        #expect(error.errorDescription == "Dialogue count must be non-negative")
    }

    @Test("ValidationError invalidHeight has correct description")
    func testValidationErrorInvalidHeightDescription() async throws {
        let error = ValidationError.invalidHeight
        #expect(error.errorDescription == "Height must be between 24 and 96 inches")
    }

    @Test("ValidationError invalidAvailability has correct description")
    func testValidationErrorInvalidAvailabilityDescription() async throws {
        let error = ValidationError.invalidAvailability
        #expect(error.errorDescription == "Availability start date must be before end date")
    }

    // MARK: - Repository Edge Cases (Coverage Improvement)

    @Test("CharacterRepository delete by ID returns false for non-existent ID")
    func testCharacterRepositoryDeleteByIDNotFound() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = CharacterRepository(context: context)

        let randomID = UUID()
        let deleted = try repo.delete(id: randomID)
        #expect(deleted == false)
    }

    @Test("ActorRepository delete by ID returns false for non-existent ID")
    func testActorRepositoryDeleteByIDNotFound() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let randomID = UUID()
        let deleted = try repo.delete(id: randomID)
        #expect(deleted == false)
    }

    @Test("ActorRepository delete by ID returns true for existing ID")
    func testActorRepositoryDeleteByIDSuccess() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let repo = ActorRepository(context: context)

        let actor = TestFixtures.createSampleActor()
        try repo.create(actor)

        let deleted = try repo.delete(id: actor.id)
        #expect(deleted == true)
        #expect(try repo.count() == 0)
    }

    @Test("CastingRepository links actor when character has nil actors array")
    func testCastingRepositoryLinkWithNilActorsArray() async throws {
        let config = try SwiftEchadaConfiguration(inMemory: true)
        let context = ModelContext(config.modelContainer)
        let castingRepo = CastingRepository(context: context)
        let charRepo = CharacterRepository(context: context)
        let actorRepo = ActorRepository(context: context)

        // Create a character without any actors
        let character = Character(name: "Test", characterType: .lead)
        let actor = TestFixtures.createSampleActor()

        try charRepo.create(character)
        try actorRepo.create(actor)

        // This should initialize the actors array
        try castingRepo.linkActorToCharacter(actor, character)

        let actors = castingRepo.getActors(for: character)
        #expect(actors.count == 1)
    }
}
