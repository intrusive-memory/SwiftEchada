import ArgumentParser
import Foundation
import SwiftProyecto

/// `echada generate vox` — synthesize on-device voices for cast members from
/// their voice prompts in PROJECT.md.
public struct GenerateVoxCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "vox",
    abstract: "Generate on-device voices for cast members from their voice prompts in PROJECT.md.",
    discussion: """
      Consumes each cast member's `voicePrompt` in PROJECT.md and produces a `.vox` \
      voice file, recorded under `voices.voxalta` in PROJECT.md.

      Idempotency: members whose `.vox` already holds the requested variant \
      (TTS model + language) are skipped unless `--force-regenerate` is passed, \
      which regenerates voices even if `.vox` files already exist.

      Example:
          echada generate vox --language es --language en
      """
  )

  @Option(name: .long, help: "Path to PROJECT.md file.")
  public var project: String = "PROJECT.md"

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

  /// Builds the PROJECT.md front matter to write back after voice generation,
  /// updating only the cast list while preserving **all** other content.
  ///
  /// Delegates to ``ProjectFrontMatter/withCast(_:)``, which carries every
  /// non-cast field — including `appSections`, the catch-all for unknown
  /// top-level keys such as `episodes_index` that the user maintains by hand.
  /// Extracted so the round-trip (parse → update cast → re-serialize) can be
  /// regression-tested offline without running voice generation (issue #44).
  static func updatedFrontMatter(
    preserving frontMatter: ProjectFrontMatter, cast: [CastMember]
  ) -> ProjectFrontMatter {
    frontMatter.withCast(cast)
  }

  public func run() async throws {
    let fileURL = URL(fileURLWithPath: project)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw ValidationError("Project file not found: \(project)")
    }
    let projectDir = fileURL.deletingLastPathComponent()
    let parser = ProjectMarkdownParser()
    let (frontMatter, body) = try parser.parse(fileURL: fileURL)

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

    guard let cast = frontMatter.cast, !cast.isEmpty else {
      throw ValidationError("No cast members found in \(project).")
    }

    // Filter cast to a single character if requested
    let targetCast: [CastMember]
    if let characterName = character {
      targetCast = cast.filter {
        $0.character.localizedCaseInsensitiveCompare(characterName) == .orderedSame
      }
      guard !targetCast.isEmpty else {
        throw ValidationError(
          "Character '\(characterName)' not found in cast. Available: \(cast.map(\.character).joined(separator: ", "))"
        )
      }
    } else {
      targetCast = cast
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
      ? "per-character (from PROJECT.md `language`, default en)"
      : languages.joined(separator: ", ")
    print("Languages: \(languagesDesc)\(accentSuffix)")
    if forceRegenerate { print("Force regenerate: yes") }
    print("")
    fflush(stdout)

    if dryRun {
      print("Cast voice prompts:")
      for member in targetCast {
        let desc = member.voiceDescription ?? "(empty — will skip)"
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

    let generator = CastVoiceGenerator(
      projectDirectory: projectDir,
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
    let finalCast: [CastMember]
    if character != nil {
      let updatedByName = Dictionary(
        genResult.updatedCast.map { ($0.character, $0) },
        uniquingKeysWith: { _, last in last }
      )
      finalCast = cast.map { updatedByName[$0.character] ?? $0 }
    } else {
      finalCast = genResult.updatedCast
    }

    // Write updated PROJECT.md.
    //
    // Route the write-back through `withCast(_:)` rather than reconstructing the
    // front matter field-by-field. The manual rebuild dropped every field it did
    // not explicitly copy — most damagingly `appSections`, the catch-all that
    // holds unknown top-level keys the user hand-maintains (e.g. `episodes_index`).
    // That silently deleted that content on every voice write-back (issue #44).
    // `withCast` preserves all non-cast fields verbatim, including `appSections`.
    let updatedFrontMatter = GenerateVoxCommand.updatedFrontMatter(
      preserving: frontMatter, cast: finalCast)

    let output = parser.generate(frontMatter: updatedFrontMatter, body: body)
    try output.write(to: fileURL, atomically: true, encoding: .utf8)
    print("\nWritten to \(project)")
  }
}
