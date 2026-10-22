import ArgumentParser
import Foundation
import Testing

@testable import EchadaCLICore

/// Offline wiring/help coverage (R-TEST-3) for the restructured command tree:
///
///     echada
///     ├── generate
///     │   ├── prompt
///     │   └── vox
///     ├── cast      (pipeline orchestrator)
///     ├── voice
///     ├── auth      (SwiftLlavero)
///     └── test-voice (hidden)
///
/// These tests guard against silent doc/wiring drift: the root has no default
/// subcommand (bare `echada` prints help), the shape of `.subcommands` at both
/// the root and the
/// `generate` container, and every restructure-related command's non-empty
/// `abstract`/`discussion` (each of which must actually describe that
/// command's inputs/outputs, not just be present). Everything here is a pure
/// metadata/parse check -- no process spawn, no model call.
@Suite("CLI wiring + help — offline (R-TEST-3)")
struct CLIWiringTests {

  // MARK: - Root wiring

  @Test("EchadaCLI has no default subcommand, so bare `echada` prints help")
  func rootHasNoDefaultSubcommand() {
    #expect(EchadaCLI.configuration.defaultSubcommand == nil)
  }

  @Test("EchadaCLI.subcommands still contains cast (invoked explicitly, not as default)")
  func rootSubcommandsContainCast() {
    let identifiers = Set(EchadaCLI.configuration.subcommands.map(ObjectIdentifier.init))
    #expect(identifiers.contains(ObjectIdentifier(CastCommand.self)))
  }

  @Test("EchadaCLI.subcommands contains generate and voice")
  func rootSubcommandsContainGenerateAndVoice() {
    let names = Set(
      EchadaCLI.configuration.subcommands.map {
        $0.configuration.commandName ?? String(describing: $0)
      })
    #expect(names.contains("generate"))
    #expect(names.contains("voice"))
    // Also confirm by identity, not just by name string.
    let identifiers = Set(EchadaCLI.configuration.subcommands.map(ObjectIdentifier.init))
    #expect(identifiers.contains(ObjectIdentifier(GenerateCommand.self)))
    #expect(identifiers.contains(ObjectIdentifier(VoiceCommand.self)))
  }

  @Test("verify and prune are gone: migration is automatic in 2.0")
  func rootHasNoMigrationVerbs() {
    let names = Set(
      EchadaCLI.configuration.subcommands.map {
        $0.configuration.commandName ?? String(describing: $0)
      })
    #expect(!names.contains("verify"))
    #expect(!names.contains("prune"))
  }

  // MARK: - `generate` container wiring

