import Foundation
import struct SwiftEchada.CharacterProfile
import struct SwiftEchada.SampleSentenceGenerator
import SwiftVoxAlta
@preconcurrency import MLXAudioTTS
@preconcurrency import MLX
@preconcurrency import MLXLMCommon

/// Composes voice descriptions and generates candidate WAV audio for voice design.
///
/// Uses the VoiceDesign variant of Qwen3-TTS to synthesize audio from a text description,
/// producing candidate voice samples that can be locked into `.vox` bundles.
enum VoiceDesigner {

    /// Compose a natural-language voice description string from a `CharacterProfile`.
    ///
    /// The resulting string is passed as the `voice` parameter to the VoiceDesign model's
    /// `generate()` method.
    static func composeVoiceDescription(from profile: CharacterProfile) -> String {
        var parts: [String] = []

        // Gender and age
        let genderStr: String
        switch profile.gender {
        case .male: genderStr = "male"
        case .female: genderStr = "female"
        case .nonBinary: genderStr = "non-binary"
        case .notSpecified: genderStr = "person"
        }
        parts.append("A \(profile.ageRange) \(genderStr)")

        // Voice traits
        if !profile.voiceTraits.isEmpty {
            let traits = profile.voiceTraits.prefix(5).joined(separator: ", ")
            parts.append("with a \(traits) voice")
        }

        // Summary for additional color
        if !profile.summary.isEmpty && profile.summary != profile.description {
            parts.append("— \(profile.summary)")
        }

        return parts.joined(separator: " ")
    }

    /// Generate a single candidate WAV audio sample for a character profile.
    ///
    /// - Parameters:
    ///   - profile: The character profile to design a voice for.
    ///   - modelManager: The VoxAlta model manager.
    ///   - sampleSentence: The text to speak in the generated audio.
    ///     Defaults to a simple greeting.
    /// - Returns: WAV format Data (24kHz, 16-bit PCM, mono).
    static func generateCandidate(
        profile: CharacterProfile,
        modelManager: VoxAltaModelManager,
        sampleSentence: String? = nil
    ) async throws -> Data {
        let model = try await modelManager.loadModel(.voiceDesign1_7B)

        guard let qwenModel = model as? Qwen3TTSModel else {
            throw VoiceDesignerError.modelCastFailed
        }

        let voiceDescription = composeVoiceDescription(from: profile)
        let text = sampleSentence
            ?? SampleSentenceGenerator.defaultSentence(for: profile.name)

        let audioArray = try await qwenModel.generate(
            text: text,
            voice: voiceDescription,
            language: "en",
            generationParameters: GenerateParameters(
                maxTokens: 16384,
                temperature: 0.6,
                topP: 0.6,
                repetitionPenalty: 1.5
            )
        )

        // Flush GPU state after generation
        Stream.defaultStream(.gpu).synchronize()
        Memory.clearCache()

        return try AudioConversion.mlxArrayToWAVData(audioArray, sampleRate: qwenModel.sampleRate)
    }

    /// Generate multiple candidate WAV audio samples for a character profile.
    ///
    /// - Parameters:
    ///   - profile: The character profile to design a voice for.
    ///   - count: Number of candidates to generate.
    ///   - modelManager: The VoxAlta model manager.
    ///   - sampleSentence: The text to speak in each generated sample.
    /// - Returns: Array of WAV format Data.
    static func generateCandidates(
        profile: CharacterProfile,
        count: Int = 3,
        modelManager: VoxAltaModelManager,
        sampleSentence: String? = nil
    ) async throws -> [Data] {
        var candidates: [Data] = []
        for _ in 0..<count {
            let candidate = try await generateCandidate(
                profile: profile,
                modelManager: modelManager,
                sampleSentence: sampleSentence
            )
            candidates.append(candidate)
        }
        return candidates
    }
}

enum VoiceDesignerError: Error, CustomStringConvertible {
    case modelCastFailed

    var description: String {
        switch self {
        case .modelCastFailed:
            "Loaded model is not a Qwen3TTSModel."
        }
    }
}
