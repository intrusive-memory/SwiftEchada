import ArgumentParser
import Foundation
import LlaveroCLI
import SwiftLlavero
import SwiftProyecto
import SwiftReparto

/// `echada cast` — the meta-orchestrator.
///
/// Running `echada cast` executes the whole production
/// pipeline end to end:
///
///     PROJECT.md + CAST.md  →  generate prompt  →  generate vox
///
/// Step 0 bootstraps a `PROJECT.md` when one is absent (no LLM — the scaffolding
/// is inferred heuristically from the surrounding directory via
/// `ProjectService.analyzeForGeneration(at:)`) and then ensures the `CAST.md`
/// roster beside it (seeded from a legacy `cast:` block when present; EC-15).
/// The two generative stages then run in order. Each is independently
/// idempotent — `generate prompt` fills only empty `voicePrompt`s and
/// `generate vox` skips `.vox` variants that already exist — so re-running
/// `echada cast` only fills the remaining gaps.
///
/// Echada does not discover cast members (EC-P11, 3.0.0). The roster comes
/// from `personaje cast-discover`, a legacy `cast:` block, or a person; an
/// empty roster stops the pipeline with that advice.
///
/// A single cascading `--force` fans out to every stage's own force flag; use
/// the standalone `echada generate <stage>` subcommands when per-stage control
/// is needed.
public struct CastCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "cast",
    abstract:
      "Run the voice pipeline: bootstrap PROJECT.md and CAST.md, then prompt → vox.",
    discussion: """
      Drives the whole \
      pipeline end to end:

          PROJECT.md + CAST.md  →  generate prompt  →  generate vox

      Step 0 — Bootstrap: if the `--project` file (default `PROJECT.md`) is \
      absent, a minimal PROJECT.md is scaffolded automatically from the \
      surrounding directory (inferred title, author, `episodesDir`, and \
      `filePattern`) with NO LLM involved. An existing project detected nearby \
      is left untouched. The inferred fields are plain YAML and freely editable \
      afterward. The `--cast` roster file (default CAST.md) is then ensured \
      beside PROJECT.md. An older PROJECT.md that still holds a `cast:` block \
      is migrated: the roster moves to CAST.md, the original is saved as \
      PROJECT.md.bak, and the block is removed. Otherwise an empty roster is \
      created; an existing roster is left untouched. Under `--dry-run` these \
      offline steps, migration included, still run for real.

      echada does not discover cast members. Build CAST.md from the \
      screenplays with `personaje cast-discover` (or by hand); an empty roster \
      stops the pipeline before any model runs.

      Step 1 — `generate prompt`: writes a `voicePrompt` for each cast member \
      from their dialogue, using the language model chosen by `--llm` (on-device by default).

      Step 2 — `generate vox`: synthesizes an on-device `.vox` voice for each \
      cast member from their `voicePrompt`.

      Idempotency: every stage skips already-completed work, so re-running only \
      fills the remaining gaps. A single cascading `--force` is forwarded to each \
      stage's own force flag (prompt overwrite, vox regenerate); for \
      per-stage control use the standalone `echada generate <stage>` subcommands.

      Cross-stage flags: `--cast` (roster filename, default CAST.md) forwards to \
      both stages; `--character` forwards to the prompt and vox stages; \
      `--llm` forwards to the prompt stage; \
      `--tts-model`, `--language`, and `--accent` forward to the vox stage. \
      `--dry-run` performs the offline bootstrap and migration steps but stops \
      before the model-backed prompt and vox stages.

      Example:
          echada cast
      """
  )

  @Option(name: .long, help: "Path to PROJECT.md file (created if absent).")
  public var project: String = "PROJECT.md"

  @Option(
    name: .long,
    help:
      "Filename of the cast roster (default: CAST.md; created if absent). A bare filename only — it always lives in --project's directory, so path separators are rejected. Forwarded to every stage."
  )
  public var cast: String = "CAST.md"

  @Option(
    name: .long,
    help: "Limit the prompt and vox stages to a single character (by name).")
  public var character: String?

  @Option(
    name: .long,
    help:
      "TTS model variant for the vox stage (0.6b, 1.7b). Defaults to tts.model from PROJECT.md, then 1.7b. Forwarded to `generate vox`."
  )
  public var ttsModel: String?

  @Option(
    name: .long,
    help:
      "BCP-47 language code(s) for the vox stage's reference sample (default: en). Repeat to cast multiple languages into one .vox (e.g. --language es --language en). Forwarded to `generate vox`."
  )
  public var language: [String] = []

  @Option(
    name: .long,
    help:
      "Accent or delivery directive applied to every character's voice in the vox stage (e.g. \"slow southern drawl\"). Forwarded to `generate vox`."
  )
  public var accent: String?

  @Option(
    name: .long,
    help:
      "Language model for the prompt stage: on-device (default), pcc, or any account:model set up with `echada auth login`. Forwarded to `generate prompt`."
  )
  public var llm: ModelReference = .onDevice

  @Option(
    name: .long,
    help:
      "Use this audition-pool index for every character instead of rotating per character. Forwarded to `generate vox`."
  )
  public var auditionVariant: Int?

  @Flag(
    name: .long,
    help:
      "Cascading force: overwrite existing voice prompts and regenerate existing .vox files. Fans out to every stage's own force flag."
  )
  public var force: Bool = false

  @Flag(
    name: .long,
    help:
      "Run the offline bootstrap and migration steps but stop before the model-backed prompt and vox stages."
  )
  public var dryRun: Bool = false

  @Flag(name: .long, help: "Show verbose output for every stage.")
  public var verbose: Bool = false

  public init() {}

  public func run() async throws {
    let fileURL = URL(fileURLWithPath: project)
    let projectDir = Self.resolveProjectDirectory(for: fileURL)

    // Step 0: ensure a PROJECT.md exists (bootstrap without an LLM when absent),
    // then ensure the CAST.md roster beside it (EC-15).
    try ensureProjectMarkdown(at: fileURL, projectDir: projectDir)
    // Bootstrap defers to a PROJECT.md already in this directory rather than
    // scaffolding a competing `--project` file; say so instead of silently
    // running against nothing.
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw ValidationError(
        "Project file not found: \(project). This directory already has a PROJECT.md; "
          + "pass --project PROJECT.md to use it.")
    }
    try ensureCastMarkdown(projectFile: fileURL, projectDir: projectDir)

    let rosterIsEmpty = try castRosterIsEmpty(projectDir: projectDir)

    if dryRun {
      if rosterIsEmpty { print("\n\(Self.emptyRosterAdvice(cast))") }
      print(
        "\n(dry run — stopping before the model stages: `generate prompt` and `generate vox`)")
      return
    }
    // echada no longer discovers cast (EC-P11), so an empty roster leaves the
    // model stages nothing to do.
    if rosterIsEmpty { throw ValidationError(Self.emptyRosterAdvice(cast)) }

    // Step 1: write a voicePrompt for each member (FoundationModels; see --llm).
    print("\n== Stage 1/2: generate prompt ==")
    fflush(stdout)
    var promptStage = GeneratePromptCommand()
    promptStage.project = project
    // Property wrappers on a directly-constructed command are only realized by
    // parsing or assignment — every property must be set before run() reads it.
    promptStage.cast = cast
    promptStage.character = character
    promptStage.llm = llm
    promptStage.force = force
    promptStage.dryRun = false
    promptStage.verbose = verbose
    try await promptStage.run()

    // Step 2: synthesize a .vox for each member (on-device MLX TTS).
    print("\n== Stage 2/2: generate vox ==")
    fflush(stdout)
    var voxStage = GenerateVoxCommand()
    voxStage.project = project
    // Same property-wrapper realization rule as above.
    voxStage.cast = cast
    voxStage.character = character
    voxStage.ttsModel = ttsModel
    voxStage.language = language
    voxStage.accent = accent
    voxStage.auditionVariant = auditionVariant
    voxStage.forceRegenerate = force
    voxStage.dryRun = false
    voxStage.verbose = verbose
    try await voxStage.run()

    print("\nPipeline complete.")
  }

  // MARK: - Bootstrap

  /// Ensures a PROJECT.md exists at `fileURL`, scaffolding one (without any LLM)
  /// when absent. An existing project detected nearby is left in place.
  private func ensureProjectMarkdown(at fileURL: URL, projectDir: URL) throws {
    // Already present at the requested path — nothing to do.
    if FileManager.default.fileExists(atPath: fileURL.path) {
      return
    }

    // Stay captive to the project's own directory: if a PROJECT.md already lives
    // here (e.g. `--project` pointed at a non-`PROJECT.md` filename), leave it in
    // place rather than scaffolding a competing one. Crucially, do NOT ascend to
    // parent directories — an unrelated PROJECT.md one level up (a sibling
    // fixture, a monorepo root) must not suppress bootstrapping the project the
    // caller explicitly asked for here.
    let siblingProjectMd = projectDir.appending(path: "PROJECT.md", directoryHint: .notDirectory)
    if siblingProjectMd.path != fileURL.path,
      FileManager.default.fileExists(atPath: siblingProjectMd.path)
    {
      if verbose {
        print("Detected existing project at \(siblingProjectMd.path) — leaving it in place.")
      }
      return
    }

    // Infer scaffolding heuristically from the surrounding directory. No LLM.
    // (Bootstrap writes even under `--dry-run`: the offline steps are the whole
    // point of the dry run.)
    let analysis = ProjectService.analyzeForGeneration(at: projectDir)
    let folderName = projectDir.lastPathComponent
    let title =
      analysis?.inferredTitle
      ?? (folderName.isEmpty ? "Untitled Project" : folderName)
    let episodesDir = Self.inferEpisodesDir(projectDir: projectDir)
    let filePattern = Self.inferFilePattern(from: analysis)

    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: title,
      author: NSFullUserName(),
      created: Date(),
      episodesDir: episodesDir,
      filePattern: filePattern
    )

    try ProjectMarkdownParser().write(frontMatter: frontMatter, body: "", to: fileURL)
    print("Bootstrapped \(project) (title: \"\(title)\", episodesDir: \(episodesDir)).")
  }

  /// Ensures the `--cast` roster file exists beside `PROJECT.md` (EC-15).
  ///
  /// A pre-v5 `PROJECT.md` is migrated first (``ProjectMigration``), which
  /// moves its legacy `cast:` block into the roster file. Otherwise an empty
  /// roster is created. An existing cast file is authoritative: migration only
  /// adds missing members and fills empty fields (EC-18).
  private func ensureCastMarkdown(projectFile: URL, projectDir: URL) throws {
    // Resolve (and validate) the --cast filename up front, so a bad override
    // fails before any stage runs. Same filename-only rule as the stages.
    let castURL = try CastFile.resolve(named: cast, in: projectDir)

    try ProjectMigration.migrateIfNeeded(projectURL: projectFile, castName: cast)

    guard !FileManager.default.fileExists(atPath: castURL.path) else { return }
    try CastMarkdownParser().write(document: CastDocument(cast: []), to: castURL)
    print("Bootstrapped \(cast) (empty roster).")
  }

  /// Whether the `--cast` roster exists and has no members. A missing roster
  /// is not "empty": the prompt stage reports that case itself.
  private func castRosterIsEmpty(projectDir: URL) throws -> Bool {
    let castURL = try CastFile.resolve(named: cast, in: projectDir)
    guard FileManager.default.fileExists(atPath: castURL.path) else { return false }
    return try CastMarkdownParser().parse(fileURL: castURL).cast.isEmpty
  }

  static func emptyRosterAdvice(_ cast: String) -> String {
    "\(cast) has no cast members. Build it from the screenplays with "
      + "`personaje cast-discover`, or add members by hand, then run `echada cast` again."
  }

  /// Resolves the project directory for analysis/discovery. A relative
  /// `--project` with no directory component (e.g. the default `PROJECT.md`)
  /// resolves against the current working directory so directory-based APIs
  /// receive a concrete path.
  private static func resolveProjectDirectory(for fileURL: URL) -> URL {
    let dir = fileURL.deletingLastPathComponent()
    if dir.path.isEmpty || dir.path == "." {
      return URL(
        fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
    }
    return dir
  }

  /// Picks a sensible `episodesDir` for a scaffolded project: `episodes` when a
  /// subdirectory of that name exists, otherwise `.` so the pipeline searches
  /// the whole project tree for scripts.
  private static func inferEpisodesDir(projectDir: URL) -> String {
    let episodesSub = projectDir.appending(path: "episodes", directoryHint: .isDirectory)
    var isDir: ObjCBool = false
    if FileManager.default.fileExists(atPath: episodesSub.path, isDirectory: &isDir),
      isDir.boolValue
    {
      return "episodes"
    }
    return "."
  }

  /// Derives the screenplay `filePattern` for a scaffolded project from the
  /// directory analysis, keeping only globs whose extension the pipeline can
  /// actually parse as a screenplay (so a `.txt`/`.md` project is bootstrapped
  /// with a pattern `generate prompt` can read dialogue from).
  /// Falls back to `*.fountain` when the analysis surfaces no parseable scripts.
  private static func inferFilePattern(from analysis: ProjectAnalysis?) -> FilePattern {
    let scriptPatterns = (analysis?.discoveredFiles ?? [])
      .filter { SourceMaterialLocator.isParseableScriptPattern($0) }
      .sorted()
    guard !scriptPatterns.isEmpty else { return FilePattern("*.fountain") }
    return FilePattern(scriptPatterns)
  }
}
