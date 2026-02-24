import ArgumentParser
import Foundation
import struct SwiftEchada.CharacterProfile
import struct SwiftEchada.SampleSentenceGenerator
import SwiftProyecto
import SwiftVoxAlta
@preconcurrency import VoxFormat
@preconcurrency import MLXAudioTTS

struct TestVoiceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test-voice",
        abstract: "Generate a test .vox file for integration testing.",
        shouldDisplay: false
    )

    @Option(name: .long, help: "Output path for the .vox file.")
    var output: String

    @Option(name: .long, help: "TTS model size variant (0.6b or 1.7b).")
    var ttsModel: String = Qwen3TTSModelRepo.base1_7B.slug

    /// Resolves the `--tts-model` string to a `Qwen3TTSModelRepo`.
    private func resolvedModelRepo() throws -> Qwen3TTSModelRepo {
        guard let repo = Qwen3TTSModelRepo(slug: ttsModel) else {
            let slugs = Qwen3TTSModelRepo.supportedSlugs.sorted().joined(separator: "', '")
            throw ValidationError("Unsupported TTS model '\(ttsModel)'. Use '\(slugs)'.")
        }
        return repo
    }

    func run() async throws {
        let modelRepo = try resolvedModelRepo()

        let profile = CharacterProfile(
            name: "NARRATOR",
            gender: .male,
            ageRange: "40s",
            description: "Deep authoritative baritone with warmth and gravitas",
            voiceTraits: ["deep", "authoritative", "warm", "resonant"],
            summary: "Mature male narrator with commanding presence and warmth"
        )

        let modelManager = VoxAltaModelManager()
        let sampleSentence = SampleSentenceGenerator.randomQuote()

        // Generate candidate WAV
        print("Generating candidate voice (\(ttsModel))...")
        fflush(stdout)
        let candidateWAV = try await VoiceDesigner.generateCandidate(
            profile: profile,
            modelManager: modelManager,
            sampleSentence: sampleSentence
        )
        print("Generated candidate WAV (\(candidateWAV.count) bytes)")
        fflush(stdout)

        let designInstruction = VoiceDesigner.composeVoiceDescription(from: profile)

        // Create voice lock (speaker embedding)
        print("Creating voice lock (\(ttsModel))...")
        fflush(stdout)
        let voiceLock = try await VoiceLockManager.createLock(
            characterName: profile.name,
            candidateAudio: candidateWAV,
            designInstruction: designInstruction,
            modelManager: modelManager,
            modelRepo: modelRepo
        )
        print("Voice lock created")
        fflush(stdout)

        // Export .vox bundle — append to existing or create new
        let outputURL = URL(fileURLWithPath: output)
        let vox: VoxFile
        if FileManager.default.fileExists(atPath: outputURL.path) {
            vox = try VoxFile(contentsOf: outputURL)
            print("Opened existing \(output) to add \(ttsModel) embedding")
        } else {
            vox = VoxFile(name: voiceLock.characterName, description: designInstruction)
            vox.manifest.provenance = VoxManifest.Provenance(
                method: "synthesized",
                engine: "qwen3-tts",
                license: "CC0-1.0",
                notes: "Test voice generated via echada test-voice command."
            )
        }
        try VoxExporter.addClonePrompt(to: vox, data: voiceLock.clonePromptData, modelRepo: modelRepo)
        try VoxExporter.addSampleAudio(to: vox, data: candidateWAV, modelRepo: modelRepo)
        try vox.write(to: outputURL)

        print("Wrote \(outputURL.path)")
    }
}
