import ArgumentParser
import Foundation
import struct SwiftEchada.CharacterProfile
import SwiftProyecto
import SwiftVoxAlta

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
        let sampleSentence = "The world stretched out before them, vast and unforgiving, as the last light of evening painted the hills in shades of amber."

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
        let manifest = VoxExporter.buildManifest(from: voiceLock, voiceType: "designed")
        try VoxExporter.export(manifest: manifest, clonePromptData: voiceLock.clonePromptData, to: outputURL)
        try VoxExporter.updateSampleAudio(in: outputURL, sampleAudioData: candidateWAV)

        print("Wrote \(outputURL.path)")
    }
}
