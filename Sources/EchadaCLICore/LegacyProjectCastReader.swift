import Foundation
import SwiftReparto

// LEGACY-CAST-READ: delete at SwiftProyecto 5.0.
//
// Once SwiftProyecto 5.0 ships (with `cast:` gone from the PROJECT.md schema),
// this file has no reason to exist and must be deleted, not repurposed.

/// Reads the **legacy** `cast:` block out of a `PROJECT.md`'s front matter as
/// raw YAML, decoding straight into SwiftReparto's `[CastMember]` (EC-6).
///
/// This path deliberately never touches `ProjectFrontMatter.cast`
/// (SwiftProyecto's typed model). It exists so the rollout commands can read
/// rosters still living inside a `PROJECT.md` without coupling to the schema
/// that is about to lose the key. All YAML plumbing belongs to SwiftReparto's
/// `ProjectCastImporter` (RQ-10) — this repo adds no YAML dependency of its
/// own, and this type adds no decoding of its own. Every `CastMember` leniency
/// therefore applies here for free (RQ-3/RQ-4): the scalar and array `voices:`
/// forms, the legacy `voiceDescription:` alias for `voicePrompt:`, and
/// undeclared per-member keys such as `bio:` preserved in
/// ``SwiftReparto/CastMember/extraKeys``.
///
/// The one behavioral difference from calling the importer directly: a
/// well-formed `PROJECT.md` **without** a `cast:` key yields an empty array
/// here, not an error. SwiftReparto's `missingCastKey` is a typed error because
/// for a `CAST.md`-shaped migration a missing key is a defect; for this legacy
/// read path an absent `cast:` is the expected end state (the roster has moved
/// to `CAST.md`), so absence means "no legacy roster", not failure. Everything
/// else — no front matter at all, invalid YAML, a member with no `character` —
/// still throws, because those are malformed files, not migrated ones.
enum LegacyProjectCastReader {

  /// Extracts the legacy `cast:` roster from complete `PROJECT.md` text.
  ///
  /// - Parameter content: The whole `PROJECT.md`: front matter and markdown.
  /// - Returns: The roster in document order, or `[]` when the front matter
  ///   declares no `cast:` key.
  /// - Throws: ``SwiftReparto/CastParseError`` for a malformed file (no front
  ///   matter, invalid YAML, or a member missing `character`).
  static func readCast(content: String) throws -> [CastMember] {
    do {
      return try ProjectCastImporter().importCast(content: content).cast
    } catch CastParseError.missingCastKey {
      return []
    }
  }

  /// Reads a `PROJECT.md` from disk and extracts its legacy `cast:` roster,
  /// with voice paths normalized against the file's directory (SwiftReparto's
  /// D-7 behavior).
  ///
  /// - Parameter fileURL: The `PROJECT.md` to read. The file is never written.
  /// - Returns: The roster, or `[]` when the front matter declares no `cast:`.
  /// - Throws: ``SwiftReparto/CastParseError`` for a malformed file;
  ///   Foundation's own error when the file cannot be read.
  static func readCast(fileURL: URL) throws -> [CastMember] {
    do {
      return try ProjectCastImporter().importCast(fileURL: fileURL).cast
    } catch CastParseError.missingCastKey {
      return []
    }
  }
}
