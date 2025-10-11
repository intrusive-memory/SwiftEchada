import Foundation
import SwiftData

// MARK: - Repository Protocol

/// Generic repository protocol for data access operations
public protocol Repository {
    associatedtype Entity

    func create(_ entity: Entity) throws
    func read(id: UUID) throws -> Entity?
    func readAll() throws -> [Entity]
    func update(_ entity: Entity) throws
    func delete(_ entity: Entity) throws
    func delete(id: UUID) throws -> Bool
}

// MARK: - Character Repository

/// Repository for Character CRUD operations
public final class CharacterRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Create

    /// Create a new character
    /// - Parameter character: The character to create
    /// - Throws: ValidationError if character is invalid
    public func create(_ character: Character) throws {
        try character.validate()
        context.insert(character)
        try context.save()
    }

    /// Create multiple characters in a batch
    /// - Parameter characters: Array of characters to create
    /// - Throws: ValidationError if any character is invalid
    public func createBatch(_ characters: [Character]) throws {
        for character in characters {
            try character.validate()
            context.insert(character)
        }
        try context.save()
    }

    // MARK: - Read

    /// Read a character by ID
    /// - Parameter id: The character's UUID
    /// - Returns: The character if found, nil otherwise
    public func read(id: UUID) throws -> Character? {
        let descriptor = FetchDescriptor<Character>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    /// Read all characters
    /// - Returns: Array of all characters
    public func readAll() throws -> [Character] {
        let descriptor = FetchDescriptor<Character>()
        return try context.fetch(descriptor)
    }

    /// Find characters by name (exact match)
    /// - Parameter name: Character name to search for
    /// - Returns: Array of matching characters
    public func findByName(_ name: String) throws -> [Character] {
        let descriptor = FetchDescriptor<Character>(
            predicate: #Predicate { $0.name == name }
        )
        return try context.fetch(descriptor)
    }

    /// Find characters by type
    /// - Parameter type: Character type to filter by
    /// - Returns: Array of characters of the specified type
    public func findByType(_ type: CharacterType) throws -> [Character] {
        // SwiftData doesn't support enum predicates, so we filter in memory
        let all = try readAll()
        return all.filter { $0.characterType == type }
    }

    /// Find characters by casting status
    /// - Parameter status: Casting status to filter by
    /// - Returns: Array of characters with the specified status
    public func findByCastingStatus(_ status: CastingStatus) throws -> [Character] {
        // SwiftData doesn't support enum predicates, so we filter in memory
        let all = try readAll()
        return all.filter { $0.castingStatus == status }
    }

    /// Find speaking characters (dialogue count > 0)
    /// - Returns: Array of characters with dialogue
    public func findSpeakingCharacters() throws -> [Character] {
        let descriptor = FetchDescriptor<Character>(
            predicate: #Predicate { $0.dialogueCount > 0 }
        )
        return try context.fetch(descriptor)
    }

    /// Find characters with minimum scene count
    /// - Parameter minScenes: Minimum number of scenes
    /// - Returns: Array of characters appearing in at least minScenes
    public func findByMinimumScenes(_ minScenes: Int) throws -> [Character] {
        let descriptor = FetchDescriptor<Character>(
            predicate: #Predicate { $0.totalScenes >= minScenes }
        )
        return try context.fetch(descriptor)
    }

    /// Search characters by name (contains)
    /// - Parameter searchTerm: Term to search for in character names
    /// - Returns: Array of matching characters
    public func search(name searchTerm: String) throws -> [Character] {
        let allCharacters = try readAll()
        return allCharacters.filter { character in
            character.name.localizedCaseInsensitiveContains(searchTerm) ||
            character.aliases.contains { $0.localizedCaseInsensitiveContains(searchTerm) }
        }
    }

    // MARK: - Update

    /// Update a character
    /// - Parameter character: The character to update
    /// - Throws: ValidationError if character is invalid
    public func update(_ character: Character) throws {
        try character.validate()
        character.touch()
        try context.save()
    }

    /// Update character casting status
    /// - Parameters:
    ///   - character: The character to update
    ///   - status: New casting status
    public func updateCastingStatus(_ character: Character, to status: CastingStatus) throws {
        character.castingStatus = status
        character.touch()
        try context.save()
    }

    // MARK: - Delete

    /// Delete a character
    /// - Parameter character: The character to delete
    public func delete(_ character: Character) throws {
        context.delete(character)
        try context.save()
    }

    /// Delete a character by ID
    /// - Parameter id: The character's UUID
    /// - Returns: True if character was deleted, false if not found
    public func delete(id: UUID) throws -> Bool {
        guard let character = try read(id: id) else {
            return false
        }
        try delete(character)
        return true
    }

    /// Delete all characters
    /// - Returns: Number of characters deleted
    @discardableResult
    public func deleteAll() throws -> Int {
        let characters = try readAll()
        for character in characters {
            context.delete(character)
        }
        try context.save()
        return characters.count
    }

    // MARK: - Statistics

    /// Get count of all characters
    /// - Returns: Total character count
    public func count() throws -> Int {
        return try readAll().count
    }

    /// Get count by type
    /// - Parameter type: Character type
    /// - Returns: Count of characters of that type
    public func count(ofType type: CharacterType) throws -> Int {
        return try findByType(type).count
    }

    /// Get count by casting status
    /// - Parameter status: Casting status
    /// - Returns: Count of characters with that status
    public func count(withStatus status: CastingStatus) throws -> Int {
        return try findByCastingStatus(status).count
    }
}

