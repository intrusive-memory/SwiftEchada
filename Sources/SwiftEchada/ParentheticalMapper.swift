import Foundation

/// Maps screenplay parentheticals (e.g. "(whispering)", "(angrily)") to TTS instruct strings,
/// or returns `nil` for parentheticals that should block speech generation.
public struct ParentheticalMapper: Sendable {

    public init() {}

    /// Map a parenthetical to a TTS instruct string.
    ///
    /// - Parameters:
    ///   - parenthetical: The parenthetical text (with or without surrounding parens).
    ///   - queryFn: Optional LLM fallback for unmapped parentheticals.
    /// - Returns: A TTS instruct string, or `nil` if the parenthetical should block generation
    ///   (e.g. "(beat)" or "(silence)").
    public func map(
        _ parenthetical: String,
        queryFn: (@Sendable (String, String) async throws -> String)? = nil
    ) async -> String? {
        let normalized = parenthetical
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            .lowercased()
            .trimmingCharacters(in: .whitespaces)

        // Check blocking parentheticals first
        if Self.blockingParentheticals.contains(normalized) {
            return nil
        }

        // Check static lookup
        if let instruct = Self.staticMappings[normalized] {
            return instruct
        }

        // LLM fallback
        if let queryFn {
            return await llmFallback(normalized, queryFn: queryFn)
        }

        // No mapping found, return generic instruct
        return "speak \(normalized)"
    }

    // MARK: - Static Mappings

    /// Parentheticals that should block speech generation (produce silence).
    static let blockingParentheticals: Set<String> = [
        "beat", "pause", "silence", "long pause", "a beat",
        "long beat", "stunned silence", "dead silence",
    ]

    /// Static parenthetical → TTS instruct mappings.
    static let staticMappings: [String: String] = [
        // Emotion
        "angrily": "speak angrily with intensity",
        "angry": "speak angrily with intensity",
        "sadly": "speak with sadness and sorrow",
        "sad": "speak with sadness and sorrow",
        "happily": "speak with happiness and joy",
        "happy": "speak with happiness and joy",
        "excited": "speak with excitement and energy",
        "excitedly": "speak with excitement and energy",
        "fearful": "speak with fear and trembling",
        "fearfully": "speak with fear and trembling",
        "scared": "speak with fear and trembling",
        "nervous": "speak nervously with hesitation",
        "nervously": "speak nervously with hesitation",
        "confused": "speak with confusion and uncertainty",
        "surprised": "speak with surprise",
        "shocked": "speak with shock and disbelief",
        "disgusted": "speak with disgust",
        "frustrated": "speak with frustration",
        "desperate": "speak desperately with urgency",
        "desperately": "speak desperately with urgency",
        "relieved": "speak with relief",
        "bitter": "speak with bitterness",
        "bitterly": "speak with bitterness",
        "amused": "speak with amusement",
        "sarcastic": "speak with sarcasm",
        "sarcastically": "speak with sarcasm",
        "ironic": "speak with irony",
        "ironically": "speak with irony",
        "wistful": "speak wistfully with nostalgia",
        "wistfully": "speak wistfully with nostalgia",
        "tender": "speak tenderly with warmth",
        "tenderly": "speak tenderly with warmth",
        "resigned": "speak with resignation",

        // Volume / Delivery
        "whispering": "speak in a whisper",
        "whisper": "speak in a whisper",
        "quietly": "speak quietly",
        "softly": "speak softly",
        "sotto voce": "speak in a low whisper",
        "shouting": "speak loudly as if shouting",
        "yelling": "speak loudly as if yelling",
        "screaming": "speak loudly as if screaming",
        "loud": "speak loudly",
        "loudly": "speak loudly",
        "muttering": "speak in a low mutter",
        "mumbling": "speak in a low mumble",
        "under breath": "speak quietly under breath",
        "under his breath": "speak quietly under breath",
        "under her breath": "speak quietly under breath",

        // Pacing
        "slowly": "speak slowly with deliberate pacing",
        "quickly": "speak quickly with urgency",
        "rushed": "speak quickly as if rushed",
        "hesitant": "speak with hesitation",
        "hesitantly": "speak with hesitation",
        "stammering": "speak with a stammer",
        "stuttering": "speak with a stutter",

        // Tone
        "cold": "speak coldly",
        "coldly": "speak coldly",
        "warm": "speak warmly",
        "warmly": "speak warmly",
        "flat": "speak in a flat monotone",
        "deadpan": "speak in a deadpan monotone",
        "dry": "speak dryly",
        "dryly": "speak dryly",
        "matter of fact": "speak in a matter-of-fact tone",
        "stern": "speak sternly",
        "sternly": "speak sternly",
        "firm": "speak firmly",
        "firmly": "speak firmly",
        "gentle": "speak gently",
        "gently": "speak gently",
        "threatening": "speak in a threatening tone",
        "menacing": "speak menacingly",
        "pleading": "speak pleadingly",
        "begging": "speak as if begging",
        "mocking": "speak mockingly",

        // Physical state
        "crying": "speak while crying",
        "in tears": "speak while crying",
        "through tears": "speak while crying",
        "laughing": "speak while laughing",
        "choked up": "speak as if choked up with emotion",
        "breathless": "speak breathlessly",
        "out of breath": "speak as if out of breath",
        "exhausted": "speak with exhaustion",
        "drunk": "speak as if intoxicated",
        "sleepy": "speak drowsily",
        "drowsy": "speak drowsily",
        "waking up": "speak groggily as if just waking up",

        // Direction
        "to herself": "speak as if talking to oneself",
        "to himself": "speak as if talking to oneself",
        "to self": "speak as if talking to oneself",
        "aside": "speak as an aside",
        "reading": "speak as if reading aloud",
        "reciting": "speak as if reciting from memory",
        "on phone": "speak as if on the phone",
        "into phone": "speak as if on the phone",
        "v.o.": "speak as a voice-over narration",
        "voice over": "speak as a voice-over narration",
        "o.s.": "speak as if from off-screen",
        "off-screen": "speak as if from off-screen",

        // Continuation
        "continuing": "continue speaking naturally",
        "cont'd": "continue speaking naturally",
    ]

    // MARK: - LLM Fallback

    private func llmFallback(
        _ parenthetical: String,
        queryFn: @Sendable (String, String) async throws -> String
    ) async -> String? {
        let systemPrompt = """
            You are a TTS direction translator. Given a screenplay parenthetical, \
            produce a short TTS instruct string that describes how the line should be delivered. \
            If the parenthetical indicates silence or a non-verbal action (no speech), respond with "BLOCK". \
            Otherwise, respond with a short instruction starting with "speak" (e.g. "speak wearily"). \
            Return ONLY the instruction, nothing else.
            """

        let userPrompt = "Parenthetical: (\(parenthetical))"

        do {
            let response = try await queryFn(userPrompt, systemPrompt)
            let result = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if result.uppercased() == "BLOCK" {
                return nil
            }
            return result.isEmpty ? "speak \(parenthetical)" : result
        } catch {
            return "speak \(parenthetical)"
        }
    }
}
