import Foundation

/// Generates a sample sentence for TTS voice design auditions.
///
/// Returns a randomly selected quote from Dorothy Parker and Fran Lebowitz.
public struct SampleSentenceGenerator: Sendable {

    /// Curated quotes suitable for TTS voice auditions (15-30 words each).
    public static let quotes: [String] = [
        // Dorothy Parker
        "The cure for boredom is curiosity, and there is absolutely no cure for curiosity.",
        "I don't care what is written about me so long as it isn't true.",
        "If you want to know what God thinks of money, just look at the people he gave it to.",
        "The first thing I do in the morning is brush my teeth and sharpen my tongue.",
        "You can lead a horticulture, but you can't make her think.",
        "I require three things in a man: he must be handsome, ruthless, and stupid.",
        "Take care of the luxuries and the necessities will take care of themselves.",
        "That woman speaks eighteen languages, and she can't say no in any of them.",
        "I'd rather have a bottle in front of me than a frontal lobotomy.",
        "Tell him I was too busy, or vice versa.",
        // Fran Lebowitz
        "Think before you speak. Read before you think.",
        "Great people talk about ideas, average people talk about things, and small people talk about wine.",
        "There is no such thing as inner peace. There is only nervousness or death.",
        "My favorite animal is steak.",
        "The opposite of talking isn't listening. The opposite of talking is waiting.",
        "Being a woman is of special interest only to aspiring male transsexuals. To actual women it is simply a good excuse not to play football.",
        "In real life, I assure you, there is no such thing as algebra.",
        "Nature is by and large to be found out of doors, a location where, it cannot be argued, there are never enough comfortable chairs.",
        "Life is something that happens when you can't get to sleep.",
        "Ask your child what he wants for dinner only if he's buying.",
    ]

    /// Returns a randomly selected quote.
    public static func randomQuote() -> String {
        quotes.randomElement()!
    }

    public init() {}

    /// Generate a sample sentence from a `CharacterProfile`.
    ///
    /// - Parameters:
    ///   - profile: The character profile to generate a sentence for.
    ///   - queryFn: LLM query function (ignored — a random quote is returned).
    /// - Returns: A random quote suitable for voice audition.
    public func generate(
        from profile: CharacterProfile,
        queryFn: @escaping @Sendable (String, String) async throws -> String
    ) async throws -> String {
        Self.randomQuote()
    }

    /// Generate a sample sentence from a freeform description.
    ///
    /// - Parameters:
    ///   - characterName: The character name (ignored).
    ///   - description: A freeform voice/character description (ignored).
    ///   - queryFn: LLM query function (ignored — a random quote is returned).
    /// - Returns: A random quote suitable for voice audition.
    public func generate(
        characterName: String,
        description: String,
        queryFn: @escaping @Sendable (String, String) async throws -> String
    ) async throws -> String {
        Self.randomQuote()
    }

    /// Returns a random quote (characterName is ignored).
    public static func defaultSentence(for characterName: String) -> String {
        randomQuote()
    }
}
