import ArgumentParser
import Foundation
import SwiftProyecto
import SwiftReparto

/// `echada generate cast` — scan the screenplay source material for character
/// names and merge them into the project's `CAST.md` roster.
///
/// This is heuristic-only in v1: `CastExtractor` finds CHARACTER cues in each
/// script via regex/parser heuristics — no LLM/ML model is involved. Only the
/// `character` field is populated for newly discovered members; `actor`,
/// `gender`, `voices`, `voicePrompt`, and `language` are left empty for later
/// stages (`generate prompt`, `generate vox`) or manual editing to fill in.
///
/// ## PROJECT.md is read-only here
///
/// `PROJECT.md` is consulted for `title`, `episodesDir`, and `filePattern`, and
/// is **never written** by this command. The roster lives in `CAST.md`, beside
/// `PROJECT.md`, written through SwiftReparto's `CastMarkdownParser` — the one
/// serializer in the ecosystem allowed to emit a `CAST.md`.
///
/// ## Seeding (EC-7)
///
/// When `CAST.md` is absent and `PROJECT.md` still carries a legacy `cast:`
/// block, that roster seeds the new `CAST.md` verbatim — every field, including
/// `voicePrompt`, undeclared keys such as `bio:`, and `voices` pointers —
/// before newly-discovered characters are merged on top. Fields the legacy
/// members never had stay absent; nothing is invented. An existing `CAST.md`
/// is authoritative and the legacy block is ignored.
///
/// ## Merge semantics (EC-8)
///
/// By default, newly discovered characters are added to the existing roster and
/// nothing already there is touched (no clobbering of `actor`, `voicePrompt`,
/// `voices`, `language`, or `bio`). `--force` re-syncs the roster to exactly
/// what is discovered in the current source material — characters no longer
/// present in any script are dropped — while still preserving every field on
/// matching characters. `--dry-run` prints the resulting roster and writes
/// nothing.
public struct GenerateCastCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "cast",
    abstract: "Discover cast members from the screenplay source and merge them into CAST.md.",
    discussion: """
      Consumes the project's episode/screenplay files (via `episodesDir`/`filePattern` \
      in PROJECT.md) and produces a merged roster in CAST.md, beside PROJECT.md. \
      PROJECT.md itself is read-only to this command — it is never modified.

      Character discovery is purely heuristic in this version — no LLM/ML model is \
      involved. Only the `character` name is populated for newly discovered members; \
      `actor`, `gender`, `voices`, `voicePrompt`, and `language` are left empty for \
      `generate prompt` / `generate vox` (or manual editing) to fill in later.

      Seeding: when CAST.md does not exist yet and PROJECT.md still carries a legacy \
      `cast:` block, that roster seeds the new CAST.md verbatim (voice prompts, bios, \
      and voice pointers included) before newly-discovered characters are merged on top.

      Idempotency: by default, only newly-appearing characters are added — existing \
      roster entries (and their downstream fields) are left untouched. Pass `--force` to \
      re-sync the roster to exactly the characters found in the current source \
      material, dropping any that no longer appear (matching characters still keep \
      their existing `actor`/`voicePrompt`/`voices`/`language`).

      Example:
          echada generate cast --project PROJECT.md
      """
  )

  @Option(name: .long, help: "Path to PROJECT.md file.")
  public var project: String = "PROJECT.md"

  @Option(
    name: .long,
    help:
      "Filename of the cast roster (default: CAST.md). A bare filename only — it always lives in --project's directory, so path separators are rejected."
  )
  public var cast: String = "CAST.md"

  @Flag(
    name: .long,
    help:
      "Re-sync the roster to exactly the characters found in the source material now (drops characters no longer present; matching characters keep their existing downstream fields). Default: add newly-appearing characters only."
  )
  public var force: Bool = false

  @Flag(
    name: .long, help: "Preview the resulting roster without writing CAST.md.")
  public var dryRun: Bool = false

  @Flag(name: .long, help: "Show verbose output.")
  public var verbose: Bool = false

  public init() {}

  public func run() async throws {
    let fileURL = URL(fileURLWithPath: project)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw ValidationError("Project file not found: \(project)")
    }
    let projectDir = fileURL.deletingLastPathComponent()
    let castURL = try Self.resolveCastFile(named: cast, in: projectDir)

    // PROJECT.md is read for `title`/`episodesDir`/`filePattern` only, and is
    // never written by this command (OQ-1, EC-8).
    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: fileURL)

    let episodeURLs = SourceMaterialLocator.episodeFiles(
      projectDirectory: projectDir, frontMatter: frontMatter)
    let highlandURLs = SourceMaterialLocator.highlandFiles(
      projectDirectory: projectDir, frontMatter: frontMatter)

    print("Project: \(frontMatter.title)")
    print(
      "Source: \(frontMatter.resolvedEpisodesDir)/ (patterns: \(frontMatter.resolvedFilePatterns.joined(separator: ", ")))"
    )
    print("Script files: \(episodeURLs.count)")
    if !highlandURLs.isEmpty {
      print(
        "  Note: \(highlandURLs.count) .highland bundle(s) found but not parsed (export to .fountain to include them)."
      )
    }
    if force { print("Force: re-syncing roster to discovered characters") }
    print("")
    fflush(stdout)

    guard !episodeURLs.isEmpty else {
      throw ValidationError(
        "No screenplay source files found under \(frontMatter.resolvedEpisodesDir)/ matching \(frontMatter.resolvedFilePatterns.joined(separator: ", ")). "
          + "Set `episodesDir`/`filePattern` in PROJECT.md, or add scripts to examine."
      )
    }

    // Load every script once and union the discovered character names.
    let extractor = CastExtractor()
    var discoveredNames: Set<String> = []
    for url in episodeURLs {
      guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        if verbose {
          print("[verbose] Could not read \(url.lastPathComponent) as UTF-8 — skipping")
        }
        continue
      }
      let names = extractor.extractCast(from: text)
      if verbose {
        print("[verbose] \(url.lastPathComponent): \(names.count) character(s)")
      }
      discoveredNames.formUnion(names)
    }

    let sortedNames = discoveredNames.sorted()

    print("Discovered characters: \(sortedNames.count)")
    for name in sortedNames {
      print("  \(name)")
    }

    let discoveredMembers = sortedNames.map { SwiftReparto.CastMember(character: $0) }

    // The roster base: an existing CAST.md is authoritative. When absent, the
    // legacy `cast:` block still living in PROJECT.md (if any) seeds the new
    // roster verbatim — every field carried through, nothing invented (EC-7).
    let castParser = CastMarkdownParser()
    let castFileExists = FileManager.default.fileExists(atPath: castURL.path)
    var document: CastDocument
    if castFileExists {
      document = try castParser.parse(fileURL: castURL)
    } else {
      let legacy = try LegacyProjectCastReader.readCast(fileURL: fileURL)
      document = CastDocument(cast: legacy)
      if !legacy.isEmpty {
        print("\nSeeding \(cast) from the legacy `cast:` block in \(project) (\(legacy.count) member(s)).")
      }
    }

    let baseCast = document.cast
    let mergedCast: [SwiftReparto.CastMember]
    if force {
      // Re-sync to exactly what was discovered this run, dropping characters
      // that no longer appear — but keep every field (actor, voicePrompt,
      // voices, bio, …) for characters that persist. The additive merge keeps
      // the base's spelling and fields for survivors; the filter then drops
      // members no discovered name matches.
      let discoveredKeys = Set(discoveredMembers.map { Self.matchKey($0.character) })
      mergedCast = baseCast.merging(discoveredMembers)
        .filter { discoveredKeys.contains(Self.matchKey($0.character)) }
    } else {
      // Default: additive and non-clobbering. SwiftReparto's `merging(_:)` can
      // only add members and fill gaps — it never removes a member, never
      // reorders, and never overwrites a field the roster already has.
      mergedCast = baseCast.merging(discoveredMembers)
    }
    document.cast = mergedCast

    let existingKeys = Set(baseCast.map { Self.matchKey($0.character) })
    let addedCount = mergedCast.filter { !existingKeys.contains(Self.matchKey($0.character)) }
      .count

    print("")
    print("  Total cast: \(mergedCast.count)")
    if addedCount > 0 { print("  Added: \(addedCount)") }

    if dryRun {
      print("\nResulting roster:")
      for member in mergedCast {
        print("  \(member.character)")
      }
      print("\n(dry run — no file writes)")
      return
    }

    // Nothing to seed and nothing discovered: don't create an empty CAST.md.
    // (`--force` still writes, because "re-sync to exactly what was found" is
    // an explicit request even when what was found is nothing.)
    guard castFileExists || !mergedCast.isEmpty || force else {
      print("\nNo characters discovered and no legacy cast to seed — \(cast) not created.")
      return
    }

    try castParser.write(document: document, to: castURL)
    print("\nWritten to \(castURL.path)")
  }

  // MARK: - Cast file resolution (OQ-1, EC-13)

  /// Resolves the `--cast` filename inside the project directory.
  ///
  /// `CAST.md` always sits beside `PROJECT.md`; `--cast` overrides the
  /// *filename* only. Any value carrying a path separator, or resolving
  /// outside the project directory, is rejected (OQ-1).
  static func resolveCastFile(named name: String, in projectDir: URL) throws -> URL {
    guard !name.isEmpty else {
      throw ValidationError("--cast must be a filename, not empty.")
    }
    guard !name.contains("/"), !name.contains("\\"), name != ".", name != ".." else {
      throw ValidationError(
        "--cast is a filename override only — it may not contain path separators or escape "
          + "the project directory. The cast file always lives beside PROJECT.md.")
    }
    let castURL = projectDir.appendingPathComponent(name, isDirectory: false)

    // Belt and suspenders: the standardized result must stay inside the
    // project directory.
    let standardizedDir = projectDir.standardizedFileURL.path
    let dirPrefix = standardizedDir.hasSuffix("/") ? standardizedDir : standardizedDir + "/"
    guard castURL.standardizedFileURL.path.hasPrefix(dirPrefix) else {
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