// MARK: - Actor Repository

/// Repository for Actor CRUD operations
public final class ActorRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Create

    /// Create a new actor
    /// - Parameter actor: The actor to create
    /// - Throws: ValidationError if actor is invalid
    public func create(_ actor: Actor) throws {
        try actor.validate()
        context.insert(actor)
        try context.save()
    }

    /// Create multiple actors in a batch
    /// - Parameter actors: Array of actors to create
    /// - Throws: ValidationError if any actor is invalid
    public func createBatch(_ actors: [Actor]) throws {
        for actor in actors {
            try actor.validate()
            context.insert(actor)
        }
        try context.save()
    }

    // MARK: - Read

    /// Read an actor by ID
    /// - Parameter id: The actor's UUID
    /// - Returns: The actor if found, nil otherwise
    public func read(id: UUID) throws -> Actor? {
        let descriptor = FetchDescriptor<Actor>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    /// Read all actors
    /// - Returns: Array of all actors
    public func readAll() throws -> [Actor] {
        let descriptor = FetchDescriptor<Actor>()
        return try context.fetch(descriptor)
    }

    /// Find actors by full name
    /// - Parameter name: Full name to search for
    /// - Returns: Array of matching actors
    public func findByFullName(_ name: String) throws -> [Actor] {
        let descriptor = FetchDescriptor<Actor>(
            predicate: #Predicate { $0.fullName == name }
        )
        return try context.fetch(descriptor)
    }

    /// Find actors by experience level
    /// - Parameter level: Experience level to filter by
    /// - Returns: Array of actors with the specified experience level
    public func findByExperienceLevel(_ level: ExperienceLevel) throws -> [Actor] {
        // SwiftData doesn't support enum predicates, so we filter in memory
        let all = try readAll()
        return all.filter { $0.experienceLevel == level }
    }

    /// Find actors by union status
    /// - Parameter status: Union status to search for
    /// - Returns: Array of actors with matching union status
    public func findByUnionStatus(_ status: String) throws -> [Actor] {
        let allActors = try readAll()
        return allActors.filter { $0.unionStatus == status }
    }

    /// Find available actors
    /// - Returns: Array of currently available actors
    public func findAvailableActors() throws -> [Actor] {
        let allActors = try readAll()
        return allActors.filter { $0.isAvailable }
    }

    /// Find actors by location
    /// - Parameter location: Location to search for
    /// - Returns: Array of actors in that location
    public func findByLocation(_ location: String) throws -> [Actor] {
        let allActors = try readAll()
        return allActors.filter { $0.location == location }
    }

    /// Find actors with specific skill
    /// - Parameter skill: Skill to search for
    /// - Returns: Array of actors with that skill
    public func findBySkill(_ skill: String) throws -> [Actor] {
        let allActors = try readAll()
        return allActors.filter { actor in
            actor.specialSkills.contains { $0.localizedCaseInsensitiveContains(skill) }
        }
    }

    /// Search actors by name (contains search in full name and stage name)
    /// - Parameter searchTerm: Term to search for
    /// - Returns: Array of matching actors
    public func search(name searchTerm: String) throws -> [Actor] {
        let allActors = try readAll()
        return allActors.filter { actor in
            actor.fullName.localizedCaseInsensitiveContains(searchTerm) ||
            (actor.stageName?.localizedCaseInsensitiveContains(searchTerm) ?? false)
        }
    }

    // MARK: - Update

    /// Update an actor
    /// - Parameter actor: The actor to update
    /// - Throws: ValidationError if actor is invalid
    public func update(_ actor: Actor) throws {
        try actor.validate()
        actor.touch()
        try context.save()
    }

    /// Update actor availability
    /// - Parameters:
    ///   - actor: The actor to update
    ///   - start: Availability start date
    ///   - end: Availability end date
    public func updateAvailability(_ actor: Actor, start: Date?, end: Date?) throws {
        actor.availabilityStart = start
        actor.availabilityEnd = end
        try actor.validate()
        actor.touch()
        try context.save()
    }

    // MARK: - Delete

    /// Delete an actor
    /// - Parameter actor: The actor to delete
    public func delete(_ actor: Actor) throws {
        context.delete(actor)
        try context.save()
    }

    /// Delete an actor by ID
    /// - Parameter id: The actor's UUID
    /// - Returns: True if actor was deleted, false if not found
    public func delete(id: UUID) throws -> Bool {
        guard let actor = try read(id: id) else {
            return false
        }
        try delete(actor)
        return true
    }

    /// Delete all actors
    /// - Returns: Number of actors deleted
    @discardableResult
    public func deleteAll() throws -> Int {
        let actors = try readAll()
        for actor in actors {
            context.delete(actor)
        }
        try context.save()
        return actors.count
    }

    // MARK: - Statistics

    /// Get count of all actors
    /// - Returns: Total actor count
    public func count() throws -> Int {
        return try readAll().count
    }

    /// Get count by experience level
    /// - Parameter level: Experience level
    /// - Returns: Count of actors with that experience level
    public func count(withExperience level: ExperienceLevel) throws -> Int {
        return try findByExperienceLevel(level).count
    }

    /// Get count of available actors
    /// - Returns: Count of currently available actors
    public func countAvailable() throws -> Int {
        return try findAvailableActors().count
    }

    // MARK: - Binary Data Import/Export

    /// Import photo from file URL and store as binary Data
    /// - Parameters:
    ///   - actor: The actor to update
    ///   - url: File URL of the image
    /// - Throws: Error if file cannot be read or actor validation fails
    public func importPhoto(for actor: Actor, from url: URL) throws {
        let imageData = try Data(contentsOf: url)

        // TODO: Add image compression in Phase 4
        // For now, store the data directly
        actor.photoData = imageData

        // TODO: Generate thumbnail in Phase 4
        actor.thumbnailData = imageData

        actor.touch()
        try context.save()
    }

    /// Export photo Data to file URL
    /// - Parameters:
    ///   - actor: The actor whose photo to export
    ///   - url: Destination file URL
    /// - Throws: Error if no photo data or write fails
    public func exportPhoto(for actor: Actor, to url: URL) throws {
        guard let photoData = actor.photoData else {
            throw BinaryDataError.noPhotoData
        }
        try photoData.write(to: url)
    }

    /// Import additional photos from file URLs
    /// - Parameters:
    ///   - actor: The actor to update
    ///   - urls: Array of file URLs
    /// - Throws: Error if any file cannot be read
    public func importAdditionalPhotos(for actor: Actor, from urls: [URL]) throws {
        var photosData: [Data] = []
        var thumbnailsData: [Data] = []

        for url in urls {
            let imageData = try Data(contentsOf: url)
            photosData.append(imageData)

            // TODO: Generate actual thumbnails in Phase 4
            thumbnailsData.append(imageData)
        }

        actor.additionalPhotosData = photosData
        actor.additionalThumbnailsData = thumbnailsData
        actor.touch()
        try context.save()
    }

    /// Export additional photos to directory
    /// - Parameters:
    ///   - actor: The actor whose photos to export
    ///   - directory: Directory URL to write files
    ///   - prefix: Filename prefix (default: actor's full name)
    /// - Returns: Array of written file URLs
    /// - Throws: Error if no photos or write fails
    @discardableResult
    public func exportAdditionalPhotos(
        for actor: Actor,
        to directory: URL,
        prefix: String? = nil
    ) throws -> [URL] {
        guard !actor.additionalPhotosData.isEmpty else {
            throw BinaryDataError.noAdditionalPhotos
        }

        let filePrefix = prefix ?? actor.fullName.replacingOccurrences(of: " ", with: "_")
        var writtenURLs: [URL] = []

        for (index, photoData) in actor.additionalPhotosData.enumerated() {
            let filename = "\(filePrefix)_\(index + 1).jpg"
            let fileURL = directory.appendingPathComponent(filename)
            try photoData.write(to: fileURL)
            writtenURLs.append(fileURL)
        }

        return writtenURLs
    }
}

