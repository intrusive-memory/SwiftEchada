import EchadaVoice
import Foundation
import SwiftHablare
import SwiftHablareOnce
import SwiftOnce
import SwiftReparto

/// Typed failures of `echada sample --provider elevenlabs`.
enum SampleElevenLabsError: LocalizedError, Equatable {
  case unknownCharacter(String, available: [String])
  case noElevenLabsVoice(character: String)
  case voxMissing(character: String, path: String)
  case voxHasNoVoiceId(path: String)
  case emptyVoiceId(character: String)
  case notADesignedVoice(character: String, voiceId: String)
  case noDesignPreview(path: String)

  var errorDescription: String? {
    switch self {
    case .unknownCharacter(let name, let available):
      return "'\(name)' isn't in CAST.md. Available: \(available.joined(separator: ", "))"
    case .noElevenLabsVoice(let character):
      return
        "\(character) has no ElevenLabs voice (no `voices.elevenlabs` in CAST.md). "
        + "Design one with `echada voices design`, or assign a premade voice with "
        + "`echada voices assign \(character) --provider elevenlabs --voice-id <id>`."
    case .voxMissing(let character, let path):
      return "\(character): voices.elevenlabs points at \(path), which doesn't exist."
    case .voxHasNoVoiceId(let path):
      return "\(path) has no extensions.elevenlabs.voice_id; it isn't a designed ElevenLabs voice."
    case .emptyVoiceId(let character):
      return "\(character): voices.elevenlabs is empty."
    case .notADesignedVoice(let character, let voiceId):
      return
        "\(character) uses the stock ElevenLabs voice \(voiceId), which has no .vox and so no "
        + "stored design preview. Drop --from-design-preview to synthesize a sample instead."
    case .noDesignPreview(let path):
      return "\(path) holds no stored ElevenLabs design preview audio."
    }
  }
}

/// What ElevenLabs sampling needs from the network, behind one seam so tests inject a
/// fake and never reach ElevenLabs.
protocol ElevenLabsSampleBackend: Sendable {
  /// Estimated credits for `request` (audio tag included), without calling the API.
  func estimateCredits(_ request: SpeechRequest) -> Int?
  /// Remaining credits when the account reports them (one subscription call).
  func remainingCredits() async -> Int?
  /// WAV audio for `request`.
  func synthesize(_ request: SpeechRequest) async throws -> Data
}

/// The live backend: SwiftHablareOnce's `ElevenLabsPlugin` synthesizer, the same path
/// `produciesta generate --provider elevenlabs` uses.
struct LiveElevenLabsSampleBackend: ElevenLabsSampleBackend {
  private let plugin: ElevenLabsPlugin

  init() async throws {
    let context = PluginContext(keys: ChainedAPIKeyStore.default, registry: PluginRegistry.default)
    self.plugin = try await ElevenLabsPlugin(context: context)
  }

  func estimateCredits(_ request: SpeechRequest) -> Int? {
    plugin.synthesizer?.estimateCost(request).map { Int($0.quantity.rounded(.up)) }
  }

  func remainingCredits() async -> Int? { await plugin.remainingCredits() }

  func synthesize(_ request: SpeechRequest) async throws -> Data {
    guard let synthesizer = plugin.synthesizer else {
      throw HablareError.invalidRequest(detail: "ElevenLabs plugin has no synthesizer")
    }
    return try await synthesizer.synthesize(request).data
  }
}

/// A member's resolved ElevenLabs voice.
struct ElevenLabsVoice: Equatable {
  var voiceId: String
  /// The `.vox` a designed voice lives in; `nil` for a stock voice.
  var voxURL: URL?
  /// The pointer as written in CAST.md, relative to the CAST.md directory.
  var voxRelativePath: String?
}

