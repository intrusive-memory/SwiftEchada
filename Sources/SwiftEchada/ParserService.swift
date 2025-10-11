import Foundation
import SwiftData
import SwiftGuion

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
        // Simple heuristic - can be refined later
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
