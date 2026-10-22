import ArgumentParser
import Foundation
import SwiftReparto

/// `echada migrate` — one-time moves of echada's own assets.
public struct MigrateCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "migrate",
    abstract: "Move existing voice assets to where echada 3.0 writes them.",
    subcommands: [MigrateVoicesCommand.self]
  )

  public init() {}
}

/// `echada migrate voices` (EC-26).
public struct MigrateVoicesCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "voices",
    abstract: "Move each member's .vox into its character record (dry run unless --apply).",
    discussion: """
      For each CAST.md member whose `voices.voxalta` names a file, plans a move \
      to `<bundle>/voice/<NAME>.vox` when the member has a `manifest:`, \
      otherwise to `characters/<NAME>.dossier/voice/<NAME>.vox` (PROJECT.md \
      `personaje.charactersDir` overrides `characters`).

      Without --apply this prints the plan and writes nothing, and also lists \
      `.vox` files in a legacy `voices/` folder that no member points at. Paths \
      outside the project folder (absolute or `../`, e.g. common-voices) are \
      skipped.

      --apply copies each file and checks its SHA-256, rewrites every pointer in \
      one CAST.md write, re-reads CAST.md to check every new pointer, and only \
      then removes the old files. If any step fails, the copies are removed and \
      CAST.md is restored. It refuses to run when a name isn't canonical (run \
      `reparto canonicalize`), when two members would share a path, or when a \
      destination already exists with different contents. It never touches \
      manifest.json.

      Example:
          echada migrate voices
          echada migrate voices --apply
      """
  )

  @Option(name: .long, help: "Path to PROJECT.md.")
  public var project: String = "PROJECT.md"

  @Option(name: .long, help: "Filename of the cast roster beside PROJECT.md.")
  public var cast: String = "CAST.md"

  @Flag(name: .long, help: "Perform the moves. Without it, only the plan is printed.")
  public var apply: Bool = false

  public init() {}

  public func run() async throws {
    let projectURL = URL(fileURLWithPath: project)
    guard FileManager.default.fileExists(atPath: projectURL.path) else {
      throw ValidationError("Project file not found: \(project)")
    }
    let castURL = try CastFile.resolve(named: cast, in: projectURL.deletingLastPathComponent())
    guard FileManager.default.fileExists(atPath: castURL.path) else {
      throw ValidationError("\(cast) not found beside \(project).")
    }
    let charactersDir = try PersonajeSettings.read(fileURL: projectURL).resolvedCharactersDir
    let plan = try VoiceMigration.plan(castURL: castURL, charactersDir: charactersDir)

    for move in plan.moves {
      print("  \(move.character): \(move.from) → \(move.to)")
    }
    for name in plan.alreadyInPlace { print("  \(name): already in place") }
    for skip in plan.skips { print("  \(skip.character): skipped \(skip.path) (\(skip.reason))") }
    for blocker in plan.blockers { print("  ✗ \(blocker.character): \(blocker.reason)") }
    if !plan.strays.isEmpty {
      print("\nIn voices/ but not named by any member:")
      for stray in plan.strays { print("  \(stray)") }
    }
    if plan.moves.isEmpty && plan.blockers.isEmpty {
      print("Nothing to move.")
    }

    guard apply else {
      if !plan.moves.isEmpty { print("\n(dry run — re-run with --apply to move these)") }
      if !plan.canApply { throw ExitCode.failure }
      return
    }
    try VoiceMigration.apply(plan, castURL: castURL)
    print("\nMoved \(plan.moves.count) voice(s); \(cast) updated.")
  }
}
