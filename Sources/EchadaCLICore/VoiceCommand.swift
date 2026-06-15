import ArgumentParser
import Foundation
@preconcurrency import MLX
@preconcurrency import MLXAudioTTS
@preconcurrency import MLXLMCommon
import SwiftVoxAlta
@preconcurrency import VoxFormat

public struct VoiceCommand: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "voice",
    abstract: "Generate a .vox voice file from a text prompt."
  )

  @Argument(
    help: "Voice description prompt (e.g., \"A warm female voice with a slight southern accent\").")
  public var prompt: String

  @Option(name: .long, help: "Output path for the .vox file.")
  public var output: String = "voice.vox"

  @Option(name: .long, help: "Character name for the .vox manifest.")
  public var name: String = "Voice"

  @Option(name: .long, help: "TTS model variant (0.6b, 1.7b).")
  public var ttsModel: String = Qwen3TTSModelRepo.base1_7B.slug

  @Option(
    name: .long,
    help: "BCP-47 language code for the reference sample (default: en).")
  public var language: String = "en"

  @Flag(name: .long, help: "Show verbose output.")
  public var verbose: Bool = false

  public init() {}

  private func resolvedModelRepo() throws -> Qwen3TTSModelRepo {
    guard let repo = Qwen3TTSModelRepo(slug: ttsModel) else {
      let slugs = Qwen3TTSModelRepo.supportedSlugs.sorted().joined(separator: "', '")
      throw ValidationError("Unsupported TTS model '\(ttsModel)'. Use '\(slugs)'.")
    }
    return repo
  }

  public func run() async throws {
    let modelRepo = try resolvedModelRepo()
    let normalizedLanguage = language.trimmingCharacters(in: .whitespaces).lowercased()
    guard !normalizedLanguage.isEmpty else {
      throw ValidationError("--language must be a non-empty BCP-47 code.")
    }
    let languageTag = voxLanguageTag(for: normalizedLanguage)
    let modelManager = VoxAltaModelManager()
    let outputURL = URL(fileURLWithPath: output)
    // The audition sentence is sourced exclusively from the on-device Foundation
    // Model; an unavailable model or unsupported locale throws a clear
    // configuration error rather than falling back to a canned sentence.
    let sampleSentence = try await FoundationModelSentence.auditionSentence(
      language: normalizedLanguage)

    print("Generating voice from prompt...")
    if verbose {
      print("[verbose] Prompt: \(prompt)")
      print("[verbose] Language: \(normalizedLanguage)")
      print("[verbose] Sample sentence: \(sampleSentence)")
    }
    fflush(stdout)

    // Phase A: Generate candidate WAV via VoiceDesign model
    let designModel = try await modelManager.loadModel(.voiceDesign1_7B)
    guard let qwenModel = designModel as? Qwen3TTSModel else {
      throw VoiceDesignerError.modelCastFailed
    }

    let audioArray = try await qwenModel.generate(
      text: sampleSentence,
      voice: prompt,
      language: normalizedLanguage,
      generationParameters: GenerateParameters()
    )

    Stream.defaultStream(.gpu).synchronize()
    Memory.clearCache()

    let candidateWAV = try AudioConversion.mlxArrayToWAVData(
      audioArray, sampleRate: qwenModel.sampleRate)
    print("Generated candidate WAV (\(candidateWAV.count) bytes)")
    fflush(stdout)

    // Unload VoiceDesign before loading Base
    await modelManager.unloadModel()

    // Phase B: Create voice lock and export .vox
    print("Creating voice lock (\(ttsModel))...")
    fflush(stdout)

    let voiceLock = try await VoiceLockManager.createLock(
      characterName: name,
      candidateAudio: candidateWAV,
      designInstruction: prompt,
      modelManager: modelManager,
      sampleSentence: sampleSentence,
      modelRepo: modelRepo,
      language: normalizedLanguage
    )

    let vox: VoxFile
    if FileManager.default.fileExists(atPath: outputURL.path) {
      vox = try VoxFile(contentsOf: outputURL)
      if verbose {
        print("[verbose] Opened existing \(output) to add \(ttsModel) embedding")
      }
    } else {
      vox = VoxFile(name: name, description: prompt)
      vox.manifest.provenance = VoxManifest.Provenance(
        method: "synthesized",
        engine: "qwen3-tts",
        license: "CC0-1.0",
        notes: "Voice generated from text prompt via echada voice command."
      )
    }

    try VoxExporter.addClonePrompt(
      to: vox, data: voiceLock.clonePromptData, modelRepo: modelRepo, language: languageTag)
    try VoxExporter.addSampleAudio(
      to: vox, data: candidateWAV, modelRepo: modelRepo, language: languageTag)
    try vox.write(to: outputURL)

    print("Wrote \(outputURL.path)")
  }
}
