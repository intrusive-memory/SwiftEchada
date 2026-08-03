import ArgumentParser
import Foundation

/// `echada prune` — container for the destructive cleanup steps of the cast
/// migration (EC-10).
///
/// Everything under `prune` removes legacy data whose migrated replacement
/// already exists, and refuses to run until the matching `echada verify` gate
/// passes. Nothing here is ever invoked by another command — pruning happens
/// only when the user types it explicitly.
///
/// This container has no default subcommand — running `echada prune` with no
/// arguments prints help listing the available cleanups rather than silently
/// picking one.
public struct PruneCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "prune",
    abstract: "Remove migrated legacy data from project files (explicit, gated on verify).",
    discussion: """
      Container for the destructive cleanup steps of the cast migration. Each \
      subcommand removes legacy data that has already moved to its new home, and \
      refuses to run until the corresponding `echada verify` gate passes. No \
      other command ever invokes anything under `prune` — these cleanups only \
      run when asked for explicitly.

      - `prune cast` strips the legacy `cast:` block from PROJECT.md once the \
        roster lives in CAST.md and `echada verify cast` reports no divergence. \
        Every byte of PROJECT.md outside the `cast:` block is preserved verbatim.

      Example:
          echada prune cast --project PROJECT.md
      """,
    subcommands: [PruneCastCommand.self]
  )

  public init() {}
}
