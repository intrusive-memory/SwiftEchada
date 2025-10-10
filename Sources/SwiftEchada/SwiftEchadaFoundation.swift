import Foundation
import SwiftData
import SwiftGuion

// MARK: - SwiftData Models

/// Represents a character from a screenplay
@Model
public final class Character {
    /// Unique identifier for the character
    @Attribute(.unique) public var id: UUID

    /// Character's name as it appears in the screenplay
    public var name: String

    /// Alternative names or nicknames
    public var aliases: [String]

    /// When the character was created/imported
    public var createdAt: Date

    /// When the character was last modified
    public var updatedAt: Date

    /// Character's age or age range (optional)
    public var age: String?

    /// Character's gender identity (optional)
    public var gender: String?

    /// Physical description (optional)
    public var physicalDescription: String?

    /// Scene number where character first appears (optional)
    public var firstAppearance: String?

    /// Scene number where character last appears (optional)
    public var lastAppearance: String?

    /// Total number of scenes featuring this character
    public var totalScenes: Int

    /// Count of dialogue lines
    public var dialogueCount: Int

    /// Character type (Lead, Supporting, Featured, Background, Extra)
    public var characterType: CharacterType

    public init(
        id: UUID = UUID(),
        name: String,
        aliases: [String] = [],
        age: String? = nil,
        gender: String? = nil,
        physicalDescription: String? = nil,
        firstAppearance: String? = nil,
        lastAppearance: String? = nil,
        totalScenes: Int = 0,
        dialogueCount: Int = 0,
        characterType: CharacterType = .featured
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.createdAt = Date()
        self.updatedAt = Date()
        self.age = age
        self.gender = gender
        self.physicalDescription = physicalDescription
        self.firstAppearance = firstAppearance
        self.lastAppearance = lastAppearance
        self.totalScenes = totalScenes
        self.dialogueCount = dialogueCount
        self.characterType = characterType
    }
}

/// Character type classification
public enum CharacterType: String, Codable {
    case lead
    case supporting
    case featured
    case background
    case extra
}

// MARK: - SwiftGuion Integration

/// Service for parsing screenplays and extracting character information
public final class ScreenplayParserService {

    public init() {}

    /// Parse a Fountain format screenplay and extract characters
    /// - Parameter url: URL to the fountain file
    /// - Returns: Array of Character objects extracted from the screenplay
    /// - Throws: Error if file cannot be read or parsed
    public func parseScreenplay(from url: URL) async throws -> [Character] {
        // Read the fountain file
        let content = try String(contentsOf: url, encoding: .utf8)

        // Parse using SwiftGuion
        let script = try FountainScript(string: content)

        // Extract character information
        let characterList = script.extractCharacters()

        // Convert to our Character models
        var characters: [Character] = []

        for (characterName, info) in characterList {
            let character = Character(
                name: characterName,
                totalScenes: info.scenes.count,
                dialogueCount: info.counts.lineCount,
                characterType: classifyCharacterType(sceneCount: info.scenes.count, dialogueCount: info.counts.lineCount)
            )
            characters.append(character)
        }

        return characters
    }

    /// Classify character type based on their presence in the script
    /// - Parameters:
    ///   - sceneCount: Number of scenes the character appears in
    ///   - dialogueCount: Number of dialogue lines
    /// - Returns: CharacterType classification
    private func classifyCharacterType(sceneCount: Int, dialogueCount: Int) -> CharacterType {
        // Simple heuristic for Phase 0 - can be refined later
        if dialogueCount >= 20 && sceneCount >= 10 {
            return .lead
        } else if dialogueCount >= 10 || sceneCount >= 5 {
            return .supporting
        } else if dialogueCount > 0 {
            return .featured
        } else if sceneCount > 0 {
            return .background
        } else {
            return .extra
        }
    }
}

// MARK: - SwiftData Configuration

/// Configuration for SwiftData persistent storage
public struct SwiftEchadaConfiguration {
    /// The model container for SwiftData
    public let modelContainer: ModelContainer

    /// Create a new configuration with default settings
    /// - Parameter inMemory: If true, uses in-memory storage (useful for testing)
    /// - Throws: Error if container cannot be created
    public init(inMemory: Bool = false) throws {
        let schema = Schema([
            Character.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
}