/// The machine-readable result of `echada sample --provider elevenlabs`, for the
/// dossier manifest writer.
struct ElevenLabsSampleResult: Codable, Equatable {
  var provider = ElevenLabsProviderID.value
  var variant: String
  var model: String
  var voiceId: String
  var text: String
  var sampleText: String
  var instruct: String?
  /// Absolute path of the `.m4a` (written, or that would be written under `--dry-run`).
  var path: String
  /// Relative to the CAST.md directory.
  var relativePath: String
  /// The designed voice's `.vox`, relative to the CAST.md directory (nil for a stock voice).
  var voxPath: String?
  /// Credits spent: 0 for a design preview or a dry run.
  var creditsUsed: Int
  /// What the synthesis costs (or would cost); 0 for a design preview.
  var creditsEstimated: Int
  var fromDesignPreview: Bool
  var dryRun: Bool
}

/// The work of `echada sample --provider elevenlabs`, with the backend injected.
struct ElevenLabsSampleRunner {
  var projectURL: URL
  var castName: String
  var character: String
  var variant: String
  var text: String?
  var instruct: String?
  var model: String
  var fromDesignPreview: Bool
  var dryRun: Bool
  var output: String?
  /// Created only when the API is actually needed (never for a preview or a missing voice).
  var makeBackend: @Sendable () async throws -> any ElevenLabsSampleBackend
  var log: @Sendable (String) -> Void = { print($0) }

  func run() async throws -> ElevenLabsSampleResult {
    let castURL = try CastFile.resolve(named: castName, in: projectURL.deletingLastPathComponent())
    let roster = try CastMarkdownParser().parse(fileURL: castURL).cast
    guard
      let member = roster.first(where: {
        $0.character.localizedCaseInsensitiveCompare(character) == .orderedSame
      })
    else {
      throw SampleElevenLabsError.unknownCharacter(character, available: roster.map(\.character))
    }
    let castDir = castURL.deletingLastPathComponent()
    let voice = try Self.resolveVoice(for: member, castDirectory: castDir)

    let builder = VoiceBuilder(
      castDirectory: castDir,
      charactersDir: try PersonajeSettings.read(fileURL: projectURL).resolvedCharactersDir)
    let voxalta = try builder.location(for: member)
    let voiceDirectory = voxalta.url.deletingLastPathComponent()
    let characterDirectory = voiceDirectory.deletingLastPathComponent()
    let outputURL: URL
    if let output {
      outputURL = URL(fileURLWithPath: output)
    } else {
      outputURL = voiceDirectory.appending(
        path: VoiceBuilder.elevenLabsSampleFileName(variant: variant))
    }
    let relative = Self.relativePath(of: outputURL, from: castDir)

    if fromDesignPreview { return try exportPreview(voice, to: outputURL, relative: relative) }

    let spoken =
      text ?? SampleCommand.sampleLine(characterDirectory: characterDirectory)
      ?? VoiceBuilder.defaultSampleLine
    let tag = instruct ?? (variant == "neutral" ? nil : variant)
    var settings = VoiceSettings()
    settings[ElevenLabsModels.SettingKey.model] = .string(model)
    let request = SpeechRequest(
      text: spoken, voice: .catalog(pluginId: ElevenLabsProviderID.value, voiceId: voice.voiceId),
      languageCode: member.language?.trimmingCharacters(in: .whitespaces).lowercased(),
      instruct: tag, settings: settings)

    let backend = try await makeBackend()
    let estimate = backend.estimateCredits(request) ?? 0
    var result = ElevenLabsSampleResult(
      variant: variant, model: model, voiceId: voice.voiceId, text: spoken, sampleText: spoken,
      instruct: tag, path: outputURL.path, relativePath: relative,
      voxPath: voice.voxRelativePath, creditsUsed: 0, creditsEstimated: estimate,
      fromDesignPreview: false, dryRun: dryRun)

    if dryRun {
      log(
        "\(character) \(variant): \(estimate) credits estimated (\(spoken.count) characters, "
          + "\(model)); dry run, nothing synthesized.")
      return result
    }
    let remaining = await backend.remainingCredits()
    log(
      "\(character) \(variant): synthesizing with \(model), estimated \(estimate) credits"
        + (remaining.map { " (\($0) remaining)" } ?? "") + ".")
    let wav = try await backend.synthesize(request)
    try VoiceBuilder.writeM4AMono(wav: wav, to: outputURL)
    result.creditsUsed = estimate
    log("\(relative)  \"\(spoken)\"")
    return result
  }

