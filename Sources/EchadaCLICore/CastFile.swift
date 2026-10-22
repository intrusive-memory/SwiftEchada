import ArgumentParser
import Foundation

/// Locating the `CAST.md` roster and comparing the names in it.
///
/// These used to live on `echada generate cast`, which 3.0.0 removed (EC-P11):
/// building a CAST.md from screenplays is now `personaje cast-discover`. Every
/// remaining stage and the automatic migration still need both.
enum CastFile {

  // MARK: - Cast file resolution (OQ-1, EC-13)

  /// Resolves the `--cast` filename inside the project directory.
  ///
  /// `CAST.md` always sits beside `PROJECT.md`; `--cast` overrides the
  /// *filename* only. Any value carrying a path separator, or resolving
  /// outside the project directory, is rejected (OQ-1).
  static func resolve(named name: String, in projectDir: URL) throws -> URL {
    guard !name.isEmpty else {
      throw ValidationError("--cast must be a filename, not empty.")
    }
    guard !name.contains("/"), !name.contains("\\"), name != ".", name != ".." else {
      throw ValidationError(
        "--cast is a filename override only — it may not contain path separators or escape "
          + "the project directory. The cast file always lives beside PROJECT.md.")
    }
    let castURL = projectDir.appendingPathComponent(name, isDirectory: false)

    // Belt and suspenders: the cast file's parent must be the project
    // directory. Compare the two directories rather than prefix-matching the
    // file's path: `standardizedFileURL` strips a `/private` prefix only from
    // paths that exist, so a not-yet-created CAST.md under `/private/tmp` would
    // otherwise appear to escape its (existing) directory.
    let castDir = castURL.deletingLastPathComponent().standardizedFileURL.path
    let standardizedDir = projectDir.standardizedFileURL.path
    guard castDir == standardizedDir else {
      throw ValidationError(
        "--cast resolves outside the project directory: \(name)")
    }
    return castURL
  }

  // MARK: - Character matching

  /// The case- and whitespace-insensitive key two `character` names are
  /// compared under, mirroring SwiftReparto's documented matching rule for
  /// `merging(_:)` (RQ-14): collapse every run of Unicode whitespace to one
  /// space, trim the ends, lowercase. Used only for membership tests here —
  /// never stored, never written into any member.
  static func matchKey(_ character: String) -> String {
    character
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
      .lowercased()
  }
}
