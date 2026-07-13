import Foundation
import FoundationModels
import SwiftProyecto

/// Failures surfaced when the on-device Foundation Model cannot synthesize a
/// character voice prompt.
enum VoicePromptSynthesizerError: LocalizedError {
  /// Apple Intelligence is unavailable (disabled, unsupported hardware, or the
  /// model is still downloading).
  case appleIntelligenceUnavailable
  /// The model ran but returned no usable voice prompt for the character.
  /// Carries the underlying FoundationModels error (if any) so the real cause
  /// is never swallowed.
  case generationFailed(character: String, underlying: Error?)

  var errorDescription: String? {
    switch self {
    case .appleIntelligenceUnavailable:
      return """
        Apple Intelligence is not available on this device. echada uses the \
        on-device Foundation Model to write voice prompts from your source \
        material, so you must have Apple Intelligence enabled. Turn it on in \
        System Settings ▸ Apple Intelligence & Siri on a supported Apple silicon Mac.
        """
    case .generationFailed(let character, let underlying):
      let base =
        "Apple Intelligence returned no usable voice prompt for character '\(character)'."
      guard let underlying else { return base }
      let detail =
        (underlying as? LocalizedError)?.errorDescription
        ?? String(describing: underlying)
      return "\(base) Underlying FoundationModels error: \(detail)"
    }
  }
}

/// Synthesizes a character's `voicePrompt` from screenplay evidence using Apple's
/// on-device Foundation Model.
///
/// echada already uses the on-device `SystemLanguageModel` as the single source
/// of audition sentences (see ``FoundationModelSentence``); this uses the same
/// model to turn a character's own dialogue and delivery notes into a compact,
/// human-readable voice-design brief. That brief is written to PROJECT.md as
/// `voicePrompt` and later fed to VoiceDesign's `voice:` parameter by
/// ``CastVoiceGenerator`` to lock the character's `.vox`.
enum VoicePromptSynthesizer {

  /// Fails fast when the on-device model is unusable. Call before any work.
  static func requireAvailable() throws {
    guard SystemLanguageModel.default.isAvailable else {
      throw VoicePromptSynthesizerError.appleIntelligenceUnavailable
    }
  }

  /// The most dialogue lines fed to the model — enough to characterize a voice
  /// without overrunning the on-device context window.
  static let maxDialogueLines = 40

  /// The most delivery notes (parentheticals / cue extensions) fed to the model.
  static let maxDeliveryNotes = 12

  /// Synthesize a one-line voice-casting description for a character.
  ///
  /// - Parameters:
  ///   - character: Character name (used for context and error messages; the
  ///     model is instructed NOT to echo it into the description).
  ///   - gender: Declared gender, if known — anchors the voice.
  ///   - language: BCP-47 spoken language, if known — a non-English language
  ///     directs the description to note a native accent.
  ///   - projectTitle: Project title, for tonal context.
  ///   - projectDescription: Project description/logline, if any.
  ///   - genre: Project genre, if any.
  ///   - evidence: Gathered dialogue and delivery notes for the character.
  /// - Returns: A sanitized voice-prompt string suitable for `voicePrompt`.
  /// - Throws: ``VoicePromptSynthesizerError`` if the model is unavailable or
  ///   returns nothing usable.
  static func synthesize(
    character: String,
    gender: Gender?,
    language: String?,
    projectTitle: String,
    projectDescription: String?,
    genre: String?,
    evidence: CharacterDialogueEvidence
  ) async throws -> String {
    guard SystemLanguageModel.default.isAvailable else {
      throw VoicePromptSynthesizerError.appleIntelligenceUnavailable
    }

    let prompt = buildPrompt(
      character: character,
      gender: gender,
      language: language,
      projectTitle: projectTitle,
      projectDescription: projectDescription,
      genre: genre,
      evidence: evidence
    )

    let content: String
    do {
      content = try await LanguageModelSession().respond(to: prompt).content
    } catch {
      throw VoicePromptSynthesizerError.generationFailed(character: character, underlying: error)
    }

    guard let result = sanitize(content) else {
      throw VoicePromptSynthesizerError.generationFailed(character: character, underlying: nil)
    }
    return result
  }

  // MARK: - Prompt construction (pure, unit-testable)

