import ArgumentParser
import Foundation
import struct SwiftEchada.SampleSentenceGenerator
import SwiftVoxAlta
@preconcurrency import VoxFormat
@preconcurrency import MLXAudioTTS
@preconcurrency import MLX
@preconcurrency import MLXLMCommon

struct VoiceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "voice",
        abstract: "Generate a .vox voice file from a text prompt."
    )

    @Argument(help: "Voice description prompt (e.g., \"A warm female voice with a slight southern accent\").")
    var prompt: String

    @Option(name: .long, help: "Output path for the .vox file.")
    var output: String = "voice.vox"

    @Option(name: .long, help: "Character name for the .vox manifest.")
    var name: String = "Voice"

    @Option(name: .long, help: "TTS model variant (0.6b, 1.7b).")
    var ttsModel: String = Qwen3TTSModelRepo.base1_7B.slug

    @Flag(name: .long, help: "Show verbose output.")
    var verbose: Bool = false

    private func resolvedModelRepo() throws -> Qwen3TTSModelRepo {
        guard let repo = Qwen3TTSModelRepo(slug: ttsModel) else {
            let slugs = Qwen3TTSModelRepo.supportedSlugs.sorted().joined(separator: "', '")
            throw ValidationError("Unsupported TTS model '\(ttsModel)'. Use '\(slugs)'.")
        }
        return repo
    }

    func run() async throws {
        let modelRepo = try resolvedModelRepo()
        let modelManager = VoxAltaModelManager()
        let outputURL = URL(fileURLWithPath: output)
        let sampleSentence = SampleSentenceGenerator.randomQuote()

        print("Generating voice from prompt...")
        if verbose {
            print("[verbose] Prompt: \(prompt)")
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
            language: "en",
            generationParameters: GenerateParameters()
        )

        Stream.defaultStream(.gpu).synchronize()
        Memory.clearCache()

        let candidateWAV = try AudioConversion.mlxArrayToWAVData(audioArray, sampleRate: qwenModel.sampleRate)
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
            modelRepo: modelRepo
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

        try VoxExporter.addClonePrompt(to: vox, data: voiceLock.clonePromptData, modelRepo: modelRepo)
        try VoxExporter.addSampleAudio(to: vox, data: candidateWAV, modelRepo: modelRepo)
        try vox.write(to: outputURL)

        print("Wrote \(outputURL.path)")
    }
}
