import Foundation
import FoundationModels

/// Hard configuration failures surfaced when the on-device Foundation Model
/// cannot produce a voice-audition sentence.
///
/// echada uses Apple's on-device Foundation Model as the *single* source of
/// voice-audition reference sentences — there is no curated fallback pool — so an
/// unavailable model or unsupported locale is a configuration error the user must
/// fix, not something to silently work around.
enum FoundationModelSentenceError: LocalizedError {
  /// Apple Intelligence is not available on this device (disabled, unsupported
  /// hardware, or the model is still downloading).
  case appleIntelligenceUnavailable
  /// Apple Intelligence is available but does not support the requested locale.
  case unsupportedLanguage(String)
  /// The model ran but produced no usable sentence.
  case generationFailed(String)

  var errorDescription: String? {
    switch self {
    case .appleIntelligenceUnavailable:
      return """
        Apple Intelligence is not available on this device. echada uses the \
        on-device Foundation Model to generate voice-audition sentences, so you \
        must have Apple Intelligence enabled to ride this ride. Enable it in \
        System Settings ▸ Apple Intelligence & Siri on a supported Apple silicon Mac.
        """
    case .unsupportedLanguage(let language):
      return """
        Apple Intelligence does not support audition-sentence generation for \
        language '\(language)' on this device. Choose a supported language, or \
        enable that language in System Settings ▸ Apple Intelligence & Siri.
        """
    case .generationFailed(let language):
      return
        "Apple Intelligence returned no usable audition sentence for language '\(language)'."
    }
  }
}

/// Sources a short, in-language audition sentence from Apple's on-device
/// Foundation Model (`SystemLanguageModel`).
///
/// The on-device system model is multilingual and understands/produces text in
/// every language Apple Intelligence supports (es, fr, it, pt, de, …). echada
/// relies on it as the single source of voice-audition reference sentences, so a
/// genuinely in-language sample is produced for any supported locale with no
/// hand-curated quote pools to maintain.
///
/// Every failure mode (Apple Intelligence off, unsupported locale, generation
/// error, empty output) throws a ``FoundationModelSentenceError`` so the caller
/// can surface a clear configuration failure rather than falling back to a
/// canned sentence.
enum FoundationModelSentence {

  /// Fails fast with ``FoundationModelSentenceError/appleIntelligenceUnavailable``
  /// when the on-device model is not usable. Call this before any expensive model
  /// loading so the user sees the configuration error immediately.
  static func requireAvailable() throws {
    guard SystemLanguageModel.default.isAvailable else {
      throw FoundationModelSentenceError.appleIntelligenceUnavailable
    }
  }

  /// Returns one in-language audition sentence for `rawLanguage`.
  ///
  /// - Parameter rawLanguage: A BCP-47 code (e.g. `"es-MX"`, `"fr-FR"`, `"de"`).
  /// - Throws: ``FoundationModelSentenceError`` when Apple Intelligence is
  ///   unavailable, the locale is unsupported, or generation yields nothing.
  static func auditionSentence(language rawLanguage: String) async throws -> String {
    let model = SystemLanguageModel.default
    guard model.isAvailable else {
      throw FoundationModelSentenceError.appleIntelligenceUnavailable
    }

    let identifier = rawLanguage.replacingOccurrences(of: "-", with: "_")
    let locale = Locale(identifier: identifier)
    guard model.supportsLocale(locale) else {
      throw FoundationModelSentenceError.unsupportedLanguage(rawLanguage)
    }

    let baseCode =
      rawLanguage.split(separator: "-").first.map(String.init)?.lowercased()
      ?? rawLanguage.lowercased()
    let englishName =
      Locale(identifier: "en_US").localizedString(forLanguageCode: baseCode)
      ?? baseCode

    // The leading locale phrase is the exact format Apple recommends to reduce
    // multilingual hallucinations; the explicit language clause pins the output.
    let prompt = """
      The person's locale is \(locale.identifier). \
      You MUST respond only in \(englishName). \
      Write exactly one natural, vivid sentence of 15 to 25 words suitable for a \
      text-to-speech voice audition. The sentence must be neutral, free of proper \
      names, and free of quotation marks, ellipses, em dashes, and repeated \
      punctuation. Output only the sentence itself — no preamble, no translation, \
      and no commentary.
      """

    let content: String
    do {
      content = try await LanguageModelSession().respond(to: prompt).content
    } catch {
      throw FoundationModelSentenceError.generationFailed(rawLanguage)
    }
    guard let sentence = sanitize(content) else {
      throw FoundationModelSentenceError.generationFailed(rawLanguage)
    }
    return sentence
  }

  /// Normalizes model output into a single clean line safe for the TTS engine.
  ///
  /// Strips wrapping quotes, collapses to the first line/paragraph, and removes
  /// stacked terminal punctuation (`...`, `!!`, `,,`) which is documented to
  /// destabilize the Qwen3-TTS speaker conditioning. Returns `nil` if nothing
  /// usable remains.
  private static func sanitize(_ raw: String) -> String? {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

    // Keep only the first non-empty line — guards against a stray preamble or a
    // model that emits multiple lines despite the instruction.
    if let firstLine = text.split(whereSeparator: \.isNewline)
      .map({ $0.trimmingCharacters(in: .whitespaces) })
      .first(where: { !$0.isEmpty })
    {
      text = firstLine
    }

    // Drop a single pair of wrapping quotes (straight or typographic).
    let quotePairs: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("«", "»"), ("'", "'")]
    for (open, close) in quotePairs where text.first == open && text.last == close && text.count > 1
    {
      text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
      break
    }

    // Collapse runs of stacked terminal punctuation to a single mark.
    var collapsed = ""
    collapsed.reserveCapacity(text.count)
    var previous: Character? = nil
    let stackable: Set<Character> = [".", "!", "?", ",", ";", ":"]
    for character in text {
      if let prev = previous, stackable.contains(character), stackable.contains(prev) {
        continue
      }
      collapsed.append(character)
      previous = character
    }

    let result = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    return result.isEmpty ? nil : result
  }
}
