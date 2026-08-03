import ArgumentParser
import Foundation
import SwiftProyecto

import enum SwiftEchada.SwiftEchada

public struct EchadaCLI: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "echada",
    abstract: "On-device voice generation for screenplay projects.",
    discussion: """
      `echada` turns a screenplay project into on-device voices. Run a \
      subcommand to do work; bare `echada` (no subcommand) prints this help.

      The `cast` command runs the whole pipeline end to end:

          PROJECT.md  →  cast  →  prompt  →  vox

      `echada cast` bootstraps a PROJECT.md when one is absent, then discovers \
      the cast, writes a `voicePrompt` for each member, and synthesizes a \
      `.vox` voice for each. Every stage is idempotent, so re-running only \
      fills the gaps.

      Individual stages are also available under the `generate` namespace — \
      `echada generate cast`, `echada generate prompt`, and `echada generate \
      vox` — for per-stage control. See `echada cast --help` for the full \
      pipeline and its cascading `--force`.

      Read-only checks live under the `verify` namespace — `echada verify \
      cast` compares CAST.md against the legacy `cast:` block in PROJECT.md \
      and exits non-zero on any divergence, without writing anything.
      """,
    version: EchadaCLI.versionReport,
    subcommands: [
      VoiceCommand.self, CastCommand.self, GenerateCommand.self,
      VerifyCommand.self, TestVoiceCommand.self,
    ]
  )

  /// What `echada --version` prints: the tool version, followed by the
  /// dependency versions actually compiled into this binary.
  ///
  /// The dependency table is generated at build time from `Package.swift` and
  /// `Package.resolved` (see `Scripts/generate-dependency-versions.py`). It is
  /// reported here because `Package.resolved` is gitignored, so a shipped
  /// binary is otherwise the only artifact that knows what it links against —
  /// and reading it out of a binary is far harder than printing it.
  static var versionReport: String {
    SwiftEchada.version + "\n" + DependencyVersions.report()
  }

  public init() {}
}
