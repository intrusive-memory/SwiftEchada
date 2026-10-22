import AVFoundation
import Foundation
@preconcurrency import MLX
@preconcurrency import MLXAudioTTS
@preconcurrency import MLXLMCommon
import SwiftReparto
import SwiftVoxAlta
@preconcurrency import VoxFormat

import enum SwiftEchada.SwiftEchada

/// A Qwen3-TTS model size a `.vox` can hold an embedding for.
public enum VoiceModelSize: String, CaseIterable, Codable, Sendable {
  case large = "1.7b"
  case small = "0.6b"

  /// The size a `.vox` is played with when nothing asks for another one.
  public static let `default`: VoiceModelSize = .large

  var repo: Qwen3TTSModelRepo {
    switch self {
    case .large: .base1_7B
    case .small: .base0_6B
    }
  }
}

/// What a long-running ``VoiceBuilder`` call is doing, for a progress UI.
public enum VoiceBuildProgress: Equatable, Sendable {
  /// Rendering audition `index` of `count` with VoiceDesign.
  case designing(index: Int, count: Int)
  /// Locking the voice with the Base model of this size.
  case locking(VoiceModelSize)
  /// Writing the `.vox` to its EC-23 location.
  case writing(relativePath: String)
  /// Rendering a sample.
  case renderingSample(variant: String, model: VoiceModelSize)
}

/// One candidate voice: audio an app can play before choosing (EC-P7).
public struct VoiceAudition: Sendable {
  /// The voice prompt it was designed from (accent included).
  public let voicePrompt: String
  /// The sentence it speaks.
  public let sampleText: String
  /// BCP-47 language.
  public let language: String
  /// WAV audio (24 kHz, 16-bit PCM, mono).
  public let wav: Data
}

/// The outcome of writing a `.vox`.
public struct VoiceBuildResult: Sendable {
  /// Where it went and which EC-23 rule chose it.
  public let location: VoiceLocation
  /// The sizes it now holds an embedding for.
  public let models: [VoiceModelSize]
  /// The sentence its embedded samples speak.
  public let sampleText: String

  /// The member with `voices.voxalta` pointing at the file. echada never
  /// writes CAST.md from the library; write this back through SwiftReparto.
  public func updating(_ member: CastMember) -> CastMember {
    var updated = member
    updated.voices["voxalta"] = [location.relativePath]
    return updated
  }
}

/// A rendered sample file (EC-28, EC-P8).
public struct VoiceSample: Codable, Equatable, Sendable {
  public let variant: String
  public let model: VoiceModelSize
  public let language: String
  /// The words spoken, for the manifest's `sampleText`.
  public let sampleText: String
  /// Relative to the CAST.md directory: `<character dir>/voice/sample-<variant>[-<model>].m4a`.
  public let relativePath: String
}

public enum VoiceBuilderError: LocalizedError, Sendable {
  case noVoicePrompt(character: String)
  case noVox(character: String, path: String)
  case modelMissing(character: String, model: String)
  case encodingFailed(String)

  public var errorDescription: String? {
    switch self {
    case .noVoicePrompt(let character):
      return "'\(character)' has no voicePrompt to design a voice from."
    case .noVox(let character, let path):
      return "'\(character)' has no voice at \(path). Build the voice first."
    case .modelMissing(let character, let model):
      return "The voice for '\(character)' has no \(model) embedding."
    case .encodingFailed(let reason):
      return "Couldn't encode the sample as .m4a: \(reason)"
    }
  }
}

/// Builds and renders character voices in-process, for an app (Personaje
/// Part B). It writes `.vox` and sample files into the character's record
/// (EC-23) and never writes CAST.md or `manifest.json`: the caller records the
/// results through SwiftReparto and SwiftDossier.
///
/// Every call loads the models it needs and unloads them before returning
/// (EC-P9), and checks for task cancellation between steps. Models come from
/// the shared SwiftAcervo directory (`group.intrusive-memory.models`), so the
/// host needs that App Group entitlement (EC-P10).
public struct VoiceBuilder: Sendable {

  public let castDirectory: URL
  public let charactersDir: String

  /// - Parameters:
  ///   - castDirectory: The directory holding CAST.md; every path is relative to it.
  ///   - charactersDir: PROJECT.md `personaje.charactersDir`.
  public init(castDirectory: URL, charactersDir: String = VoiceLocation.defaultCharactersDir) {
    self.castDirectory = castDirectory
    self.charactersDir = charactersDir
  }

  /// Where `member`'s `.vox` goes (EC-23).
  public func location(for member: CastMember) throws -> VoiceLocation {
    try VoiceLocation.resolve(
      for: member, castDirectory: castDirectory, charactersDir: charactersDir)
  }

  // MARK: - Build (EC-P6)