  // MARK: - Design preview

  private func exportPreview(
    _ voice: ElevenLabsVoice, to outputURL: URL, relative: String
  ) throws -> ElevenLabsSampleResult {
    guard let voxURL = voice.voxURL else {
      throw SampleElevenLabsError.notADesignedVoice(character: character, voiceId: voice.voiceId)
    }
    let asset = try VoiceAsset(contentsOf: voxURL)
    guard let wav = Self.designPreview(in: asset) else {
      throw SampleElevenLabsError.noDesignPreview(path: voxURL.path)
    }
    let fields = asset.extensionFields(forEngine: ElevenLabsProviderID.value) ?? [:]
    let spoken = (fields["sample_text"] as? String) ?? ""
    let designModel = (fields["design_model"] as? String) ?? ""
    try VoiceBuilder.writeM4AMono(wav: wav, to: outputURL)
    log("\(relative)  design preview, no credits used")
    return ElevenLabsSampleResult(
      variant: variant, model: designModel, voiceId: voice.voiceId, text: spoken,
      sampleText: spoken, instruct: nil, path: outputURL.path, relativePath: relative,
      voxPath: voice.voxRelativePath, creditsUsed: 0, creditsEstimated: 0,
      fromDesignPreview: true, dryRun: false)
  }

  /// The picked design preview `ElevenLabsDesigner.save` stored as the `.vox`'s ElevenLabs
  /// sample audio.
  static func designPreview(in asset: VoiceAsset) -> Data? {
    let stored = asset.sources.first {
      $0.engine == ElevenLabsProviderID.value && $0.kind == .referenceAudio && $0.path != nil
    }
    if let path = stored?.path, let data = asset.entryData(at: path) { return data }
    if let path = asset.entryPaths.first(where: {
      $0.hasPrefix("embeddings/\(ElevenLabsProviderID.value)/") && $0.hasSuffix("sample-audio.wav")
    }) {
      return asset.entryData(at: path)
    }
    return nil
  }

  // MARK: - Voice resolution

  /// `voices.elevenlabs` is a `.vox` path (a designed voice), `elevenlabs://<id>`, or a bare id.
  static func resolveVoice(for member: CastMember, castDirectory: URL) throws -> ElevenLabsVoice {
    guard let raw = member.voices[ElevenLabsProviderID.value]?.first else {
      throw SampleElevenLabsError.noElevenLabsVoice(character: member.character)
    }
    let pointer = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !pointer.isEmpty else {
      throw SampleElevenLabsError.noElevenLabsVoice(character: member.character)
    }
    if pointer.hasSuffix(".vox") {
      let url =
        pointer.hasPrefix("/")
        ? URL(fileURLWithPath: pointer).standardizedFileURL
        : castDirectory.appending(path: pointer).standardizedFileURL
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw SampleElevenLabsError.voxMissing(character: member.character, path: pointer)
      }
      let asset = try VoiceAsset(contentsOf: url)
      guard
        let id = asset.extensionFields(forEngine: ElevenLabsProviderID.value)?["voice_id"]
          as? String, !id.isEmpty
      else { throw SampleElevenLabsError.voxHasNoVoiceId(path: pointer) }
      return ElevenLabsVoice(voiceId: id, voxURL: url, voxRelativePath: pointer)
    }
    let id = VoicesAssignRunner.normalize(pointer)
    guard !id.isEmpty else { throw SampleElevenLabsError.emptyVoiceId(character: member.character) }
    return ElevenLabsVoice(voiceId: id, voxURL: nil, voxRelativePath: nil)
  }

  static func relativePath(of url: URL, from base: URL) -> String {
    let full = url.standardizedFileURL.path
    let prefix = base.standardizedFileURL.path + "/"
    return full.hasPrefix(prefix) ? String(full.dropFirst(prefix.count)) : full
  }
}
