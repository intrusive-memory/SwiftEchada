import Foundation

/// Evidence gathered from screenplay source material for a single character.
///
/// This is the raw material the `prompt` command feeds to the on-device
/// Foundation Model when synthesizing a `voicePrompt`: the character's own
/// dialogue, the parentheticals that colour their delivery, and the cue
/// extensions (`(V.O.)`, `(O.S.)`, `(CONT'D)`) that hint at how they are heard.
struct CharacterDialogueEvidence: Equatable, Sendable {
  /// The character's spoken dialogue lines, in script order, across all sources.
  var dialogue: [String] = []

  /// In-block parentheticals (e.g. `whispering`, `angrily`) plus cue extensions
  /// (e.g. `V.O.`, `O.S.`), with the wrapping parentheses stripped.
  var parentheticals: [String] = []

  /// Number of distinct dialogue blocks (cue → speech) attributed to the character.
  var blockCount: Int = 0

  /// True when no dialogue was found — the character has nothing to synthesize from.
  var isEmpty: Bool { dialogue.isEmpty }

  /// Merge another evidence bundle into this one (used to accumulate across files).
  mutating func merge(_ other: CharacterDialogueEvidence) {
    dialogue.append(contentsOf: other.dialogue)
    parentheticals.append(contentsOf: other.parentheticals)
    blockCount += other.blockCount
  }
}

/// Extracts a specific character's dialogue and parentheticals from Fountain
/// screenplay text.
///
/// `CastExtractor` (in SwiftProyecto) answers "who is in this script?"; this
/// answers "what does *this* character say, and how?" — the input the voice
/// designer actually needs to characterize a voice.
///
/// ## Fountain cue recognition
///
/// A character cue is an all-uppercase line that is preceded by a blank line and
/// followed by a non-blank line (the dialogue). A trailing parenthetical on the
/// cue itself (`UNCLE FU (CONT'D)`, `NARRATOR (V.O.)`) is treated as a cue
/// extension; a leading `@` force-declares a cue. The dialogue block runs until
/// the next blank line; lines wholly wrapped in `(...)` inside the block are
/// parentheticals rather than spoken text.
///
/// The uppercase/name heuristics mirror SwiftProyecto's `CastExtractor` so the
/// two agree on what counts as a character.
enum DialogueExtractor {

  /// Extract `character`'s dialogue and parentheticals from one Fountain script.
  ///
  /// - Parameters:
  ///   - character: The character name to collect (matched case-insensitively,
  ///     ignoring surrounding whitespace and internal-whitespace runs).
  ///   - fountainText: The full text of a `.fountain` (or Fountain-flavored) file.
  /// - Returns: The gathered ``CharacterDialogueEvidence`` (empty if the
  ///   character never speaks in this text).
  static func evidence(for character: String, in fountainText: String) -> CharacterDialogueEvidence
  {
    let target = normalize(character)
    guard !target.isEmpty else { return CharacterDialogueEvidence() }

    var evidence = CharacterDialogueEvidence()
    let lines = fountainText.components(separatedBy: .newlines)

    var index = 0
    while index < lines.count {
      let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else {
        index += 1
        continue
      }

      let precededByBlank =
        index == 0 || lines[index - 1].trimmingCharacters(in: .whitespaces).isEmpty
      let followedByText =
        index + 1 < lines.count && !lines[index + 1].trimmingCharacters(in: .whitespaces).isEmpty

      guard precededByBlank, followedByText, let cue = parseCue(trimmed) else {
        index += 1
        continue
      }

      guard normalize(cue.name) == target else {
        index += 1
        continue
      }

      // Matched cue: record any cue extension, then consume the dialogue block.
      if let ext = cue.ext, !ext.isEmpty {
        evidence.parentheticals.append(ext)
      }
      evidence.blockCount += 1

      var cursor = index + 1
      while cursor < lines.count {
        let blockLine = lines[cursor].trimmingCharacters(in: .whitespaces)
        if blockLine.isEmpty { break }
        if blockLine.hasPrefix("(") && blockLine.hasSuffix(")") && blockLine.count > 1 {
          let inner = String(blockLine.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
          if !inner.isEmpty { evidence.parentheticals.append(inner) }
        } else {
          evidence.dialogue.append(blockLine)
        }
        cursor += 1
      }
      index = cursor
    }

    return evidence
  }

  // MARK: - Private helpers

  /// A parsed character cue: the base name and an optional extension text
  /// (the contents of a trailing `(...)`, parentheses stripped).
  private struct Cue {
    let name: String
    let ext: String?
  }

  /// Parse a trimmed line as a Fountain character cue, or return `nil`.
  ///
  /// Handles a forcing leading `@` and a trailing parenthetical extension. The
  /// base (name with any trailing parenthetical removed) must satisfy the
  /// character-name heuristic.
  private static func parseCue(_ line: String) -> Cue? {
    var text = line
    var forced = false
    if text.hasPrefix("@") {
      text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
      forced = true
    }
    guard !text.isEmpty else { return nil }

    // Capture the last trailing parenthetical (e.g. "(V.O.)", "(CONT'D)").
    var ext: String?
    if text.hasSuffix(")"), let open = text.lastIndex(of: "(") {
      let inner = text[text.index(after: open)..<text.index(before: text.endIndex)]
      ext = inner.trimmingCharacters(in: .whitespaces)
    }

    let base = removeParentheticals(from: text)
    guard !base.isEmpty else { return nil }

    // A forced (`@`) cue is a cue regardless of casing; otherwise apply the
    // uppercase character-name heuristic.
    guard forced || isLikelyCharacterName(base) else { return nil }
    return Cue(name: base, ext: ext)
  }

  /// Remove all parenthetical groups from a line and trim the result.
  private static func removeParentheticals(from line: String) -> String {
    line.replacingOccurrences(
      of: "\\s*\\([^)]*\\)\\s*",
      with: "",
      options: .regularExpression
    ).trimmingCharacters(in: .whitespaces)
  }

  /// Case- and whitespace-insensitive normalization for name comparison.
  /// Uppercases, trims, and collapses internal whitespace runs to a single space.
  private static func normalize(_ name: String) -> String {
    let collapsed = name.split(whereSeparator: { $0 == " " || $0 == "\t" })
      .joined(separator: " ")
    return collapsed.uppercased()
  }

  /// Whether a line looks like a character name.
  ///
  /// Mirrors SwiftProyecto's `CastExtractor.isLikelyCharacterName` so the name
  /// filter stays consistent across the two extractors.
  private static func isLikelyCharacterName(_ text: String) -> Bool {
    guard text == text.uppercased() else { return false }

    if text.hasPrefix("INT.")
      || text.hasPrefix("EXT.")
      || text.hasPrefix("EST.")
      || text.hasPrefix("INT/EXT")
    {
      return false
    }
    if text.hasSuffix("TO:") { return false }
    if text.hasPrefix("(") || text.hasSuffix(")") { return false }
    if text.hasPrefix("FADE") || text.hasPrefix("CUT") || text.hasPrefix("DISSOLVE") {
      return false
    }

    let length = text.count
    if length < 1 || length > 50 { return false }

    let validCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ - '1234567890")
    let textSet = CharacterSet(charactersIn: text)
    guard textSet.isSubset(of: validCharacters) else { return false }

    return true
  }
}
