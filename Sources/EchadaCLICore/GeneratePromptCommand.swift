import ArgumentParser
import Foundation
import FoundationModels
import LlaveroCLI
import SwiftLlavero
import SwiftProyecto
import SwiftReparto

/// `echada generate prompt` — examine the screenplay source material and write
/// a `voicePrompt` for each cast member in CAST.md.
///
/// This is the inverse of `generate vox`: where `vox` consumes each member's
/// `voicePrompt` to lock a `.vox`, `prompt` reads the episode scripts, gathers
/// what each character actually says (and how), and asks a FoundationModels
/// language model (on-device by default, or Private Cloud Compute) to write the voice-design brief that `vox` will later use.
///
/// ## The roster lives in CAST.md; PROJECT.md is read-only here
///
/// The cast is read from — and written back to — `CAST.md`, beside
/// `PROJECT.md`, through SwiftReparto's `CastMarkdownParser` (EC-12).
/// `PROJECT.md` is still consulted read-only for `title`, `description`,
/// `genre`, `episodesDir`, and `filePattern`, but its legacy `cast:` block is
/// never touched. When `CAST.md` is absent this command fails rather than
/// creating it — the roster comes from `personaje cast-discover` (EC-P11).
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
      `voicePrompt` per member — written by a language model from the gathered \
      dialogue evidence. `--llm on-device` (the default) keeps everything on the Mac; \
      `--llm pcc` uses Apple Private Cloud Compute (no API key); `--llm \
      anthropic:claude-sonnet-5-5` (or any account configured with `echada auth \
      login`) uses that provider.

      The roster is read from, and written back to, CAST.md (beside PROJECT.md); \
      PROJECT.md is read for `title`, `episodesDir`, and `filePattern`; an older \
      PROJECT.md that still holds a `cast:` block is first migrated into CAST.md \
      (original saved as PROJECT.md.bak). When CAST.md is absent this command \
      fails — build it first with `personaje cast-discover`.

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

  @Option(
    name: .long,
    help:
      "Language model that writes the voice prompts: on-device (default; nothing leaves the Mac), pcc (Apple Private Cloud Compute), or any account:model set up with `echada auth login` (e.g. anthropic:claude-sonnet-5-5). Off-device models receive the characters' dialogue."
  )
  public var llm: ModelReference = .onDevice

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
    let castURL = try CastFile.resolve(named: cast, in: projectDir)

    // A pre-v5 project still carries its roster in PROJECT.md; move it to
    // CAST.md before this stage reads anything.
    try ProjectMigration.migrateIfNeeded(projectURL: fileURL, castName: cast, dryRun: dryRun)

    // EC-14: the roster must already exist — this command never creates it.
    guard FileManager.default.fileExists(atPath: castURL.path) else {
      throw ValidationError(
        "Cast file not found: \(castURL.path). `generate prompt` reads the roster from \(cast) "
          + "and never creates it — build it first with `personaje cast-discover`.")
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
        "No cast members found in \(cast). Build the roster with `personaje cast-discover`.")
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
    print("Language model: \(llm)")
    if !LanguageModelResolver.isOnDevice(llm) {
      print("  Note: character dialogue is sent to this model's provider.")
    }
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

    // Resolve the model once, failing fast before any per-character work
    // (skipped in a dry run, which never calls the model).
    let model: (any LanguageModel)? = dryRun ? nil : try await LanguageModelResolver.resolve(llm)

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

      guard let model else {
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
          evidence: evidence,
          model: model
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
