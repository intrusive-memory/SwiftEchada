import Foundation
import SwiftReparto

// MARK: - Divergence model

/// One disagreement between `CAST.md` and a legacy `cast:` block, found
/// during automatic migration (see ``ProjectMigration``).
///
/// Three classes exist, mirroring the migration's failure modes:
/// - ``Kind/membership``: a character present in one file and not the other.
/// - ``Kind/fieldMismatch``: a matched character whose field values differ
///   between `CAST.md` and the legacy `cast:` block.
/// - ``Kind/danglingVoicePath``: a `.vox` pointer in `CAST.md` that does not
///   resolve to an existing file on disk (resolved relative to the `CAST.md`
///   directory).
public struct CastDivergence: Equatable, Sendable {

  /// The divergence class.
  public enum Kind: Equatable, Sendable {
    /// Character present in one file and not the other.
    case membership
    /// A matched character carries a differing field value.
    case fieldMismatch
    /// A `.vox` path in `CAST.md` that does not exist on disk.
    case danglingVoicePath
  }

  /// Which class of disagreement this is.
  public let kind: Kind

  /// The character the disagreement is about, as spelled in the file that
  /// carries it.
  public let character: String

  /// Human-readable diagnostic naming the character and, where applicable,
  /// the differing field or the dangling path.
  public let message: String
}

// MARK: - Verifier

/// Pure comparison logic behind ``ProjectMigration``: given both rosters, it
/// returns every divergence and touches nothing.
///
/// The only filesystem access is the existence check behind the
/// dangling-`.vox` class — SwiftReparto deliberately never stats paths
/// (RQ-7), so the consumer that wants to know whether a voice file is really
/// there has to ask the filesystem itself, and this is where it asks.
enum CastRosterVerifier {

  /// Compares a `CAST.md` roster against the legacy `cast:` roster and
  /// checks `.vox` pointers on disk.
  ///
  /// - Parameters:
  ///   - castRoster: The roster parsed from `CAST.md`.
  ///   - legacyRoster: The roster read from `PROJECT.md`'s legacy `cast:`
  ///     block (empty when the key is absent).
  ///   - castDirectory: The directory containing `CAST.md`; relative voice
  ///     paths resolve against it.
  ///   - castLabel: Display name for the cast file (e.g. `CAST.md`).
  ///   - projectLabel: Display name for the project file (e.g. `PROJECT.md`).
  /// - Returns: Every divergence, in a stable order: membership first
  ///   (legacy-only members in legacy order, then cast-only members in cast
  ///   order), then field mismatches in cast order, then dangling `.vox`
  ///   paths in cast order.
  static func divergences(
    castRoster: [CastMember],
    legacyRoster: [CastMember],
    castDirectory: URL,
    castLabel: String,
    projectLabel: String
  ) -> [CastDivergence] {
    var found: [CastDivergence] = []

    // Membership is matched under the same case- and whitespace-insensitive
    // key SwiftReparto's `merging(_:)` uses (RQ-14), so migration and the
    // merge can never disagree about whether two spellings are the same
    // character.
    var legacyByKey: [String: CastMember] = [:]
    for member in legacyRoster {
      let key = CastFile.matchKey(member.character)
      if legacyByKey[key] == nil { legacyByKey[key] = member }
    }
    var castByKey: [String: CastMember] = [:]
    for member in castRoster {
      let key = CastFile.matchKey(member.character)
      if castByKey[key] == nil { castByKey[key] = member }
    }

    // Class 1: present in one file and not the other — both directions.
    for member in legacyRoster
    where castByKey[CastFile.matchKey(member.character)] == nil {
      found.append(
        CastDivergence(
          kind: .membership,
          character: member.character,
          message:
            "\(member.character): present in \(projectLabel)'s legacy `cast:` but missing from \(castLabel)"
        ))
    }
    for member in castRoster
    where legacyByKey[CastFile.matchKey(member.character)] == nil {
      found.append(
        CastDivergence(
          kind: .membership,
          character: member.character,
          message:
            "\(member.character): present in \(castLabel) but missing from \(projectLabel)'s legacy `cast:`"
        ))
    }

    // Class 2: differing field values on a matched character.
    for member in castRoster {
      guard let legacy = legacyByKey[CastFile.matchKey(member.character)] else {
        continue
      }
      found.append(
        contentsOf: fieldMismatches(
          cast: member, legacy: legacy,
          castLabel: castLabel, projectLabel: projectLabel))
    }

    // Class 3: `.vox` paths in CAST.md that do not resolve on disk, relative
    // to the CAST.md directory.
    for member in castRoster {
      for provider in member.voices.keys.sorted() {
        for path in member.voices[provider] ?? []
        where path.lowercased().hasSuffix(".vox") {
          let resolved =
            path.hasPrefix("/")
            ? URL(fileURLWithPath: path)
            : castDirectory.appendingPathComponent(path)
          if !FileManager.default.fileExists(atPath: resolved.path) {
            found.append(
              CastDivergence(
                kind: .danglingVoicePath,
                character: member.character,
                message:
                  "\(member.character): voice path \(path) (\(provider)) in \(castLabel) does not resolve to an existing file"
              ))
          }
        }
      }
    }

    return found
  }

