import Foundation
import SwiftProyecto

/// Enriches cast members that are missing voice descriptions by querying a local LLM.
///
/// Pass 1 of the `echada cast` pipeline: generates voice descriptions for characters
/// that don't already have one, using character name, genre, and optional actor hints.
public struct VoiceDescriptionEnricher: Sendable {

    /// Result of an enrichment operation.
    public struct EnrichResult: Sendable {
        public let updatedCast: [CastMember]
        public let enrichedCount: Int
        public let skippedCount: Int
    }

    public init() {}

    /// Enrich cast members that are missing voice descriptions.
    ///
    /// - Parameters:
    ///   - cast: The current cast list.
    ///   - genre: The project genre (used as context for the LLM).
    ///   - queryFn: A function that takes (userPrompt, systemPrompt) and returns the LLM response.
    ///   - verbose: Whether to print debug output.
    /// - Returns: An `EnrichResult` with updated cast and counts.
    public func enrich(
        cast: [CastMember],
        genre: String?,
        queryFn: @escaping @Sendable (String, String) async throws -> String,
        verbose: Bool = false
    ) async -> EnrichResult {
        var updatedCast = cast
        var enrichedCount = 0
        var skippedCount = 0

        let systemPrompt = buildSystemPrompt(genre: genre)

        for (index, member) in cast.enumerated() {
            if let desc = member.voiceDescription, !desc.isEmpty {
                if verbose {
                    print("[verbose] Skipping \(member.character) — already has voice description")
                }
                continue
            }

            let userPrompt = buildUserPrompt(member: member, genre: genre)

            if verbose {
                print("[verbose] --- Enriching: \(member.character) ---")
                print("[verbose] User prompt:\n\(userPrompt)")
            }

            do {
                let response = try await queryFn(userPrompt, systemPrompt)
                let description = response.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !description.isEmpty else {
                    if verbose {
                        print("[verbose] Empty response for \(member.character), skipping")
                    }
                    skippedCount += 1
                    continue
                }

                if verbose {
                    print("[verbose] Description: \(description)")
                }

                updatedCast[index] = CastMember(
                    character: member.character,
                    actor: member.actor,
                    gender: member.gender,
                    voiceDescription: description,
                    voices: member.voices
                )
                enrichedCount += 1
            } catch {
                if verbose {
                    print("[verbose] Error enriching \(member.character): \(error)")
                }
                skippedCount += 1
            }
        }

        return EnrichResult(
            updatedCast: updatedCast,
            enrichedCount: enrichedCount,
            skippedCount: skippedCount
        )
    }

    // MARK: - Private

    private func buildSystemPrompt(genre: String?) -> String {
        let genreLine = genre ?? "unspecified"
        return """
            You are a professional voice casting director for a \(genreLine) production. \
            Given a character, generate a concise voice description suitable for text-to-speech casting. \
            Include: vocal pitch (high/low), pace (fast/slow), tone (warm/gravelly/nasal/breathy), \
            age range, energy level, and emotional quality. \
            If an actor reference is provided, describe a voice inspired by that actor's vocal qualities. \
            Respond with ONLY the voice description text, nothing else. Keep it to 1-2 sentences.
            """
    }

    private func buildUserPrompt(member: CastMember, genre: String?) -> String {
        var lines: [String] = []
        lines.append("Character: \(member.character)")
        if let gender = member.gender {
            lines.append("Gender: \(gender.displayName)")
        }
        if let actor = member.actor, !actor.isEmpty {
            lines.append("Actor reference: \(actor)")
        }
        if let genre {
            lines.append("Genre: \(genre)")
        }
        lines.append("Generate a voice description for this character.")
        return lines.joined(separator: "\n")
    }
}

public enum VoiceDescriptionEnricherError: Error, CustomStringConvertible {
    case noCastMembers

    public var description: String {
        switch self {
        case .noCastMembers:
            "No cast members found in project"
        }
    }
}
