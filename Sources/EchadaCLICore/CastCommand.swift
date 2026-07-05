import ArgumentParser
import Foundation
import SwiftProyecto

/// `echada cast` — the meta-orchestrator and default subcommand.
///
/// Running bare `echada` (or `echada cast`) executes the whole production
/// pipeline end to end:
///
///     PROJECT.md  →  generate cast  →  generate prompt  →  generate vox
///
/// Step 0 bootstraps a `PROJECT.md` when one is absent (no LLM — the scaffolding
/// is inferred heuristically from the surrounding directory via
/// `ProjectService.analyzeForGeneration(at:)`). The three generative stages are
/// then invoked in order. Each stage is independently idempotent — `generate
/// cast` adds only newly-discovered characters, `generate prompt` fills only
/// empty `voicePrompt`s, and `generate vox` skips `.vox` variants that already
/// exist — so re-running `echada cast` only fills the remaining gaps.
///
/// A single cascading `--force` fans out to every stage's own force flag; use
/// the standalone `echada generate <stage>` subcommands when per-stage control
/// is needed.
public struct CastCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "cast",
    abstract:
      "Run the full production pipeline: bootstrap PROJECT.md, then cast → prompt → vox.",
    discussion: """
      The default command. Bare `echada` runs this. It drives the whole \
      pipeline end to end:

          PROJECT.md  →  generate cast  →  generate prompt  →  generate vox

      Step 0 — Bootstrap: if the `--project` file (default `PROJECT.md`) is \
      absent, a minimal PROJECT.md is scaffolded automatically from the \
      surrounding directory (inferred title, author, `episodesDir`, and \
      `filePattern`) with NO LLM involved. An existing project detected nearby \
      is left untouched. The inferred fields are plain YAML and freely editable \
      afterward.

      Step 1 — `generate cast`: heuristically discovers character names from the \
      screenplay source and merges them into PROJECT.md's `cast:` list.

      Step 2 — `generate prompt`: writes a `voicePrompt` for each cast member \
      from their dialogue, using the on-device Foundation Model.

      Step 3 — `generate vox`: synthesizes an on-device `.vox` voice for each \
      cast member from their `voicePrompt`.

      Idempotency: every stage skips already-completed work, so re-running only \
      fills the remaining gaps. A single cascading `--force` is forwarded to each \
      stage's own force flag (cast re-sync, prompt overwrite, vox regenerate); for \
      per-stage control use the standalone `echada generate <stage>` subcommands.

      Cross-stage flags: `--character` forwards to the prompt and vox stages; \
      `--tts-model`, `--language`, and `--accent` forward to the vox stage. \
      `--dry-run` performs the offline bootstrap and cast-discovery steps (writing \
      the discovered cast to PROJECT.md) but stops before the model-backed prompt \
      and vox stages.

      Example:
          echada cast
      """
  )

  @Option(name: .long, help: "Path to PROJECT.md file (created if absent).")
  public var project: String = "PROJECT.md"

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

  @Flag(
    name: .long,
    help:
      "Cascading force: re-sync the cast list, overwrite existing voice prompts, and regenerate existing .vox files. Fans out to every stage's own force flag."
  )
  public var force: Bool = false

  @Flag(
    name: .long,
    help:
      "Run the offline bootstrap + cast-discovery steps but stop before the model-backed prompt and vox stages."
  )
  public var dryRun: Bool = false

  @Flag(name: .long, help: "Show verbose output for every stage.")
  public var verbose: Bool = false

  public init() {}

  public func run() async throws {
    let fileURL = URL(fileURLWithPath: project)
    let projectDir = Self.resolveProjectDirectory(for: fileURL)

    // Step 0: ensure a PROJECT.md exists (bootstrap without an LLM when absent).
    try ensureProjectMarkdown(at: fileURL, projectDir: projectDir)

    // Step 1: discover cast from the screenplay source (offline, heuristic).
    print("\n== Stage 1/3: generate cast ==")
    fflush(stdout)
    var castStage = GenerateCastCommand()
    castStage.project = project
    castStage.force = force
    castStage.dryRun = false  // cast is offline/cheap; run it for real so the
    // discovered cast is written before the model stages.
    castStage.verbose = verbose
    try await castStage.run()

    if dryRun {
      print(
        "\n(dry run — stopping before the model stages: `generate prompt` and `generate vox`)")
      return
    }

    // Step 2: write a voicePrompt for each member (on-device Foundation Model).
    print("\n== Stage 2/3: generate prompt ==")
    fflush(stdout)
    var promptStage = GeneratePromptCommand()
    promptStage.project = project
    promptStage.character = character
    promptStage.force = force
    promptStage.dryRun = false
    promptStage.verbose = verbose
    try await promptStage.run()

    // Step 3: synthesize a .vox for each member (on-device MLX TTS).
    print("\n== Stage 3/3: generate vox ==")
    fflush(stdout)
    var voxStage = GenerateVoxCommand()
    voxStage.project = project
    voxStage.character = character
    voxStage.ttsModel = ttsModel
    voxStage.language = language
    voxStage.accent = accent
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

    // A project already exists nearby (e.g. in the parent directory) — leave it
    // in place rather than scaffolding a competing one (OQ-3).
    if let existing = ProjectDiscovery().findProjectMd(from: projectDir) {
      if verbose {
        print("Detected existing project at \(existing.path) — leaving it in place.")
      }
      return
    }

    // Infer scaffolding heuristically from the surrounding directory. No LLM.
    // (Bootstrap writes even under `--dry-run`: the offline steps are the whole
    // point of the dry run, and the cast stage needs a project to write into.)
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
  /// with a pattern the immediately-following `generate cast` will match).
  /// Falls back to `*.fountain` when the analysis surfaces no parseable scripts.
  private static func inferFilePattern(from analysis: ProjectAnalysis?) -> FilePattern {
    let scriptPatterns = (analysis?.discoveredFiles ?? [])
      .filter { SourceMaterialLocator.isParseableScriptPattern($0) }
      .sorted()
    guard !scriptPatterns.isEmpty else { return FilePattern("*.fountain") }
    return FilePattern(scriptPatterns)
  }
}