  /// Designs a voice from the member's `voicePrompt` and writes one `.vox`
  /// holding an embedding for each of `models` (both sizes by default).
  public func buildVoice(
    for member: CastMember,
    language: String = "en",
    accent: String? = nil,
    models: [VoiceModelSize] = VoiceModelSize.allCases,
    progress: @escaping @Sendable (VoiceBuildProgress) -> Void = { _ in }
  ) async throws -> VoiceBuildResult {
    let candidates = try await audition(
      for: member, language: language, accent: accent, count: 1, progress: progress)
    return try await lock(candidates[0], for: member, models: models, progress: progress)
  }

  // MARK: - Audition (EC-P7)

  /// Renders `count` candidate voices for the member's prompt without locking
  /// any, so the app can play them and lock one.
  public func audition(
    for member: CastMember,
    language: String = "en",
    accent: String? = nil,
    count: Int = 3,
    progress: @escaping @Sendable (VoiceBuildProgress) -> Void = { _ in }
  ) async throws -> [VoiceAudition] {
    guard
      let base = localizedVoicePrompt(for: member, language: language) ?? member.voicePrompt,
      !base.isEmpty
    else { throw VoiceBuilderError.noVoicePrompt(character: member.character) }
    let voicePrompt = composeVoicePrompt(base: base, accent: accent)
    let sampleText = try AuditionSentence.auditionSentence(
      language: language, character: member.character, variant: nil)
    let ttsLanguage = try TTSLanguage(languageCode: language)

    let manager = VoxAltaModelManager()
    do {
      let model = try await manager.loadModel(.voiceDesign1_7B)
      guard let qwen = model as? Qwen3TTSModel else { throw VoiceDesignerError.modelCastFailed }

      var auditions: [VoiceAudition] = []
      for index in 0..<max(1, count) {
        try Task.checkCancellation()
        progress(.designing(index: index + 1, count: max(1, count)))
        let audio = try await qwen.generate(
          text: sampleText, voice: voicePrompt, language: ttsLanguage.modelName,
          generationParameters: GenerateParameters())
        Stream.defaultStream(.gpu).synchronize()
        Memory.clearCache()
        let wav = try AudioConversion.mlxArrayToWAVData(audio, sampleRate: qwen.sampleRate)
        auditions.append(
          VoiceAudition(
            voicePrompt: voicePrompt, sampleText: sampleText, language: language, wav: wav))
      }
      await manager.unloadModel()
      return auditions
    } catch {
      await manager.unloadModel()
      throw error
    }
  }

  // MARK: - Lock