// MARK: - Binary Data Errors

/// Errors related to binary data operations
public enum BinaryDataError: Error, LocalizedError {
    case noPhotoData
    case noAdditionalPhotos
    case invalidImageFormat
    case compressionFailed

    public var errorDescription: String? {
        switch self {
        case .noPhotoData:
            return "No photo data available for export"
        case .noAdditionalPhotos:
            return "No additional photos available for export"
        case .invalidImageFormat:
            return "Invalid image format"
        case .compressionFailed:
            return "Image compression failed"
        }
    }
}

// MARK: - Relationship Operations

/// Repository for managing Character-Actor relationships
public final class CastingRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    /// Link an actor to a character
    /// - Parameters:
    ///   - actor: The actor
    ///   - character: The character
    public func linkActorToCharacter(_ actor: Actor, _ character: Character) throws {
        if character.actors == nil {
            character.actors = []
        }
        if !character.actors!.contains(where: { $0.id == actor.id }) {
            character.actors!.append(actor)
        }
        character.touch()
        actor.touch()
        try context.save()
    }

    /// Unlink an actor from a character
    /// - Parameters:
    ///   - actor: The actor
    ///   - character: The character
    public func unlinkActorFromCharacter(_ actor: Actor, _ character: Character) throws {
        character.actors?.removeAll { $0.id == actor.id }
        character.touch()
        actor.touch()
        try context.save()
    }

    /// Get all actors for a character
    /// - Parameter character: The character
    /// - Returns: Array of actors linked to this character
    public func getActors(for character: Character) -> [Actor] {
        return character.actors ?? []
    }

    /// Get all characters for an actor
    /// - Parameter actor: The actor
    /// - Returns: Array of characters linked to this actor
    public func getCharacters(for actor: Actor) -> [Character] {
        return actor.characters ?? []
    }

    /// Cast an actor in a character role
    /// - Parameters:
    ///   - actor: The actor to cast
    ///   - character: The character role
    public func cast(_ actor: Actor, as character: Character) throws {
        try linkActorToCharacter(actor, character)
        character.castingStatus = .cast
        character.touch()
        try context.save()
    }

    /// Remove casting (uncast a character)
    /// - Parameter character: The character to uncast
    public func uncast(_ character: Character) throws {
        character.actors?.removeAll()
        character.castingStatus = .notCast
        character.touch()
        try context.save()
    }
}