  /// Compares every field on a matched character pair, naming each field
  /// that differs.
  private static func fieldMismatches(
    cast: CastMember,
    legacy: CastMember,
    castLabel: String,
    projectLabel: String
  ) -> [CastDivergence] {
    var mismatches: [CastDivergence] = []

    func report(_ field: String, castValue: String, legacyValue: String) {
      mismatches.append(
        CastDivergence(
          kind: .fieldMismatch,
          character: cast.character,
          message:
            "\(cast.character): field `\(field)` differs — \(castLabel): \(castValue) / \(projectLabel): \(legacyValue)"
        ))
    }

    func describe(_ value: String?) -> String {
      value.map { "\"\($0)\"" } ?? "(absent)"
    }

    if cast.character != legacy.character {
      report(
        "character", castValue: describe(cast.character),
        legacyValue: describe(legacy.character))
    }
    if cast.actor != legacy.actor {
      report("actor", castValue: describe(cast.actor), legacyValue: describe(legacy.actor))
    }
    if cast.gender != legacy.gender {
      report(
        "gender", castValue: describe(cast.gender?.rawValue),
        legacyValue: describe(legacy.gender?.rawValue))
    }
    if cast.language != legacy.language {
      report(
        "language", castValue: describe(cast.language), legacyValue: describe(legacy.language))
    }
    if cast.voicePrompt != legacy.voicePrompt {
      report(
        "voicePrompt", castValue: describe(cast.voicePrompt),
        legacyValue: describe(legacy.voicePrompt))
    }
    if cast.voices != legacy.voices {
      report(
        "voices", castValue: describeVoices(cast.voices),
        legacyValue: describeVoices(legacy.voices))
    }

    // Undeclared keys (`bio:`, a deferred `appearance:` block) compare
    // per-key, so the diagnostic names the actual key that drifted.
    let extraKeyNames = Set(cast.extraKeys.keys).union(legacy.extraKeys.keys)
    for key in extraKeyNames.sorted() where cast[extra: key] != legacy[extra: key] {
      report(
        key,
        castValue: cast[extra: key].map { String(describing: $0) } ?? "(absent)",
        legacyValue: legacy[extra: key].map { String(describing: $0) } ?? "(absent)")
    }

    return mismatches
  }

  private static func describeVoices(_ voices: [String: [String]]) -> String {
    guard !voices.isEmpty else { return "(none)" }
    return voices.keys.sorted()
      .map { "\($0): [\((voices[$0] ?? []).joined(separator: ", "))]" }
      .joined(separator: "; ")
  }
}