  /// Locks `audition` with each Base model size and writes the `.vox`. An
  /// existing `.vox` at the location gains the new embeddings; its others stay.
  public func lock(
    _ audition: VoiceAudition,
    for member: CastMember,
    models: [VoiceModelSize] = VoiceModelSize.allCases,
    progress: @escaping @Sendable (VoiceBuildProgress) -> Void = { _ in }
  ) async throws -> VoiceBuildResult {
    let location = try location(for: member)
    let ttsLanguage = try TTSLanguage(languageCode: audition.language)
    let languageTag = voxLanguageTag(for: audition.language)

    let vox: VoxFile
    if FileManager.default.fileExists(atPath: location.url.path) {
      vox = try VoxFile(contentsOf: location.url)
    } else {
      vox = VoxFile(name: member.character, description: audition.voicePrompt)
      vox.manifest.provenance = VoxManifest.Provenance(
        method: "synthesized", engine: "qwen3-tts", license: "CC0-1.0",
        notes: "Voice generated from text prompt by EchadaVoice (echada \(SwiftEchada.version)).")
    }

    let manager = VoxAltaModelManager()
    do {
      for size in models {
        try Task.checkCancellation()
        progress(.locking(size))
        let voiceLock = try await VoiceLockManager.createLock(
          characterName: member.character, candidateAudio: audition.wav,
          designInstruction: audition.voicePrompt, modelManager: manager,
          sampleSentence: audition.sampleText, modelRepo: size.repo, language: ttsLanguage)
        try VoxExporter.addClonePrompt(
          to: vox, data: voiceLock.clonePromptData, modelRepo: size.repo, language: languageTag)
        try VoxExporter.addSampleAudio(
          to: vox, data: audition.wav, modelRepo: size.repo, language: languageTag)
        await manager.unloadModel()
      }
    } catch {
      await manager.unloadModel()
      throw error
    }

    try Task.checkCancellation()
    progress(.writing(relativePath: location.relativePath))
    try FileManager.default.createDirectory(
      at: location.url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try vox.write(to: location.url)

    let held = VoiceModelSize.allCases.filter { vox.supportsModel($0.rawValue) }
    return VoiceBuildResult(location: location, models: held, sampleText: audition.sampleText)
  }

  // MARK: - Samples (EC-28, EC-P8)

  /// The fixed line used when a character has no `sampleLine`.
  public static let defaultSampleLine =
    "The quick brown fox jumps over the lazy dog, and then it rests a while."

  /// Writes `voice/sample-<variant>[-<model>].m4a` beside the member's `.vox`.
  ///
  /// `neutral` with no `text` exports the sample already embedded in the
  /// `.vox` (no synthesis). Any other variant, or explicit `text`, is spoken
  /// by the character's locked voice with `instruct` (default: the variant
  /// name) as the delivery instruction.
  public func renderSample(
    for member: CastMember,
    variant: String = "neutral",
    text: String? = nil,
    model: VoiceModelSize = .default,
    language: String? = nil,
    sampleLine: String? = nil,
    instruct: String? = nil,
    progress: @escaping @Sendable (VoiceBuildProgress) -> Void = { _ in }
  ) async throws -> VoiceSample {
    let location = try location(for: member)
    guard FileManager.default.fileExists(atPath: location.url.path) else {
      throw VoiceBuilderError.noVox(character: member.character, path: location.relativePath)
    }
    let vox = try VoxFile(contentsOf: location.url)
    guard vox.supportsModel(model.rawValue) else {
      throw VoiceBuilderError.modelMissing(character: member.character, model: model.rawValue)
    }
    let language =
      language ?? member.language?.trimmingCharacters(in: .whitespaces).lowercased() ?? "en"
    progress(.renderingSample(variant: variant, model: model))

    let wav: Data
    let spoken: String
    if variant == "neutral", text == nil {
      guard
        let embedded = vox.sampleAudioData(
          for: model.rawValue, language: voxLanguageTag(for: language))
      else {
        throw VoiceBuilderError.modelMissing(character: member.character, model: model.rawValue)
      }
      wav = embedded
      spoken = try AuditionSentence.auditionSentence(
        language: language, character: member.character, variant: nil)
    } else {
      guard
        let clone = vox.clonePromptData(
          for: model.rawValue, language: voxLanguageTag(for: language))
      else {
        throw VoiceBuilderError.modelMissing(character: member.character, model: model.rawValue)
      }
      spoken = text ?? sampleLine ?? Self.defaultSampleLine
      let manager = VoxAltaModelManager()
      try Task.checkCancellation()
      wav = try await VoiceLockManager.generateAudio(
        text: spoken,
        voiceLock: VoiceLock(
          characterName: member.character, clonePromptData: clone,
          designInstruction: vox.manifest.voice.description),
        language: try TTSLanguage(languageCode: language),
        instruct: instruct ?? (variant == "neutral" ? nil : variant),
        modelManager: manager, modelRepo: model.repo)
      await manager.unloadModel()
    }

    let name = Self.sampleFileName(variant: variant, model: model)
    let relative = (location.relativePath as NSString).deletingLastPathComponent + "/" + name
    let output = castDirectory.appending(path: relative)
    try Self.writeM4A(wav: wav, to: output)
    return VoiceSample(
      variant: variant, model: model, language: language, sampleText: spoken,
      relativePath: relative)
  }

  /// The model sizes the `.vox` at `url` holds an embedding for.
  public static func modelSizes(inVoxAt url: URL) throws -> [VoiceModelSize] {
    let vox = try VoxFile(contentsOf: url)
    return VoiceModelSize.allCases.filter { vox.supportsModel($0.rawValue) }
  }

  /// `sample-<variant>.m4a`, with `-<model>` when the size isn't the default
  /// (dossier-format §4).
  public static func sampleFileName(variant: String, model: VoiceModelSize) -> String {
    model == .default ? "sample-\(variant).m4a" : "sample-\(variant)-\(model.rawValue).m4a"
  }

  /// Transcodes WAV data to an AAC `.m4a` file with AVFoundation.
  static func writeM4A(wav: Data, to output: URL) throws {
    let scratch = FileManager.default.temporaryDirectory
      .appendingPathComponent("echada-sample-\(UUID().uuidString).wav")
    try wav.write(to: scratch)
    defer { try? FileManager.default.removeItem(at: scratch) }

    let input = try AVAudioFile(forReading: scratch)
    let format = input.processingFormat
    guard
      let buffer = AVAudioPCMBuffer(
        pcmFormat: format, frameCapacity: AVAudioFrameCount(input.length))
    else { throw VoiceBuilderError.encodingFailed("couldn't allocate an audio buffer") }
    try input.read(into: buffer)

    try FileManager.default.createDirectory(
      at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: output)
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: format.sampleRate,
      AVNumberOfChannelsKey: format.channelCount,
      // A fixed bit rate can exceed what AAC allows at 24 kHz mono; let the
      // encoder pick one for the quality.
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
    do {
      let file = try AVAudioFile(
        forWriting: output, settings: settings, commonFormat: format.commonFormat,
        interleaved: format.isInterleaved)
      try file.write(from: buffer)
    } catch {
      throw VoiceBuilderError.encodingFailed(error.localizedDescription)
    }
  }
}
