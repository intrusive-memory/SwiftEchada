import SwiftProyecto

/// Merges extracted character lists from multiple screenplay files into a unified cast list.
public struct CharacterMerger: Sendable {

    public init() {}

    /// Merge extracted character arrays with an optional existing cast.
    ///
    /// - Parameters:
    ///   - extracted: Character lists from each screenplay file.
    ///   - existingCast: Existing cast from PROJECT.md (may contain voice assignments).
    /// - Returns: Unified, deduplicated, alphabetically sorted cast list.
    public func merge(
        extracted: [[CharacterInfo]],
        existingCast: [CastMember]?
    ) -> [CastMember] {
        // Build a lookup of existing cast by normalised name
        var existingByName: [String: CastMember] = [:]
        if let existingCast {
            for member in existingCast {
                existingByName[member.character.lowercased().trimmingCharacters(in: .whitespaces)] = member
            }
        }

        // Collect unique character names (first occurrence keeps description)
        var seen: [String: CharacterInfo] = [:]
        var order: [String] = []

        for list in extracted {
            for character in list {
                let key = character.name.lowercased().trimmingCharacters(in: .whitespaces)
                guard !key.isEmpty else { continue }
                if seen[key] == nil {
                    seen[key] = character
                    order.append(key)
                }
            }
        }

        // Build cast members, preserving existing voice/actor data
        var result: [CastMember] = []
        for key in order {
            guard let info = seen[key] else { continue }
            if let existing = existingByName[key] {
                result.append(existing)
            } else {
                result.append(CastMember(
                    character: info.name,
                    actor: nil,
                    voices: []
                ))
            }
        }

        // Also include any existing cast members not found in extracted files
        for (key, member) in existingByName where seen[key] == nil {
            result.append(member)
        }

        // Sort alphabetically by character name
        result.sort { $0.character.localizedCaseInsensitiveCompare($1.character) == .orderedAscending }

        return result
    }
}