  @Test("GenerateCommand's subcommands are exactly prompt/vox, with no default")
  func generateContainerSubcommandsExactlyPromptVox() {
    #expect(GenerateCommand.configuration.defaultSubcommand == nil)

    let names = GenerateCommand.configuration.subcommands.map {
      $0.configuration.commandName ?? String(describing: $0)
    }
    #expect(Set(names) == ["prompt", "vox"])
    #expect(names.count == 2)  // exactly two -- `generate cast` was removed in 3.0.0 (EC-P11)

    let identifiers = Set(GenerateCommand.configuration.subcommands.map(ObjectIdentifier.init))
    #expect(
      identifiers == [
        ObjectIdentifier(GeneratePromptCommand.self),
        ObjectIdentifier(GenerateVoxCommand.self),
      ])
  }

  // MARK: - Non-empty abstract/discussion, mentioning inputs/outputs

  /// Every command touched by the restructure must document itself: a
  /// non-empty `abstract`, a non-empty `discussion`, and that discussion must
  /// actually name the command's input and output (not just be prose).
  @Test(
    "Every restructure command has non-empty abstract/discussion mentioning its inputs/outputs",
    arguments: [
      (
        name: "echada", abstract: EchadaCLI.configuration.abstract,
        discussion: EchadaCLI.configuration.discussion,
        mustMention: ["PROJECT.md", "cast", "prompt", "vox"]
      ),
      (
        name: "cast (orchestrator)", abstract: CastCommand.configuration.abstract,
        discussion: CastCommand.configuration.discussion,
        mustMention: [
          "PROJECT.md", "CAST.md", "personaje cast-discover", "generate prompt", "generate vox",
        ]
      ),
      (
        name: "generate", abstract: GenerateCommand.configuration.abstract,
        discussion: GenerateCommand.configuration.discussion,
        mustMention: ["prompt", "vox", "personaje cast-discover"]
      ),
      (
        name: "generate prompt", abstract: GeneratePromptCommand.configuration.abstract,
        discussion: GeneratePromptCommand.configuration.discussion,
        mustMention: ["PROJECT.md", "CAST.md", "voicePrompt", "personaje cast-discover"]
      ),
      (
        name: "generate vox", abstract: GenerateVoxCommand.configuration.abstract,
        discussion: GenerateVoxCommand.configuration.discussion,
        mustMention: ["PROJECT.md", "CAST.md", "voicePrompt", ".vox", "personaje cast-discover"]
      ),
    ] as [(name: String, abstract: String, discussion: String, mustMention: [String])]
  )
  func commandHasNonEmptyDocumentation(
    _ fixture: (name: String, abstract: String, discussion: String, mustMention: [String])
  ) {
    #expect(
      !fixture.abstract.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      "\(fixture.name) abstract")
    #expect(
      !fixture.discussion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      "\(fixture.name) discussion")
    for token in fixture.mustMention {
      #expect(
        fixture.discussion.localizedCaseInsensitiveContains(token),
        "\(fixture.name) discussion should mention '\(token)'")
    }
  }

  // MARK: - `--help` rendering (guards doc drift end to end)

  /// Renders the real `--help` text ArgumentParser would print for `generate`
  /// and each leaf stage, rooted at `EchadaCLI` (the actual CLI entry point),
  /// and confirms the rendered text contains the command name and the
  /// command's own discussion prose.
  @Test(
    "Rendered --help for generate and each leaf contains the command name + discussion",
    arguments: [
      (name: "generate", type: GenerateCommand.self as ParsableCommand.Type),
      (name: "prompt", type: GeneratePromptCommand.self as ParsableCommand.Type),
      (name: "vox", type: GenerateVoxCommand.self as ParsableCommand.Type),
    ] as [(name: String, type: ParsableCommand.Type)]
  )
  func helpRenderingContainsNameAndDiscussion(
    _ fixture: (name: String, type: ParsableCommand.Type)
  ) {
    let rendered = EchadaCLI.helpMessage(for: fixture.type)
    #expect(rendered.contains(fixture.name))

    let discussion = fixture.type.configuration.discussion
    #expect(!discussion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    // ArgumentParser re-wraps discussion prose to the terminal width, so
    // compare a stable short phrase rather than the raw multi-line literal.
    let firstDiscussionWords =
      discussion
      .split(whereSeparator: { $0.isWhitespace })
      .prefix(4)
      .joined(separator: " ")
    #expect(rendered.contains(firstDiscussionWords))
  }

  @Test("Rendered --help for the cast orchestrator contains its name + discussion")
  func helpRenderingForCastOrchestrator() {
    let rendered = EchadaCLI.helpMessage(for: CastCommand.self)
    #expect(rendered.contains("cast"))
    let firstDiscussionWords = CastCommand.configuration.discussion
      .split(whereSeparator: { $0.isWhitespace })
      .prefix(4)
      .joined(separator: " ")
    #expect(rendered.contains(firstDiscussionWords))
  }

  // MARK: - `--cast` option surface (EC-13)

  @Test("Rendered --help for generate prompt and generate vox lists --cast")
  func generatePromptAndVoxHelpListCastOption() {
    for type in [GeneratePromptCommand.self as ParsableCommand.Type, GenerateVoxCommand.self] {
      let rendered = EchadaCLI.helpMessage(for: type)
      #expect(rendered.contains("--cast"), "\(type) --help should list --cast")
    }
  }

  @Test("Rendered --help for the cast orchestrator lists --cast (EC-15 cascade)")
  func castOrchestratorHelpListsCastOption() {
    let rendered = EchadaCLI.helpMessage(for: CastCommand.self)
    #expect(rendered.contains("--cast"), "echada cast --help should list --cast")
  }

  @Test("CastCommand's --cast defaults to CAST.md and accepts an override")
  func castCommandCastOptionParses() throws {
    let defaulted = try CastCommand.parse([])
    #expect(defaulted.cast == "CAST.md")
    let overridden = try CastCommand.parse(["--cast", "ROSTER.md"])
    #expect(overridden.cast == "ROSTER.md")
  }

  // MARK: - Thin parse wiring test

  @Test("GeneratePromptCommand parses its full flag surface")
  func generatePromptCommandParses() throws {
    let cmd = try GeneratePromptCommand.parse([
      "--project", "PROJECT.md",
      "--cast", "ROSTER.md",
      "--character", "ALICE",
      "--force",
      "--dry-run",
      "--verbose",
    ])
    #expect(cmd.project == "PROJECT.md")
    #expect(cmd.cast == "ROSTER.md")
    #expect(cmd.character == "ALICE")
    #expect(cmd.force)
    #expect(cmd.dryRun)
    #expect(cmd.verbose)
  }

  @Test("GeneratePromptCommand parses with defaults when only --project is given")
  func generatePromptCommandParsesWithDefaults() throws {
    let cmd = try GeneratePromptCommand.parse(["--project", "PROJECT.md"])
    #expect(cmd.project == "PROJECT.md")
    #expect(cmd.cast == "CAST.md")
    #expect(cmd.character == nil)
    #expect(!cmd.force)
    #expect(!cmd.dryRun)
    #expect(!cmd.verbose)
  }

  @Test("GenerateVoxCommand's --cast defaults to CAST.md and accepts an override")
  func generateVoxCommandCastOptionParses() throws {
    let defaulted = try GenerateVoxCommand.parse(["--project", "PROJECT.md"])
    #expect(defaulted.cast == "CAST.md")
    let overridden = try GenerateVoxCommand.parse([
      "--project", "PROJECT.md", "--cast", "ROSTER.md",
    ])
    #expect(overridden.cast == "ROSTER.md")
  }
}
