import ArgumentParser
import Foundation

/// `echada voices` — ElevenLabs voices for a project's cast (EL-4).
public struct VoicesCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "voices",
    abstract: "Design and manage cloud (ElevenLabs) voices for the cast in CAST.md.",
    subcommands: [VoicesDesignCommand.self]
  )

  public init() {}
}

/// `echada voices design` — the non-interactive two-step: design previews, a person listens,
/// then pick one to save.
public struct VoicesDesignCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "design",
    abstract: "Design ElevenLabs voices from each character's voicePrompt, then save a chosen one.",
    discussion: """
      Step 1 — design. Selects the named CHARACTERs, or every cast member with \
      `provider: elevenlabs` (narrow with --role). The description is the \
      `voicePrompt`; the sample line is the character's first dialogue line of \
      100-1,000 characters in the project's episodes, else --sample-text (never \
      invented). Refuses when there are more voices to design than free voice \
      slots, and prints the estimated credit cost first. Each preview WAV and an \
      index.json are written to --candidates-dir, then the command exits.

      Step 2 — pick. After listening, `--pick <generated_voice_id>` (with the \
      same --candidates-dir) creates the permanent voice named \
      `<project> — <CHARACTER>`, writes the ElevenLabs fields into the \
      character's existing .vox (the qwen3-tts entries are kept), and sets \
      `voices.elevenlabs` and `provider: elevenlabs` in CAST.md. If the \
      character already had a designed ElevenLabs voice, it is deleted only \
      after the new one is saved. Never pick for a person who has not listened.

      The API key comes from ELEVENLABS_API_KEY or the shared keychain.

      Example:
          echada voices design --candidates-dir ./candidates NARRATOR
          echada voices design --candidates-dir ./candidates --pick <generated_voice_id>
      """
  )

  @Argument(help: "Characters to design. Default: every cast member with `provider: elevenlabs`.")
  public var characters: [String] = []

  @Option(name: .long, help: "Path to PROJECT.md file.")
  public var project: String = "PROJECT.md"

  @Option(
    name: .long,
    help: "Filename of the cast roster (default: CAST.md), beside --project.")
  public var cast: String = "CAST.md"

  @Option(
    name: .long,
    help: "Only members with these roles, comma-separated (e.g. narrator,lead).")
  public var role: String?

  @Option(
    name: .customLong("sample-text"),
    help: "Sample line (100-1,000 characters) for characters with no usable dialogue in the episodes.")
  public var sampleText: String?

  @Option(
    name: .customLong("design-model"),
    help: "ElevenLabs design model (eleven_multilingual_ttv_v2, eleven_ttv_v3).")
  public var designModel: String = "eleven_multilingual_ttv_v2"

  @Option(
    name: .customLong("candidates-dir"),
    help: "Directory for preview WAVs and index.json (design), or where they were written (--pick).")
  public var candidatesDir: String?

  @Option(
    name: .long,
    help: "Save this generated_voice_id from --candidates-dir as the character's voice.")
  public var pick: String?

  public init() {}

  public func run() async throws {
    let fileURL = URL(fileURLWithPath: project)
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw ValidationError("Project file not found: \(project)")
    }
    let roles =
      (role ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
    let backend = try await LiveElevenLabsBackend()
    let runner = VoicesDesignRunner(
      projectURL: fileURL, castName: cast, characters: characters, roles: roles,
      sampleTextOverride: sampleText, designModel: designModel, candidatesDir: candidatesDir,
      pick: pick, backend: backend)
    let outcome = try await runner.run()
    if !outcome.failures.isEmpty {
      for failure in outcome.failures {
        FileHandle.standardError.write(Data("error: \(failure.localizedDescription)\n".utf8))
      }
      throw ExitCode.failure
    }
  }
}