  /// Build the instruction handed to the Foundation Model. Kept pure so the
  /// exact evidence-selection and wording can be asserted in tests.
  static func buildPrompt(
    character: String,
    gender: Gender?,
    language: String?,
    projectTitle: String,
    projectDescription: String?,
    genre: String?,
    evidence: CharacterDialogueEvidence
  ) -> String {
    var context: [String] = []
    context.append("Character: \(character)")

    switch gender {
    case .male: context.append("Gender: male")
    case .female: context.append("Gender: female")
    case .nonBinary: context.append("Gender: non-binary")
    case .notSpecified, .none: break
    }

    var accentClause = ""
    if let language, !language.trimmingCharacters(in: .whitespaces).isEmpty,
      !isEnglish(language)
    {
      let name = languageDisplayName(language)
      context.append("Spoken language: \(name)")
      accentClause =
        " The voice must sound like a native \(name) speaker, so describe the appropriate accent."
    }

    var projectLine = "Project: \(projectTitle)"
    if let genre, !genre.trimmingCharacters(in: .whitespaces).isEmpty {
      projectLine += " (genre: \(genre))"
    }
    context.append(projectLine)
    if let projectDescription, !projectDescription.trimmingCharacters(in: .whitespaces).isEmpty {
      context.append("Project description: \(projectDescription)")
    }

    let lines = selectedDialogue(evidence.dialogue)
    var dialogueBlock = ""
    if !lines.isEmpty {
      dialogueBlock =
        "\n\nLines this character speaks:\n"
        + lines.map { "- \($0)" }.joined(separator: "\n")
    }

    let notes = selectedDeliveryNotes(evidence.parentheticals)
    var notesBlock = ""
    if !notes.isEmpty {
      notesBlock = "\n\nDelivery notes: \(notes.joined(separator: "; "))"
    }

    return """
      You are a casting director writing a text-to-speech voice-design brief.

      \(context.joined(separator: "\n"))\(dialogueBlock)\(notesBlock)

      The lines are provided ONLY so you can sense this character's emotional \
      register and rhythm of speech. Do not describe or restate what the lines \
      are about.

      Write exactly ONE vivid description of 20 to 45 words of how this \
      character's speaking voice SOUNDS. Capture timbre, pitch, pace, texture, \
      apparent age, and emotional quality.\(accentClause)

      Describe only the sound of the voice. Do NOT reference the character's \
      name, the project, the plot, their job, or any subject, topic, profession, \
      technology, object, or activity drawn from the lines. Every comparison must \
      be to a physical texture or natural sound (gravel, smoke, velvet, rust, \
      wind, glass) — never to the character's world or work. Output only the \
      description itself — no preamble, no label, no quotation marks, and no list.
      """
  }

  /// Choose a representative, deduplicated spread of dialogue lines (capped).
  /// Prefers substantive lines (drops one- and two-word interjections when
  /// enough longer lines exist) but never returns empty if any line exists.
  static func selectedDialogue(_ dialogue: [String]) -> [String] {
    var seen = Set<String>()
    let deduped = dialogue.filter { line in
      let key = line.lowercased()
      return seen.insert(key).inserted
    }
    let substantive = deduped.filter { $0.split(whereSeparator: { $0 == " " }).count >= 3 }
    let pool = substantive.count >= 5 ? substantive : deduped
    return Array(pool.prefix(maxDialogueLines))
  }

  /// Deduplicated, capped delivery notes.
  static func selectedDeliveryNotes(_ notes: [String]) -> [String] {
    var seen = Set<String>()
    let deduped = notes.filter { note in
      let key = note.lowercased()
      return seen.insert(key).inserted
    }
    return Array(deduped.prefix(maxDeliveryNotes))
  }

  // MARK: - Language helpers

  private static func isEnglish(_ language: String) -> Bool {
    let base =
      language.split(separator: "-").first.map(String.init)?.lowercased()
      ?? language.lowercased()
    return base == "en"
  }

  private static func languageDisplayName(_ language: String) -> String {
    let base =
      language.split(separator: "-").first.map(String.init)?.lowercased()
      ?? language.lowercased()
    // Prefer the full BCP-47 tag's localized name (keeps region, e.g. "Mexican
    // Spanish"), falling back to the base language name, then the raw tag.
    let identifier = language.replacingOccurrences(of: "-", with: "_")
    let english = Locale(identifier: "en_US")
    if let regional = english.localizedString(forIdentifier: identifier),
      !regional.isEmpty, regional != identifier
    {
      return regional
    }
    return english.localizedString(forLanguageCode: base) ?? language
  }

  // MARK: - Output normalization

  /// Normalize model output into a single clean voice-prompt line.
  ///
  /// Collapses to the first non-empty paragraph, strips a leading label
  /// (`Description:`), removes wrapping quotes, and flattens internal whitespace.
  /// Returns `nil` if nothing usable remains.
  static func sanitize(_ raw: String) -> String? {
    var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return nil }

    // Keep the first non-empty line/paragraph (guards against stray preambles).
    if let firstParagraph = text.components(separatedBy: "\n\n")
      .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
      .first(where: { !$0.isEmpty })
    {
      text = firstParagraph
    }

    // Flatten any remaining internal newlines to single spaces.
    text = text.split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
      .joined(separator: " ")

    // Drop a leading "Description:"/"Voice:" style label if the model added one.
    for label in ["description:", "voice:", "voice prompt:", "brief:"] {
      if text.lowercased().hasPrefix(label) {
        text = String(text.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
        break
      }
    }

    // Drop a single pair of wrapping quotes (straight or typographic).
    let quotePairs: [(Character, Character)] = [("\"", "\""), ("“", "”"), ("«", "»"), ("'", "'")]
    for (open, close) in quotePairs
    where text.first == open && text.last == close && text.count > 1 {
      text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
      break
    }

    // Collapse runs of internal whitespace to single spaces.
    text = text.split(whereSeparator: { $0 == " " || $0 == "\t" }).joined(separator: " ")

    return text.isEmpty ? nil : text
  }
}
