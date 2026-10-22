import ArgumentParser
import Foundation

/// `echada generate` — container for the individual generative pipeline
/// stages (`prompt`, `vox`).
///
/// Each stage can be run standalone for fine-grained control, or in sequence:
/// `generate prompt` writes each member's voice-design brief and
/// `generate vox` synthesizes the `.vox` voice file from that brief. The
/// top-level `echada cast` command runs both in order as a single pipeline.
/// Cast discovery (`generate cast`) was removed in 3.0.0: build CAST.md with
/// `personaje cast-discover`.
///
/// This container has no default subcommand — running `echada generate` with
/// no arguments prints help listing the stages rather than silently picking
/// one.
public struct GenerateCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "generate",
    abstract: "Run an individual stage of the voice pipeline (prompt, vox).",
    discussion: """
      Container for the two generative pipeline stages, each of which can be run \
      standalone for fine-grained control over a single step:

      - `generate prompt` examines the source material and writes a `voicePrompt` for \
        each cast member in CAST.md.
      - `generate vox`    synthesizes an on-device `.vox` voice file from each member's \
        `voicePrompt`.

      Run them in order (prompt → vox), or run `echada cast` to execute both in one \
      step. The cast roster itself comes from `personaje cast-discover` (echada no \
      longer discovers characters).

      Example:
          echada generate prompt --project PROJECT.md
      """,
    subcommands: [GeneratePromptCommand.self, GenerateVoxCommand.self]
  )

  public init() {}
}
