import SwiftReparto

/// Merges extracted character lists from multiple screenplay files into a unified cast list.
public struct CharacterMerger: Sendable {

  public init() {}

  /// Merge extracted character arrays with an optional existing cast.
  ///
  /// - Parameters:
  ///   - extracted: Character lists from each screenplay file.
  ///   - existingCast: Existing roster (from CAST.md; may contain voice assignments).
  /// - Returns: Unified, deduplicated, alphabetically sorted cast list.
  public func merge(
    extracted: [[CharacterInfo]],
    existingCast: [CastMember]?
  ) -> [CastMember] {
    // Discovery half (stays here): dedupe the per-file character lists into
    // candidate cast members. First occurrence of a name (case- and
    // whitespace-insensitively) wins and keeps its spelling and description.
    var seen: Set<String> = []
    var candidates: [CastMember] = []

    for list in extracted {
      for character in list {
        let key = character.name.lowercased().trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !seen.contains(key) else { continue }
        seen.insert(key)
        candidates.append(
          CastMember(
            character: character.name,
            actor: nil,
            gender: nil,
            voicePrompt: character.voiceDescription,
            voices: [:]
          ))
      }
    }

    // Reconciliation half: delegate to SwiftReparto's additive merge (RQ-14).
    // Existing members keep every field they already have, new members are
    // appended, and the existing roster is never pruned.
    var result = (existingCast ?? []).merging(candidates)

    // Sort alphabetically by character name
    result.sort { $0.character.localizedCaseInsensitiveCompare($1.character) == .orderedAscending }

    return result
  }
}
