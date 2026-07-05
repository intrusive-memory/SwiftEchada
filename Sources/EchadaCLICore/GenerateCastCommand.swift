import ArgumentParser
import Foundation
import SwiftProyecto

/// `echada generate cast` — scan the screenplay source material for character
/// names and merge them into PROJECT.md's `cast:` list.
///
/// This is heuristic-only in v1: `CastExtractor` finds CHARACTER cues in each
/// script via regex/parser heuristics — no LLM/ML model is involved. Only the
/// `character` field is populated for newly discovered members; `actor`,
/// `gender`, `voices`, `voicePrompt`, and `language` are left empty for later
/// stages (`generate prompt`, `generate vox`) or manual editing to fill in.
///
/// By default, newly discovered characters are added to the existing cast and
/// nothing already in PROJECT.md is touched (no clobbering of `actor`,
/// `voicePrompt`, `voices`, or `language`). `--force` re-syncs the cast list to
/// exactly what is discovered in the current source material — characters no
/// longer present in any script are dropped — while still preserving whatever
/// downstream fields survive on matching characters.
public struct GenerateCastCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "cast",
    abstract: "Discover cast members from the screenplay source and merge them into PROJECT.md.",
    discussion: """
      Consumes the project's episode/screenplay files (via `episodesDir`/`filePattern` \
      in PROJECT.md) and produces a merged `cast:` list in PROJECT.md.

      Character discovery is purely heuristic in this version — no LLM/ML model is \
      involved. Only the `character` name is populated for newly discovered members; \
      `actor`, `gender`, `voices`, `voicePrompt`, and `language` are left empty for \
      `generate prompt` / `generate vox` (or manual editing) to fill in later.

      Idempotency: by default, only newly-appearing characters are added — existing \
      cast entries (and their downstream fields) are left untouched. Pass `--force` to \
      re-sync the cast list to exactly the characters found in the current source \
      material, dropping any that no longer appear (matching characters still keep \
      their existing `actor`/`voicePrompt`/`voices`/`language`).

      Example:
          echada generate cast --project PROJECT.md
      """
  )

  @Option(name: .long, help: "Path to PROJECT.md file.")
  public var project: String = "PROJECT.md"

  @Flag(
    name: .long,
    help:
      "Re-sync the cast list to exactly the characters found in the source material now (drops characters no longer present; matching characters keep their existing downstream fields). Default: add newly-appearing characters only."
  )
  public var force: Bool = false

  @Flag(
    name: .long, help: "Preview discovered characters without writing PROJECT.md.")
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
    let parser = ProjectMarkdownParser()
    let (frontMatter, body) = try parser.parse(fileURL: fileURL)

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
    if force { print("Force: re-syncing cast list to discovered characters") }
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

    if dryRun {
      print("\n(dry run — no file writes)")
      return
    }

    guard !sortedNames.isEmpty else {
      print("\nNo characters discovered — \(project) left unchanged.")
      return
    }

    let discoveredMembers = sortedNames.map { CastMember(character: $0) }
    let existingCast = frontMatter.cast ?? []

    let mergedCast: [CastMember]
    if force {
      // Re-sync to exactly what was discovered this run, dropping characters
      // that no longer appear — but keep every downstream field (actor,
      // voicePrompt, voices, language) for characters that persist.
      //
      // Fountain cues surface as uppercase (ALICE) while a curated PROJECT.md
      // may store mixed case (Alice), so key both sides with the same
      // case/whitespace normalization used for cue matching elsewhere.
      // Otherwise a curated member would be treated as non-matching, dropped,
      // and replaced with a bare discovered entry — losing its downstream fields.
      let existingByName = Dictionary(
        existingCast.map { (Self.normalizeCharacter($0.character), $0) },
        uniquingKeysWith: { _, last in last })
      mergedCast =
        discoveredMembers
        .map { existingByName[Self.normalizeCharacter($0.character)] ?? $0 }
        .sorted { $0.character < $1.character }
    } else {
      // Default: keep the existing cast untouched and only add newly-appearing
      // characters (zero information loss for anything already in PROJECT.md).
      // `ProjectService.mergeCastLists` requires a SwiftData `ModelContext` to
      // construct, which the CLI has no use for here, so we use the equivalent
      // static merge on `ProjectFrontMatter` instead: existing is the "master"
      // (its fields always win via `.preserveExisting`), discovered supplies
      // any newly-appearing characters.
      let mergedByName = ProjectFrontMatter.mergeCast(
        existingCast, discoveredMembers, strategy: .preserveExisting)
      mergedCast = mergedByName.values.sorted { $0.character < $1.character }
    }

    let existingNames = Set(existingCast.map(\.character))
    let addedCount = mergedCast.filter { !existingNames.contains($0.character) }.count

    print("")
    print("  Total cast: \(mergedCast.count)")
    if addedCount > 0 { print("  Added: \(addedCount)") }

    let updatedFrontMatter = frontMatter.withCast(mergedCast.isEmpty ? nil : mergedCast)
    try parser.write(frontMatter: updatedFrontMatter, body: body, to: fileURL)
    print("\nWritten to \(project)")
  }

  /// Case- and whitespace-insensitive key for matching a discovered cue name to
  /// an existing cast member. Trims, collapses internal whitespace runs to a
  /// single space, and uppercases — mirroring `DialogueExtractor.normalize` so
  /// cue-to-cast matching stays consistent across the pipeline.
  static func normalizeCharacter(_ name: String) -> String {
    name.split(whereSeparator: { $0 == " " || $0 == "\t" })
      .joined(separator: " ")
      .uppercased()
  }
}
