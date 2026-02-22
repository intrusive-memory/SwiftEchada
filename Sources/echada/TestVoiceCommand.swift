import ArgumentParser
import Foundation
import struct SwiftEchada.CharacterProfile
import struct SwiftEchada.SampleSentenceGenerator
import SwiftProyecto
import SwiftVoxAlta
@preconcurrency import VoxFormat

struct TestVoiceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test-voice",
        abstract: "Generate a test .vox file for integration testing.",
        shouldDisplay: false
    )

    @Option(name: .long, help: "Output path for the .vox file.")
    var output: String

    func run() async throws {
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
        print("Generating candidate voice...")
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
        print("Creating voice lock...")
        fflush(stdout)
        let voiceLock = try await VoiceLockManager.createLock(
            characterName: profile.name,
            candidateAudio: candidateWAV,
            designInstruction: designInstruction,
            modelManager: modelManager
        )
        print("Voice lock created")
        fflush(stdout)

        // Export .vox bundle
        let outputURL = URL(fileURLWithPath: output)
        let manifest = VoxManifest(
            voxVersion: "0.2.0",
            id: UUID().uuidString.lowercased(),
            created: Date(),
            voice: VoxManifest.Voice(
                name: voiceLock.characterName,
                description: designInstruction
            ),
            provenance: VoxManifest.Provenance(
                method: "designed",
                engine: "qwen3-tts-voicedesign-1.7b"
            )
        )
        let vox = VoxFile(
            manifest: manifest,
            referenceAudio: ["sample-audio.wav": candidateWAV],
            embeddings: ["qwen3-tts/1.7b/clone-prompt.bin": voiceLock.clonePromptData]
        )
        let writer = VoxWriter()
        try writer.write(vox, to: outputURL)

        print("Wrote \(outputURL.path)")
    }
}
