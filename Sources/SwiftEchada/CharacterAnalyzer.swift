import Foundation
import SwiftProyecto

/// Analyzes a character's dialogue and context to build a detailed `CharacterProfile`
/// for voice design, using an LLM via injected query function.
public struct CharacterAnalyzer: Sendable {

    public init() {}

    /// Analyze a cast member and produce a `CharacterProfile`.
    ///
    /// - Parameters:
    ///   - member: The cast member to analyze.
    ///   - queryFn: LLM query function `(userPrompt, systemPrompt) -> response`.
    ///   - verbose: Whether to print debug output.
    /// - Returns: A `CharacterProfile` for voice design.
    public func analyze(
        member: CastMember,
        queryFn: @escaping @Sendable (String, String) async throws -> String,
        verbose: Bool = false
    ) async throws -> CharacterProfile {
        let description = member.voiceDescription ?? member.character

        let systemPrompt = """
            You are a voice profile analyzer. Given a character and voice description, \
            return a JSON object with these exact fields:
            {
              "name": "CHARACTER NAME (uppercase)",
              "gender": "male" or "female" or "nonBinary" or "notSpecified",
              "ageRange": "e.g. 30s, elderly, young adult",
              "description": "the full voice description",
              "voiceTraits": ["trait1", "trait2"],
              "summary": "concise 1-sentence summary for voice synthesis"
            }
            Return ONLY the JSON object, nothing else.
            """

        let userPrompt = """
            Character: \(member.character)
            Gender: \(member.gender?.displayName ?? "not specified")
            Voice description: \(description)
            """

        do {
            let response = try await queryFn(userPrompt, systemPrompt)
            if let profile = parseProfile(from: response) {
                return profile
            }
            if verbose {
                print("[verbose] JSON parse failed for \(member.character), using heuristic fallback")
            }
        } catch {
            if verbose {
                print("[verbose] LLM query failed for \(member.character): \(error)")
            }
        }

        // Heuristic fallback
        return CharacterProfile(
            name: member.character.uppercased(),
            gender: member.gender ?? .notSpecified,
            ageRange: "adult",
            description: description,
            voiceTraits: description.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty },
            summary: description
        )
    }

    // MARK: - Private

    private func parseProfile(from response: String) -> CharacterProfile? {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        let jsonString: String
        if let start = trimmed.range(of: "{"),
           let end = trimmed.range(of: "}", options: .backwards) {
            jsonString = String(trimmed[start.lowerBound...end.lowerBound])
        } else {
            jsonString = trimmed
        }

        guard let data = jsonString.data(using: .utf8) else { return nil }

        struct ProfileJSON: Decodable {
            let name: String
            let gender: String
            let ageRange: String
            let description: String
            let voiceTraits: [String]
            let summary: String
        }

        guard let parsed = try? JSONDecoder().decode(ProfileJSON.self, from: data) else {
            return nil
        }

        let gender: Gender
        switch parsed.gender.lowercased() {
        case "male": gender = .male
        case "female": gender = .female
        case "nonbinary": gender = .nonBinary
        default: gender = .notSpecified
        }

        return CharacterProfile(
            name: parsed.name,
            gender: gender,
            ageRange: parsed.ageRange,
            description: parsed.description,
            voiceTraits: parsed.voiceTraits,
            summary: parsed.summary
        )
    }
}
