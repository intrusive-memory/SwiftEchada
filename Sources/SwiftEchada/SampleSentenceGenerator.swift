import Foundation

/// Generates a sample sentence in a character's voice, suitable for TTS voice design auditions.
public struct SampleSentenceGenerator: Sendable {

    public init() {}

    /// Generate a sample sentence from a `CharacterProfile`.
    ///
    /// - Parameters:
    ///   - profile: The character profile to generate a sentence for.
    ///   - queryFn: LLM query function `(userPrompt, systemPrompt) -> response`.
    /// - Returns: A sample sentence in the character's voice.
    public func generate(
        from profile: CharacterProfile,
        queryFn: @escaping @Sendable (String, String) async throws -> String
    ) async throws -> String {
        let traits = profile.voiceTraits.joined(separator: ", ")
        return try await generate(
            characterName: profile.name,
            description: "\(profile.summary). Traits: \(traits). Age: \(profile.ageRange).",
            queryFn: queryFn
        )
    }

    /// Generate a sample sentence from a freeform description.
    ///
    /// - Parameters:
    ///   - characterName: The character name.
    ///   - description: A freeform voice/character description.
    ///   - queryFn: LLM query function `(userPrompt, systemPrompt) -> response`.
    /// - Returns: A sample sentence in the character's voice.
    public func generate(
        characterName: String,
        description: String,
        queryFn: @escaping @Sendable (String, String) async throws -> String
    ) async throws -> String {
        let systemPrompt = """
            You are a voice audition writer. Given a character and their voice description, \
            write a single sentence (15-30 words) that the character would naturally say. \
            The sentence should showcase the character's vocal qualities and personality. \
            Do NOT include stage directions, quotes, or the character's name prefix. \
            Return ONLY the sentence text, nothing else.
            """

        let userPrompt = """
            Character: \(characterName)
            Description: \(description)
            Write a sample sentence this character would say.
            """

        let response = try await queryFn(userPrompt, systemPrompt)
        let sentence = response.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

        guard !sentence.isEmpty else {
            return Self.defaultSentence(for: characterName)
        }

        return sentence
    }

    /// Fallback sentence when LLM generation fails.
    public static func defaultSentence(for characterName: String) -> String {
        "Hello, my name is \(characterName). This is a preview of how my voice will sound."
    }
}
