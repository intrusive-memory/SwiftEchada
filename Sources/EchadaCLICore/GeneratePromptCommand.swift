import ArgumentParser
import Foundation
import SwiftProyecto
import SwiftReparto

/// `echada generate prompt` — examine the screenplay source material and write
/// a `voicePrompt` for each cast member in CAST.md.
///
/// This is the inverse of `generate vox`: where `vox` consumes each member's
/// `voicePrompt` to lock a `.vox`, `prompt` reads the episode scripts, gathers
/// what each character actually says (and how), and asks the on-device
/// Foundation Model to write the voice-design brief that `vox` will later use.
///
/// ## The roster lives in CAST.md; PROJECT.md is read-only here
///
/// The cast is read from — and written back to — `CAST.md`, beside
/// `PROJECT.md`, through SwiftReparto's `CastMarkdownParser` (EC-12).
/// `PROJECT.md` is still consulted read-only for `title`, `description`,
/// `genre`, `episodesDir`, and `filePattern`, but its legacy `cast:` block is
/// never touched. When `CAST.md` is absent this command fails rather than
/// creating it — only `echada generate cast` creates the roster (EC-14).
///
/// Characters are processed one at a time, in cast order. By default a member
/// that already has a `voicePrompt` is left untouched; `--force` regenerates all.
public struct GeneratePromptCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "prompt",
    abstract:
      "Examine the source material and write a voicePrompt for each cast member in CAST.md.",
    discussion: """
      Consumes the project's screenplay source material (via `episodesDir`/`filePattern` \
      in PROJECT.md) and each cast member's dialogue within it, and produces a \
      `voicePrompt` per member — written by the on-device Foundation Model from the \
      gathered dialogue evidence.

      The roster is read from, and written back to, CAST.md (beside PROJECT.md); \
      PROJECT.md itself is read-only here (`title`, `episodesDir`, `filePattern`) and \
      is never modified. When CAST.md is absent this command fails — run \
      `echada generate cast` first to create it.

      Idempotency: by default, only members with an empty `voicePrompt` are filled in; \
      members that already have one are left untouched. Pass `--force` to regenerate \
      the voice prompt for every targeted member, overwriting what is already there.

      Example:
          echada generate prompt --character ALICE --force
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

  @Option(name: .long, help: "Generate a voice prompt for a single character (by name).")
  public var character: String?

  @Flag(
    name: .long,
    help: "Overwrite voice prompts for members that already have one (default: fill empty only).")
  public var force: Bool = false

  @Flag(
    name: .long, help: "Preview the gathered source material without calling the model or writing.")
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
    let castURL = try GenerateCastCommand.resolveCastFile(named: cast, in: projectDir)

    // EC-14: the roster must already exist — this command never creates it.
    guard FileManager.default.fileExists(atPath: castURL.path) else {
      throw ValidationError(
        "Cast file not found: \(castURL.path). `generate prompt` reads the roster from \(cast) "
          + "and never creates it — run `echada generate cast` first.")
    }

    // PROJECT.md is read-only here: `title`/`description`/`genre` feed the
    // synthesizer and `episodesDir`/`filePattern` locate the scripts (EC-12).
    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: fileURL)

    let castParser = CastMarkdownParser()
    var document = try castParser.parse(fileURL: castURL)
    let roster = document.cast
    guard !roster.isEmpty else {
      throw ValidationError(
        "No cast members found in \(cast). Run `echada generate cast` to discover them.")
    }

    // Resolve the target cast (all, or a single --character filter).
    let targetCast: [SwiftReparto.CastMember]
    if let characterName = character {
      targetCast = roster.filter {
        $0.character.localizedCaseInsensitiveCompare(characterName) == .orderedSame
      }
      guard !targetCast.isEmpty else {
        throw ValidationError(
          "Character '\(characterName)' not found in cast. Available: \(roster.map(\.character).joined(separator: ", "))"
        )
      }
    } else {
      targetCast = roster
    }

    // Locate and load the source material once.
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
    print(
      "Cast members: \(targetCast.count)\(character != nil ? " (filtered: \(character!))" : "")")
    if force { print("Force: overwriting existing voice prompts") }
    print("")
    fflush(stdout)

    guard !episodeURLs.isEmpty else {
      throw ValidationError(
        "No screenplay source files found under \(frontMatter.resolvedEpisodesDir)/ matching \(frontMatter.resolvedFilePatterns.joined(separator: ", ")). "
          + "Set `episodesDir`/`filePattern` in PROJECT.md, or add scripts to examine."
      )
    }

    // Load all script texts once; reused for every character.
    let scripts: [String] = episodeURLs.compactMap { url in
      guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        if verbose {
          print("[verbose] Could not read \(url.lastPathComponent) as UTF-8 — skipping")
        }
        return nil
      }
      return text
    }

    // Fail fast on model availability before any per-character work (skip in dry run).
    if !dryRun {
      try VoicePromptSynthesizer.requireAvailable()
    }

    var updatedByName: [String: SwiftReparto.CastMember] = [:]
    var generatedCount = 0
    var keptCount = 0
    var skippedCount = 0

    // Process one character at a time, in cast order.
    for member in targetCast {
      // Respect existing prompts unless --force.
      let hasPrompt =
        member.voicePrompt.map { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? false
      if hasPrompt && !force {
        print("  \(member.character): kept existing voice prompt (use --force to regenerate)")
        keptCount += 1
        continue
      }

      // Gather this character's dialogue across all scripts.
      var evidence = CharacterDialogueEvidence()
      for script in scripts {
        evidence.merge(DialogueExtractor.evidence(for: member.character, in: script))
      }

      if evidence.isEmpty {
        print(
          "  \(member.character): no dialogue found in source material — skipping (nothing to describe)."
        )
        skippedCount += 1
        continue
      }

      if verbose {
        print(
          "[verbose] \(member.character): \(evidence.dialogue.count) line(s), \(evidence.parentheticals.count) delivery note(s) across \(evidence.blockCount) block(s)"
        )
      }

      if dryRun {
        let preview = VoicePromptSynthesizer.selectedDialogue(evidence.dialogue).prefix(3)
        print("  \(member.character): would generate from \(evidence.dialogue.count) line(s):")
        for line in preview { print("      \u{201C}\(line)\u{201D}") }
        continue
      }

      // Synthesize the voice prompt from the gathered evidence.
      let prompt: String
      do {
        prompt = try await VoicePromptSynthesizer.synthesize(
          character: member.character,
          gender: member.gender,
          language: member.language,
          projectTitle: frontMatter.title,
          projectDescription: frontMatter.description,
          genre: frontMatter.genre,
          evidence: evidence
        )
      } catch {
        print("  \(member.character): error — \(error.localizedDescription)")
        skippedCount += 1
        continue
      }

      var updated = member
      updated.voicePrompt = prompt
      updatedByName[member.character] = updated
      generatedCount += 1
      print("  \(member.character): \(prompt)")
    }

    print("")
    print("  Generated: \(generatedCount)")
    if keptCount > 0 { print("  Kept: \(keptCount)") }
    if skippedCount > 0 { print("  Skipped: \(skippedCount)") }

    if dryRun {
      print("\n(dry run — no model calls or file writes)")
      return
    }

    guard generatedCount > 0 else {
      print("\nNo voice prompts generated — \(cast) left unchanged.")
      return
    }

    // Merge updated members back into the full roster, preserving order and any
    // members outside the target filter, then write CAST.md through the one
    // serializer allowed to emit it (SwiftReparto's CastMarkdownParser).
    document.cast = roster.map { updatedByName[$0.character] ?? $0 }
    try castParser.write(document: document, to: castURL)
    print("\nWritten to \(castURL.path)")
  }
}
