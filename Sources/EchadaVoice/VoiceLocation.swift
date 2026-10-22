import Foundation
import SwiftReparto

/// Why a member's `.vox` can't be placed (EC-23, EC-24). Each case names the
/// character so a batch can report it and keep going with the others.
public enum VoiceLocationError: LocalizedError, Equatable, Sendable {
  /// The name has no canonical form: it contains `/` or `:`, starts with `.`,
  /// or is empty once cue extensions are removed.
  case invalidName(character: String, reason: String)
  /// The name has a canonical form but CAST.md doesn't use it yet (mixed
  /// case, a cue extension, extra spaces).
  case nonCanonicalName(character: String, canonical: String)
  /// The destination would land outside the directory holding CAST.md.
  case outsideCastDirectory(character: String, path: String)
  /// A folder whose name differs only by case already exists where the
  /// character's folder would go.
  case caseCollision(character: String, existing: String, wanted: String)

  public var errorDescription: String? {
    switch self {
    case .invalidName(let character, let reason):
      return
        "'\(character)' can't be used as a voice file name (\(reason)). Rename the character in the screenplay."
    case .nonCanonicalName(let character, let canonical):
      return
        "'\(character)' isn't in canonical form ('\(canonical)'). Run `reparto canonicalize` on CAST.md first; echada never renames a character."
    case .outsideCastDirectory(let character, let path):
      return
        "The voice for '\(character)' would be written to '\(path)', outside the CAST.md directory."
    case .caseCollision(let character, let existing, let wanted):
      return
        "The voice for '\(character)' needs '\(wanted)', but '\(existing)' already exists and differs only by case. Rename one of them."
    }
  }
}

/// Where a member's `.vox` goes (EC-23) and what it's called (EC-24).
public struct VoiceLocation: Equatable, Sendable {

  /// Which EC-23 rule picked the location.
  public enum Rule: Equatable, Sendable {
    /// The member has a `manifest:` pointer: `<manifest dir>/voice/<NAME>.vox`.
    case manifest
    /// No manifest, but `voices.voxalta` already names a file: regenerate in place.
    case existingPointer
    /// Neither: `<charactersDir>/<NAME>.dossier/voice/<NAME>.vox`.
    case newDossier
  }

  /// The path written to `voices.voxalta`, relative to the CAST.md directory.
  public let relativePath: String
  /// The absolute file URL.
  public let url: URL
  public let rule: Rule

  /// The default `charactersDir` (PROJECT.md `personaje.charactersDir`).
  public static let defaultCharactersDir = "characters"

  /// The canonical name used for file names, or the error that stops this
  /// member (EC-24).
  public static func fileName(for character: String) throws -> String {
    let canonical: String
    do {
      canonical = try CastMember.canonicalName(character)
    } catch {
      throw VoiceLocationError.invalidName(
        character: character, reason: error.localizedDescription)
    }
    guard canonical == character else {
      throw VoiceLocationError.nonCanonicalName(character: character, canonical: canonical)
    }
    return canonical
  }

  /// Resolves the location for `member` under EC-23's rules, in order.
  ///
  /// - Parameters:
  ///   - member: The cast member.
  ///   - castDirectory: The directory holding CAST.md.
  ///   - charactersDir: PROJECT.md `personaje.charactersDir`, relative to the
  ///     CAST.md directory.
  ///   - fileManager: Used only for the case-collision check.
  public static func resolve(
    for member: CastMember,
    castDirectory: URL,
    charactersDir: String = defaultCharactersDir,
    fileManager: FileManager = .default
  ) throws -> VoiceLocation {
    let name = try fileName(for: member.character)
    let castDir = castDirectory.standardizedFileURL

    let rule: Rule
    let relativePath: String
    if let manifest = member.manifest, !manifest.isEmpty {
      rule = .manifest
      let bundle = (manifest as NSString).deletingLastPathComponent
      relativePath = join(bundle, "voice", "\(name).vox")
    } else if let existing = member.voices["voxalta"]?.first, !existing.isEmpty {
      rule = .existingPointer
      relativePath = existing
    } else {
      rule = .newDossier
      relativePath = join(charactersDir, "\(name).dossier", "voice", "\(name).vox")
    }

    let url =
      relativePath.hasPrefix("/")
      ? URL(fileURLWithPath: relativePath).standardizedFileURL
      : castDir.appending(path: relativePath).standardizedFileURL
    // An existing pointer is regenerated wherever it points (rule 2); every
    // new destination must stay inside the CAST.md directory.
    guard rule == .existingPointer || isInside(url, castDir) else {
      throw VoiceLocationError.outsideCastDirectory(character: member.character, path: relativePath)
    }

    // Refuse to sit beside a folder that differs only by case: on a
    // case-insensitive volume they are the same folder under two names.
    if rule != .existingPointer {
      try checkCaseCollisions(
        for: url, below: castDir, character: member.character, fileManager: fileManager)
    }
    return VoiceLocation(relativePath: relativePath, url: url, rule: rule)
  }

  // MARK: - Helpers

  private static func join(_ parts: String...) -> String {
    parts.filter { !$0.isEmpty && $0 != "." }.joined(separator: "/")
  }

  private static func isInside(_ url: URL, _ directory: URL) -> Bool {
    let dir = directory.path.hasSuffix("/") ? directory.path : directory.path + "/"
    return url.path.hasPrefix(dir)
  }

  /// Walks each directory component between the CAST.md directory and the
  /// file, and fails when a sibling's name equals it ignoring case but not
  /// exactly.
  private static func checkCaseCollisions(
    for url: URL, below castDir: URL, character: String, fileManager: FileManager
  ) throws {
    let relative = url.deletingLastPathComponent().path.dropFirst(castDir.path.count)
    var parent = castDir
    for component in relative.split(separator: "/").map(String.init) {
      if let siblings = try? fileManager.contentsOfDirectory(atPath: parent.path),
        let clash = siblings.first(where: {
          $0 != component && $0.caseInsensitiveCompare(component) == .orderedSame
        })
      {
        throw VoiceLocationError.caseCollision(
          character: character, existing: clash, wanted: component)
      }
      parent = parent.appending(path: component)
    }
  }
}
