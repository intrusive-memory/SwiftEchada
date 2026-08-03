import ArgumentParser
import Foundation
import SwiftProyecto
import SwiftReparto

/// `echada generate vox` — synthesize on-device voices for cast members from
/// their voice prompts in CAST.md.
///
/// ## The roster lives in CAST.md; PROJECT.md is read-only here
///
/// The cast is read from — and written back to — `CAST.md`, beside
/// `PROJECT.md`, through SwiftReparto's `CastMarkdownParser` (EC-12).
/// `PROJECT.md` is still consulted read-only for `title` and `tts.model`, but
/// its legacy `cast:` block is never touched. When `CAST.md` is absent this
/// command fails rather than creating it — only `echada generate cast` creates
/// the roster (EC-14).
public struct GenerateVoxCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "vox",
    abstract: "Generate on-device voices for cast members from their voice prompts in CAST.md.",
    discussion: """
      Consumes each cast member's `voicePrompt` in CAST.md and produces a `.vox` \
      voice file under `voices/` beside CAST.md, recorded under the member's \
      `voices.voxalta` in CAST.md (paths relative to CAST.md's directory).

      PROJECT.md is read-only here — `title` and `tts.model` only — and is never \
      modified. When CAST.md is absent this command fails — run \
      `echada generate cast` first to create it.

      Idempotency: members whose `.vox` already holds the requested variant \
      (TTS model + language) are skipped unless `--force-regenerate` is passed, \
      which regenerates voices even if `.vox` files already exist.

      Example:
          echada generate vox --language es --language en
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

  @Flag(name: .long, help: "Regenerate voices even if .vox files already exist.")
  public var forceRegenerate: Bool = false

  @Flag(name: .long, help: "Preview without writing any files.")
  public var dryRun: Bool = false

  @Flag(name: .long, help: "Show verbose output.")
  public var verbose: Bool = false

  @Option(
    name: .long,
    help:
      "TTS model variant for voice generation (0.6b, 1.7b). Defaults to tts.model from PROJECT.md, then 1.7b."
  )
  public var ttsModel: String?

  @Option(name: .long, help: "Generate voice for a single character (by name).")
  public var character: String?

  @Option(
    name: .long,
    help:
      "BCP-47 language code(s) for the reference sample (default: en). Repeat to cast multiple languages into one .vox (e.g. --language es --language en)."
  )
  public var language: [String] = []

  @Option(
    name: .long,
    help:
      "Accent or delivery directive applied to every character's voice prompt (e.g. \"slow southern drawl\"). Optional — omit for neutral delivery."
  )
  public var accent: String?

  public init() {}

  /// Normalizes the `--accent` flag: `nil` or whitespace-only → `nil`; otherwise trimmed.
  func resolvedAccent() -> String? {
    guard let raw = accent else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// Normalizes the `--language` flag into an explicit override list: lowercased,
  /// de-duplicated, order-preserving, with each code validated non-empty.
  ///
  /// Returns `[]` when the flag is absent — signalling "no global override," at
  /// which point each cast member is voiced in its OWN declared `language` (see
  /// `castingLanguages(for:explicitLanguages:)`). A non-empty result is applied
  /// uniformly to every member (the multi-embedding "casting loop" mechanism).
  func resolvedLanguages() throws -> [String] {
    guard !language.isEmpty else { return [] }
    var seen: Set<String> = []
    var result: [String] = []
    for raw in language {
      let code = raw.trimmingCharacters(in: .whitespaces).lowercased()
      guard !code.isEmpty else {
        throw ValidationError("--language values must be non-empty BCP-47 codes.")
      }
      if seen.insert(code).inserted { result.append(code) }
    }
    return result
  }

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
        "Cast file not found: \(castURL.path). `generate vox` reads the roster from \(cast) "
          + "and never creates it — run `echada generate cast` first.")
    }

    // PROJECT.md is read-only here: `title` and `tts.model` only (EC-12).
    let parser = ProjectMarkdownParser()
    let (frontMatter, _) = try parser.parse(fileURL: fileURL)

    // Resolve TTS model: CLI flag > PROJECT.md tts.model > default slug
    let effectiveTTSModel =
      ttsModel ?? frontMatter.tts?.model ?? CastVoiceGenerator.defaultModelSlug

    // Validate TTS model variant before any expensive work
    guard CastVoiceGenerator.supportedVariants.contains(effectiveTTSModel.lowercased()) else {
      throw ValidationError(
        "Unsupported TTS model variant '\(effectiveTTSModel)'. "
          + "Supported values: \(CastVoiceGenerator.supportedVariants.sorted().joined(separator: ", "))"
      )
    }

    let languages = try resolvedLanguages()

    let castParser = CastMarkdownParser()
    var document = try castParser.parse(fileURL: castURL)
    let roster = document.cast
    guard !roster.isEmpty else {
      throw ValidationError(
        "No cast members found in \(cast). Run `echada generate cast` to discover them.")
    }

    // Filter cast to a single character if requested
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

    print("Project: \(frontMatter.title)")
    print(
      "TTS model: \(effectiveTTSModel)\(ttsModel != nil ? "" : " (from \(frontMatter.tts?.model != nil ? "PROJECT.md" : "default"))")"
    )
    print(
      "Cast members: \(targetCast.count)\(character != nil ? " (filtered: \(character!))" : "")")
    let resolvedAccentValue = resolvedAccent()
    let accentSuffix = resolvedAccentValue.map { "  (accent: \($0))" } ?? ""
    let languagesDesc =
      languages.isEmpty
      ? "per-character (from \(cast) `language`, default en)"
      : languages.joined(separator: ", ")
    print("Languages: \(languagesDesc)\(accentSuffix)")
    if forceRegenerate { print("Force regenerate: yes") }
    print("")
    fflush(stdout)

    if dryRun {
      print("Cast voice prompts:")
      for member in targetCast {
        let desc = member.voicePrompt ?? "(empty — will skip)"
        print("  \(member.character): \(desc)")
      }
      if let accentValue = resolvedAccentValue {
        print("Accent: \(accentValue)")
      }
      print("\n(dry run — no voice generation or file writes)")
      return
    }

    // Generate voices
    print("Generating voices...")
    print("Loading VoxAlta models (this may take a moment)...")
    fflush(stdout)

    // `.vox` output lives in `voices/` beside CAST.md, and the paths recorded
    // in `voices.voxalta` resolve relative to CAST.md's directory (EC-16).
    let generator = CastVoiceGenerator(
      castDirectory: castURL.deletingLastPathComponent(),
      forceRegenerate: forceRegenerate,
      verbose: verbose,
      ttsModelVariant: effectiveTTSModel,
      languages: languages,
      accent: resolvedAccentValue
    )

    let genResult = try await generator.generate(cast: targetCast)

    print("  Generated: \(genResult.generatedCount)")
    print("  Skipped: \(genResult.skippedCount)")
    print("")

    for member in genResult.updatedCast {
      if member.voices.isEmpty {
        print("  \(member.character): (none)")
      } else {
        let voiceList = member.voices.map { "\($0.key):\($0.value.joined(separator: "/"))" }.joined(
          separator: ", ")
        print("  \(member.character): \(voiceList)")
      }
    }

    // Merge filtered results back into the full cast list
    let finalCast: [SwiftReparto.CastMember]
    if character != nil {
      let updatedByName = Dictionary(
        genResult.updatedCast.map { ($0.character, $0) },
        uniquingKeysWith: { _, last in last }
      )
      finalCast = roster.map { updatedByName[$0.character] ?? $0 }
    } else {
      finalCast = genResult.updatedCast
    }

    // Write the updated roster back to CAST.md through the one serializer
    // allowed to emit it (SwiftReparto's CastMarkdownParser).
    document.cast = finalCast
    try castParser.write(document: document, to: castURL)
    print("\nWritten to \(castURL.path)")
  }
}
