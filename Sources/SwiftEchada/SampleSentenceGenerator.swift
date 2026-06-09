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

  /// Curated Spanish quotes suitable for TTS voice auditions.
  ///
  /// Public-domain sources: Cervantes' *Don Quijote* and traditional Spanish
  /// proverbs (refranes). A same-language reference sentence yields a cleaner
  /// clone-prompt extraction than an English sentence spoken by a Spanish voice.
  public static let quotesES: [String] = [
    "En un lugar de la Mancha, de cuyo nombre no quiero acordarme, no ha mucho tiempo que vivía un hidalgo de los de lanza en astillero.",
    "La libertad, Sancho, es uno de los más preciosos dones que a los hombres dieron los cielos.",
    "Cada uno es artífice de su propia ventura, y bien podría serlo de su propia desdicha si así lo quisiera.",
    "No por mucho madrugar amanece más temprano, aunque siempre conviene levantarse con ánimo y empezar el día con buen pie.",
    "Más vale pájaro en mano que ciento volando, porque lo seguro siempre pesa más que la promesa de lo incierto.",
    "Dime con quién andas y te diré quién eres, pues las compañías que elegimos terminan por revelar nuestro verdadero carácter.",
    "No hay mal que por bien no venga, y a veces la peor de las noticias esconde la semilla de una alegría futura.",
    "Quien mucho abarca poco aprieta, así que conviene escoger pocas batallas y librarlas todas con verdadera dedicación.",
    "El que ríe último ríe mejor, sobre todo cuando ha sabido esperar en silencio el momento justo de su pequeña victoria.",
    "Agua que no has de beber, déjala correr, y no gastes tus fuerzas en aquello que jamás habrá de pertenecerte.",
    "A buen entendedor, pocas palabras bastan, porque la inteligencia verdadera no necesita largos discursos para comprender lo esencial.",
    "Camarón que se duerme se lo lleva la corriente, de modo que conviene estar siempre atento a las oportunidades de la vida.",
    "Más vale tarde que nunca, y nunca es demasiado tarde para empezar de nuevo aquello que el miedo dejó pendiente.",
    "La curiosidad no tiene cura, y por fortuna tampoco la necesita, pues de ella nacen los descubrimientos más asombrosos.",
    "El tiempo todo lo cura y todo lo cambia, y aquello que hoy parece una herida mañana será apenas una cicatriz olvidada.",
    "Quien busca encuentra, y quien persevera con paciencia termina alcanzando aquello que muchos abandonaron por simple cansancio.",
  ]

  /// Quote pools keyed by BCP-47 base language code. `"en"` mirrors ``quotes``.
  public static let quotesByLanguage: [String: [String]] = [
    "en": quotes,
    "es": quotesES,
  ]

  /// Returns a randomly selected English quote.
  public static func randomQuote() -> String {
    quotes.randomElement()!
  }

  /// Returns a randomly selected quote in the requested language.
  ///
  /// The lookup is by base language (the part before any region subtag, e.g.
  /// `"es-MX"` → `"es"`). Unknown languages fall back to the English pool so an
  /// unsupported `--language` still produces audio.
  ///
  /// - Parameter language: BCP-47 language code (default `"en"`).
  public static func randomQuote(language: String) -> String {
    quotes(forLanguage: language).randomElement()!
  }

  /// Resolves the quote pool for a language, falling back to English.
  private static func quotes(forLanguage language: String) -> [String] {
    let base =
      language.split(separator: "-").first.map(String.init)?.lowercased()
      ?? language.lowercased()
    return quotesByLanguage[base] ?? quotes
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

  /// Returns a random quote in the requested language (characterName is ignored).
  ///
  /// Falls back to English for unsupported languages.
  ///
  /// - Parameters:
  ///   - characterName: The character name (ignored).
  ///   - language: BCP-47 language code (default `"en"`).
  public static func defaultSentence(for characterName: String, language: String) -> String {
    randomQuote(language: language)
  }
}
