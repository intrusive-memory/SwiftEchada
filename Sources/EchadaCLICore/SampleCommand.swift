import ArgumentParser
import EchadaVoice
import Foundation
import SwiftReparto
import Yams

/// `echada sample` — playable `.m4a` voice samples for the character dossier
/// (EC-28).
public struct SampleCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "sample",
    abstract: "Export playable .m4a voice samples beside a character's .vox.",
    discussion: """
      Writes `<character dir>/voice/sample-<variant>.m4a` (AAC) beside the \
      character's `.vox`; a model size other than 1.7b adds it to the name \
      (`sample-neutral-0.6b.m4a`).

      `neutral` (the default) exports the sample already embedded in the \
      `.vox`, with no synthesis. Any other variant speaks `--text`, or the \
      character's `sampleLine` from CHARACTER.md, or a fixed neutral sentence, \
      with the variant as the delivery instruction.

      `--all-variants` renders every entry of `voice/samples.yaml` when it \
      exists, otherwise `neutral` on each model size the `.vox` holds.

      It never writes manifest.json; `--json` returns `variant`, `model`, \
      `language`, `sampleText` and the path, for the manifest writer.

      Example:
          echada sample "THE PRACTITIONER"
          echada sample MAYA --variant whisper --text "Did you sleep at all?"
          echada sample MAYA --all-variants --json
      """
  )

  @Argument(help: "The character's exact CAST.md name.")
  public var character: String

  @Option(name: .long, help: "Sample variant: neutral, or a register name.")
  public var variant: String = "neutral"

  @Option(name: .long, help: "Words to speak (default: CHARACTER.md sampleLine).")
  public var text: String?

  @Option(name: .long, help: "Model size: 1.7b or 0.6b.")
  public var model: String = VoiceModelSize.default.rawValue

  @Flag(name: .long, help: "Render every samples.yaml entry (or neutral on every size).")
  public var allVariants: Bool = false

  @Flag(name: .long, help: "Print the rendered samples as JSON.")
  public var json: Bool = false

  @Option(name: .long, help: "Path to PROJECT.md.")
  public var project: String = "PROJECT.md"

  @Option(name: .long, help: "Filename of the cast roster beside PROJECT.md.")
  public var cast: String = "CAST.md"

  public init() {}

  public func validate() throws {
    guard VoiceModelSize(rawValue: model) != nil else {
      throw ValidationError(
        "--model must be one of: \(VoiceModelSize.allCases.map(\.rawValue).joined(separator: ", "))."
      )
    }
    if allVariants, text != nil || variant != "neutral" {
      throw ValidationError("--all-variants can't be combined with --variant or --text.")
    }
  }

  public func run() async throws {
    let projectURL = URL(fileURLWithPath: project)
    guard FileManager.default.fileExists(atPath: projectURL.path) else {
      throw ValidationError("Project file not found: \(project)")
    }
    let castURL = try CastFile.resolve(named: cast, in: projectURL.deletingLastPathComponent())
    let roster = try CastMarkdownParser().parse(fileURL: castURL).cast
    guard let member = roster.first(where: { $0.character == character }) else {
      throw ValidationError(
        "'\(character)' isn't in \(cast). Available: \(roster.map(\.character).joined(separator: ", "))"
      )
    }

    let builder = VoiceBuilder(
      castDirectory: castURL.deletingLastPathComponent(),
      charactersDir: try PersonajeSettings.read(fileURL: projectURL).resolvedCharactersDir)
    let voxURL = try builder.location(for: member).url
    let characterDir = voxURL.deletingLastPathComponent().deletingLastPathComponent()
    let sampleLine = Self.sampleLine(characterDirectory: characterDir)

    var samples: [VoiceSample] = []
    for job in try jobs(voxURL: voxURL, sampleLine: sampleLine) {
      let sample = try await builder.renderSample(
        for: member, variant: job.variant, text: job.text, model: job.model,
        language: job.language, sampleLine: sampleLine, instruct: job.instruct)
      samples.append(sample)
      if !json { print("\(sample.relativePath)  \"\(sample.sampleText)\"") }
    }

    if json {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      print(String(decoding: try encoder.encode(samples), as: UTF8.self))
    }
  }

  // MARK: - What to render

  struct Job: Equatable {
    var variant: String
    var text: String?
    var model: VoiceModelSize
    var language: String?
    var instruct: String?
  }

  /// One `samples.yaml` entry (dossier-format §10).
  struct SampleSpec: Decodable, Equatable {
    var variant: String
    var text: String
    var model: String?
    var language: String?
    var instruct: String?
  }

  func jobs(voxURL: URL, sampleLine: String?) throws -> [Job] {
    guard allVariants else {
      return [Job(variant: variant, text: text, model: VoiceModelSize(rawValue: model)!)]
    }
    let specsURL = voxURL.deletingLastPathComponent().appending(path: "samples.yaml")
    if FileManager.default.fileExists(atPath: specsURL.path) {
      let specs = try Self.readSamplesYAML(at: specsURL)
      return specs.map {
        Job(
          variant: $0.variant, text: $0.text,
          model: $0.model.flatMap(VoiceModelSize.init(rawValue:)) ?? .default,
          language: $0.language, instruct: $0.instruct)
      }
    }
    let held = try VoiceBuilder.modelSizes(inVoxAt: voxURL)
    return held.map { Job(variant: "neutral", text: nil, model: $0) }
  }

  static func readSamplesYAML(at url: URL) throws -> [SampleSpec] {
    try YAMLDecoder().decode([SampleSpec].self, from: String(contentsOf: url, encoding: .utf8))
  }

  /// CHARACTER.md's `sampleLine` (dossier-format §9.1), if any.
  static func sampleLine(characterDirectory: URL) -> String? {
    let url = characterDirectory.appending(path: "CHARACTER.md")
    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    let lines = content.components(separatedBy: "\n")
    guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
      let close = lines.dropFirst().firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == "---"
      })
    else { return nil }
    struct Front: Decodable { var sampleLine: String? }
    let yaml = lines[1..<close].joined(separator: "\n")
    let line = (try? YAMLDecoder().decode(Front.self, from: yaml))?.sampleLine
    return line?.isEmpty == false ? line : nil
  }
}
