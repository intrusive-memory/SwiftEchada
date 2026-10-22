import ArgumentParser
import Foundation
import SwiftProyecto
import SwiftReparto

/// Failures that stop an automatic project migration before PROJECT.md is
/// rewritten. Each one leaves PROJECT.md exactly as it was.
enum ProjectMigrationError: LocalizedError {
  /// After writing CAST.md, a character from the legacy `cast:` block was not
  /// found in it. PROJECT.md is left untouched so nothing is lost.
  case charactersMissingAfterTransfer([String], castFile: String)

  var errorDescription: String? {
    switch self {
    case .charactersMissingAfterTransfer(let names, let castFile):
      return """
        Migration stopped: \(names.joined(separator: ", ")) did not make it into \(castFile). \
        PROJECT.md was not changed. Check \(castFile) and re-run.
        """
    }
  }
}

/// Upgrades a pre-v5 project to the current layout the first time echada
/// opens it.
///
/// Before PROJECT.md schema v5 the cast roster lived in PROJECT.md's `cast:`
/// block. Since v5 it lives in `CAST.md` (owned by SwiftReparto), and
/// SwiftProyecto no longer models `cast:` at all. Every `generate` stage calls
/// ``migrateIfNeeded(projectURL:castName:dryRun:)`` before doing its own work,
/// so an old project is upgraded on first contact.
///
/// ## What migration does
///
/// 1. Reads the legacy roster with ``LegacyProjectCastReader``.
/// 2. Writes it to CAST.md. A new CAST.md is seeded verbatim. An existing
///    CAST.md is authoritative: legacy-only members are added and empty fields
///    filled, but no CAST.md value is overwritten. Disagreements are printed.
/// 3. Re-reads CAST.md and confirms every legacy character is present. If any
///    is missing it throws, and PROJECT.md is not touched.
/// 4. Copies PROJECT.md to `PROJECT.md.bak`.
/// 5. Removes only the `cast:` line span and stamps `schemaVersion: 5`, via
///    SwiftProyecto's surgical rewrite primitives. Every other byte survives.
///
/// A PROJECT.md with no `cast:` block needs nothing and is never written.
enum ProjectMigration {

  struct Outcome: Equatable {
    /// PROJECT.md was (or, in a dry run, would be) rewritten.
    var migrated = false
    /// Legacy members carried into CAST.md that it did not already have.
    var membersAdded = 0
    /// Fields where CAST.md and the legacy block disagreed (CAST.md kept).
    var conflicts: [String] = []
    /// Where the pre-migration PROJECT.md was saved.
    var backupURL: URL?
  }

  @discardableResult
  static func migrateIfNeeded(
    projectURL: URL, castName: String, dryRun: Bool = false
  ) throws -> Outcome {
    let original = try String(contentsOf: projectURL, encoding: .utf8)
    let parser = ProjectMarkdownParser()
    let withoutCast = try parser.removingCastBlock(in: original)
    guard withoutCast != original else { return Outcome() }

    let projectDir = projectURL.deletingLastPathComponent()
    let castURL = try CastFile.resolve(named: castName, in: projectDir)
    let projectName = projectURL.lastPathComponent
    let legacy = try LegacyProjectCastReader.readCast(fileURL: projectURL)

    let castParser = CastMarkdownParser()
    let castExists = FileManager.default.fileExists(atPath: castURL.path)
    var document = castExists ? try castParser.parse(fileURL: castURL) : CastDocument(cast: [])

    var outcome = Outcome(migrated: true)
    let existingKeys = Set(document.cast.map { CastFile.matchKey($0.character) })
    outcome.membersAdded =
      legacy.filter { !existingKeys.contains(CastFile.matchKey($0.character)) }.count
    outcome.conflicts = CastRosterVerifier.divergences(
      castRoster: document.cast, legacyRoster: legacy, castDirectory: projectDir,
      castLabel: castName, projectLabel: projectName
    )
    .filter { $0.kind == .fieldMismatch }
    .map(\.message)

    print(
      "Migrating \(projectName) to schema v\(ProjectSchemaVersion.current): moving its cast to \(castName)."
    )
    if outcome.membersAdded > 0 {
      print(
        "  \(outcome.membersAdded) member(s) from the legacy `cast:` block go into \(castName).")
    }
    for conflict in outcome.conflicts {
      print("  Kept \(castName)'s value — \(conflict)")
    }

    if dryRun {
      print("  (dry run — \(projectName) and \(castName) left unchanged)")
      return outcome
    }

    // Additive and non-clobbering: adds missing members and fills empty
    // fields, never overwrites a value CAST.md already has.
    let merged = document.cast.merging(legacy)
    if !castExists || merged != document.cast {
      document.cast = merged
      try castParser.write(document: document, to: castURL)
    }

    // Verify the transfer from disk before PROJECT.md loses anything.
    let written = try castParser.parse(fileURL: castURL)
    let writtenKeys = Set(written.cast.map { CastFile.matchKey($0.character) })
    let missing = legacy.map(\.character)
      .filter { !writtenKeys.contains(CastFile.matchKey($0)) }
    guard missing.isEmpty else {
      throw ProjectMigrationError.charactersMissingAfterTransfer(missing, castFile: castName)
    }

    let backupURL = try backUp(projectURL)
    let migrated = try parser.stampingSchemaVersion(in: withoutCast)
    try migrated.write(to: projectURL, atomically: true, encoding: .utf8)
    outcome.backupURL = backupURL

    print(
      "  Removed the `cast:` block from \(projectName); original saved as \(backupURL.lastPathComponent)."
    )
    print("")
    fflush(stdout)
    return outcome
  }

  /// Copies `projectURL` to `<name>.bak`, or `<name>.bak.N` if that exists,
  /// so an earlier backup is never overwritten.
  private static func backUp(_ projectURL: URL) throws -> URL {
    let fileManager = FileManager.default
    var backupURL = projectURL.appendingPathExtension("bak")
    var suffix = 1
    while fileManager.fileExists(atPath: backupURL.path) {
      backupURL = projectURL.appendingPathExtension("bak.\(suffix)")
      suffix += 1
    }
    try fileManager.copyItem(at: projectURL, to: backupURL)
    return backupURL
  }
}
