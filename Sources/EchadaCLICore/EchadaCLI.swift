import ArgumentParser
import Foundation
import SwiftProyecto

import enum SwiftEchada.SwiftEchada

public struct EchadaCLI: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "echada",
    abstract: "On-device voice generation for screenplay projects.",
    discussion: """
      `echada` turns a screenplay project into on-device voices. The default \
      command, `cast`, runs the whole pipeline end to end:

          PROJECT.md  →  cast  →  prompt  →  vox

      Bare `echada` (no subcommand) runs `cast`, which bootstraps a PROJECT.md \
      when one is absent, then discovers the cast, writes a `voicePrompt` for \
      each member, and synthesizes a `.vox` voice for each. Every stage is \
      idempotent, so re-running only fills the gaps.

      Individual stages are also available under the `generate` namespace — \
      `echada generate cast`, `echada generate prompt`, and `echada generate \
      vox` — for per-stage control. See `echada cast --help` for the full \
      pipeline and its cascading `--force`.
      """,
    version: SwiftEchada.version,
    subcommands: [
      VoiceCommand.self, CastCommand.self, PromptCommand.self, GenerateCommand.self,
      TestVoiceCommand.self,
    ],
    defaultSubcommand: CastCommand.self
  )

  public init() {}
}
