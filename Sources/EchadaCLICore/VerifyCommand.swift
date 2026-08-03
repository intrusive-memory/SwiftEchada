import ArgumentParser
import Foundation

/// `echada verify` — container for the read-only verification gates (EC-9).
///
/// Verification commands report, and never fix: they compare artifacts,
/// print divergences, and exit non-zero when something disagrees, so a CI
/// job or a rollout loop can gate on them. No file is ever written.
///
/// This container has no default subcommand — running `echada verify` with
/// no arguments prints help listing the available checks rather than
/// silently picking one.
public struct VerifyCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "verify",
    abstract: "Report-only verification gates for the cast migration (never writes).",
    discussion: """
      Container for read-only verification checks. Each check compares project \
      artifacts, reports every divergence it finds, and exits non-zero when \
      anything disagrees — so it can gate CI or a rollout loop. Nothing is ever \
      fixed or written; these commands are the human gate.

      - `verify cast` compares a project's CAST.md roster against the legacy \
        `cast:` block still present in its PROJECT.md, and checks that every \
        `.vox` voice pointer in CAST.md resolves to a real file on disk.

      Example:
          echada verify cast --project PROJECT.md
      """,
    subcommands: [VerifyCastCommand.self]
  )

  public init() {}
}
