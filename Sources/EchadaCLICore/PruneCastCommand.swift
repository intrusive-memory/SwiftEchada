import ArgumentParser
import Foundation

/// `echada prune cast` — strip the legacy `cast:` block from `PROJECT.md`
/// once the roster lives in `CAST.md` (EC-10).
///
/// ## Only the `cast:` line span is touched
///
/// The excision goes through ``ProjectCastWriteBack/applying(cast:to:using:)``
/// with an empty roster — the same surgical splice the `generate` stages use
/// for write-back, whose contract is that an empty array removes the block.
/// The front matter is **never** re-emitted field-by-field, so every other
/// byte of the file survives verbatim: key ordering, comments, spacing,
/// `introFile`/`outroFile`, `tts`, and nested unknown structures such as
/// `episodes_index` — the exact keys the issue-#44/#55 failure class lost.
///
/// ## Two gates guard the removal
///
/// 1. `CAST.md` must exist beside `PROJECT.md` — pruning before the roster
///    has a new home would destroy it.
/// 2. The Sortie 5 verification (`echada verify cast`) must pass: no
///    divergence between the two rosters, and no dangling `.vox` pointer.
///
/// If either gate fails the command exits non-zero, prints an actionable
/// message, and writes nothing.
///
/// ## Idempotent and explicit-only
///
/// A `PROJECT.md` with no `cast:` block is already pruned: the command says
/// so and exits 0 without writing, so consecutive runs are safe. No other
/// echada command ever invokes this one — pruning only happens when the user
/// asks for it by name.
public struct PruneCastCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "cast",
    abstract:
      "Strip the migrated legacy `cast:` block from PROJECT.md (explicit, gated on verify).",
    discussion: """
      Removes the legacy `cast:` block from PROJECT.md after the roster has moved \
      to CAST.md. Only the `cast:` line span is excised — every other byte of the \
      file (key ordering, comments, spacing, `introFile`/`outroFile`, `tts`, and \
      nested structures such as `episodes_index`) is preserved verbatim, because \
      the removal reuses the same surgical splice as the generate stages rather \
      than re-emitting the front matter field-by-field.

      Two gates guard the removal: CAST.md must exist beside PROJECT.md, and the \
      `echada verify cast` check must pass — no divergence between the two \
      rosters and no dangling `.vox` pointer. If either gate fails, the command \
      exits non-zero and writes nothing.

      A PROJECT.md that carries no `cast:` block is already pruned: the command \
      reports that and exits 0 without writing, so repeated runs are safe. Pass \
      `--dry-run` to print the exact removal diff without touching the file. No \
      other echada command ever invokes this one — pruning is always explicit.

      Example:
          echada prune cast --project PROJECT.md
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
    help: "Print the exact removal diff without writing PROJECT.md.")
  public var dryRun: Bool = false

  public init() {}

  public func run() async throws {
    let projectURL = URL(fileURLWithPath: project)
    guard FileManager.default.fileExists(atPath: projectURL.path) else {
      throw ValidationError("Project file not found: \(project)")
    }
    let projectDir = projectURL.deletingLastPathComponent()
    let castURL = try GenerateCastCommand.resolveCastFile(named: cast, in: projectDir)

    // Gate 1: the roster's new home must exist before its old one is erased.
    guard FileManager.default.fileExists(atPath: castURL.path) else {
      throw ValidationError(
        "Cast file not found: \(castURL.path). `prune cast` removes the legacy `cast:` block "
          + "only after the roster lives in \(cast) — run `echada generate cast` to create it, "
          + "then `echada verify cast` to confirm the rosters agree, before pruning.")
    }

    let original = try String(contentsOf: projectURL, encoding: .utf8)

    // The excision itself: ProjectCastWriteBack's surgical splice with an
    // empty roster removes exactly the `cast:` line span and nothing else.
    let pruned = try ProjectCastWriteBack.applying(cast: [], to: original)

    // Idempotency: no `cast:` block means nothing to do. This is checked
    // before the verification gate because a previous successful prune leaves
    // PROJECT.md without a legacy roster — which verification would flag as
    // wholesale membership divergence, not as success.
    guard pruned != original else {
      print(
        "No legacy `cast:` block in \(projectURL.lastPathComponent) — nothing to prune.")
      return
    }

    // Gate 2: the Sortie 5 verification must pass before anything is removed.
    let divergences = try VerifyCastCommand.collectDivergences(
      projectURL: projectURL, castName: cast)
    guard divergences.isEmpty else {
      var diagnostics =
        "Refusing to prune: \(divergences.count) divergence(s) between \(cast) and "
        + "\(projectURL.lastPathComponent). Resolve them (see `echada verify cast "
        + "--project \(project)`) and re-run:\n"
      for divergence in divergences {
        diagnostics += "  - \(divergence.message)\n"
      }
      FileHandle.standardError.write(Data(diagnostics.utf8))
      throw ExitCode(1)
    }

    let diff = Self.removalDiff(
      original: original, pruned: pruned, label: projectURL.lastPathComponent)

    if dryRun {
      print("Would remove the legacy `cast:` block from \(projectURL.lastPathComponent):\n")
      print(diff)
      print("(dry run — no file writes)")
      return
    }

    try pruned.write(to: projectURL, atomically: true, encoding: .utf8)
    print("Removed the legacy `cast:` block from \(projectURL.lastPathComponent):\n")
    print(diff)
    print("The roster lives in \(cast).")
  }

  // MARK: - Diff rendering

  /// Renders the exact line diff between `original` and `pruned` in unified
  /// style. Because the excision removes one contiguous line span, the diff
  /// is a single hunk of `-` lines (an empty diff when the texts match).
  static func removalDiff(original: String, pruned: String, label: String) -> String {
    let originalLines = original.components(separatedBy: "\n")
    let prunedLines = pruned.components(separatedBy: "\n")

    var prefix = 0
    while prefix < originalLines.count && prefix < prunedLines.count
      && originalLines[prefix] == prunedLines[prefix]
    {
      prefix += 1
    }
    var suffix = 0
    while suffix < originalLines.count - prefix && suffix < prunedLines.count - prefix
      && originalLines[originalLines.count - 1 - suffix]
        == prunedLines[prunedLines.count - 1 - suffix]
    {
      suffix += 1
    }

    let removed = originalLines[prefix..<(originalLines.count - suffix)]
    let added = prunedLines[prefix..<(prunedLines.count - suffix)]
    guard !removed.isEmpty || !added.isEmpty else { return "(no changes)" }

    var out = "--- \(label)\n+++ \(label) (pruned)\n"
    out +=
      "@@ -\(prefix + 1),\(removed.count) +\(added.isEmpty ? prefix : prefix + 1),\(added.count) @@\n"
    for line in removed { out += "-\(line)\n" }
    for line in added { out += "+\(line)\n" }
    return out
  }
}
