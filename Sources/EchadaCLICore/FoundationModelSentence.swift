import Foundation
import FoundationModels

/// Sources a short, in-language audition sentence from Apple's on-device
/// Foundation Model (`SystemLanguageModel`).
///
/// The on-device system model is multilingual and understands/produces text in
/// every language Apple Intelligence supports (es, fr, it, pt, de, …). Using it
/// for the voice-audition reference sentence means we get a genuinely
/// in-language sample for any supported locale without maintaining a hand-curated
/// quote pool per language.
///
/// This is strictly additive: every failure mode (Apple Intelligence off,
/// unsupported locale, generation error, empty output) returns `nil` so callers
/// fall back to the bundled ``SwiftEchada/SampleSentenceGenerator`` pools. The
/// worst case therefore matches the pre-existing behavior exactly.
enum FoundationModelSentence {

  /// Returns one in-language audition sentence, or `nil` when the on-device
  /// model can't satisfy the request and the caller should fall back.
  ///
  /// - Parameter rawLanguage: A BCP-47 code (e.g. `"es-MX"`, `"fr-FR"`, `"de"`).
  static func auditionSentence(language rawLanguage: String) async -> String? {
    let model = SystemLanguageModel.default
    guard model.isAvailable else { return nil }

    let identifier = rawLanguage.replacingOccurrences(of: "-", with: "_")
    let locale = Locale(identifier: identifier)
    guard model.supportsLocale(locale) else { return nil }

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

    do {
      let response = try await LanguageModelSession().respond(to: prompt)
      return sanitize(response.content)
    } catch {
      return nil
    }
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
