import ArgumentParser
import Foundation

/// `echada generate` — container for the individual generative pipeline
/// stages (`cast`, `prompt`, `vox`).
///
/// Each stage can be run standalone for fine-grained control, or in sequence
/// to move a project from raw screenplay source to fully-voiced cast:
/// `generate cast` discovers characters, `generate prompt` writes each
/// member's voice-design brief, and `generate vox` synthesizes the `.vox`
/// voice file from that brief. The top-level `echada cast` command runs all
/// three in order as a single pipeline.
///
/// This container has no default subcommand — running `echada generate` with
/// no arguments prints help listing the three stages rather than silently
/// picking one.
public struct GenerateCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "generate",
    abstract: "Run an individual stage of the cast generation pipeline (cast, prompt, vox).",
    discussion: """
      Container for the three generative pipeline stages, each of which can be run \
      standalone for fine-grained control over a single step:

      - `generate cast`   discovers cast members from the screenplay source and merges \
        them into PROJECT.md.
      - `generate prompt` examines the source material and writes a `voicePrompt` for \
        each cast member.
      - `generate vox`    synthesizes an on-device `.vox` voice file from each member's \
        `voicePrompt`.

      Run them in order (cast → prompt → vox) to take a project from raw screenplay \
      source to fully-voiced cast, or run `echada cast` to execute the whole pipeline \
      in one step.

      Example:
          echada generate cast --project PROJECT.md
      """,
    subcommands: [GenerateCastCommand.self, GeneratePromptCommand.self, GenerateVoxCommand.self]
  )

  public init() {}
}
