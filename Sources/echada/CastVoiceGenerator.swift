import Foundation
import struct SwiftEchada.SampleSentenceGenerator
import SwiftProyecto
import SwiftVoxAlta
@preconcurrency import VoxFormat
@preconcurrency import MLXAudioTTS
@preconcurrency import MLX
@preconcurrency import MLXLMCommon

/// Errors thrown by CastVoiceGenerator.
enum CastVoiceGeneratorError: LocalizedError {
    case unsupportedTTSModel(String, supported: [String])

    var errorDescription: String? {
        switch self {
        case .unsupportedTTSModel(let value, let supported):
            return "Unsupported TTS model variant '\(value)'. Supported values: \(supported.joined(separator: ", "))"
        }
    }
}

/// Generates custom on-device voices for cast members using SwiftVoxAlta.
///
/// For each character with a non-empty voice prompt, generates a `.vox` bundle
/// containing a voice lock (speaker embedding) using the VoiceDesign → VoiceLock
/// → VoxExporter pipeline.
///
/// Generation is split into two phases to avoid model thrashing:
///   Phase A: Load VoiceDesign model once, generate all candidate WAVs
///   Phase B: Load Base model once, create all voice locks and export .vox bundles
struct CastVoiceGenerator {

    /// Result of a voice generation operation.
    struct GenerateResult: Sendable {
        let updatedCast: [CastMember]
        let generatedCount: Int
        let skippedCount: Int
    }

    /// Intermediate data from Phase A (candidate generation) needed by Phase B (locking).
    private struct CandidateResult {
        let index: Int
        let member: CastMember
        let voicePrompt: String
        let candidateWAV: Data
        let voxPath: String
        let voxURL: URL
    }

    private let projectDirectory: URL
    private let forceRegenerate: Bool
    private let verbose: Bool
    private let ttsModelVariant: String

    init(projectDirectory: URL, forceRegenerate: Bool = false, verbose: Bool = false, ttsModelVariant: String = Qwen3TTSModelRepo.base1_7B.slug) {
        self.projectDirectory = projectDirectory
        self.forceRegenerate = forceRegenerate
        self.verbose = verbose
        self.ttsModelVariant = ttsModelVariant
    }

    /// The default model size slug.
    static let defaultModelSlug = Qwen3TTSModelRepo.base1_7B.slug

    /// Known TTS model variant strings.
    static let supportedVariants = Qwen3TTSModelRepo.supportedSlugs

    /// Resolves the TTS model variant string to a `Qwen3TTSModelRepo`.
    private func resolvedModelRepo() throws -> Qwen3TTSModelRepo {
        guard let repo = Qwen3TTSModelRepo(slug: ttsModelVariant) else {
            throw CastVoiceGeneratorError.unsupportedTTSModel(
                ttsModelVariant,
                supported: Self.supportedVariants.sorted()
            )
        }
        return repo
    }

    /// Generate .vox files for each cast member with a non-empty voice prompt.
    ///
    /// Members without a `voiceDescription` (or with an empty one) are silently skipped.
    func generate(cast: [CastMember]) async throws -> GenerateResult {
        let voicesDir = projectDirectory.appending(path: "voices")
        try FileManager.default.createDirectory(at: voicesDir, withIntermediateDirectories: true)

        let modelManager = VoxAltaModelManager()
        var updatedCast = cast
        var generatedCount = 0
        var skippedCount = 0

        // Determine which members need generation
        var membersToGenerate: [(index: Int, member: CastMember, voxPath: String, voxURL: URL)] = []

        for (index, member) in cast.enumerated() {
            // Skip members with no voice prompt
            guard let voiceDescription = member.voiceDescription, !voiceDescription.isEmpty else {
                if verbose {
                    print("[verbose] Skipping \(member.character) — no voice prompt")
                }
                skippedCount += 1
                continue
            }

            let sanitizedName = member.character.replacingOccurrences(of: " ", with: "_")
            let voxPath = "voices/\(sanitizedName).vox"
            let voxURL = projectDirectory.appending(path: voxPath)

            if FileManager.default.fileExists(atPath: voxURL.path) && !forceRegenerate {
                if verbose {
                    print("[verbose] Skipping \(member.character) — \(voxPath) already exists")
                }
                if member.voices["voxalta"] == nil {
                    updatedCast[index].voices = {
                        var v = member.voices; v["voxalta"] = voxPath; return v
                    }()
                }
                continue
            }

            membersToGenerate.append((index, member, voxPath, voxURL))
        }

        guard !membersToGenerate.isEmpty else {
            return GenerateResult(updatedCast: updatedCast, generatedCount: 0, skippedCount: skippedCount)
        }

        // --- Phase A: Generate all candidate WAVs (VoiceDesign model loaded once) ---
        print("Phase A: Generating candidate audio (\(membersToGenerate.count) characters, VoiceDesign 1.7B)...")
        fflush(stdout)

        var candidates: [CandidateResult] = []

        for item in membersToGenerate {
            let voicePrompt = item.member.voiceDescription!

            if verbose {
                print("[verbose] --- Generating voice: \(item.member.character) ---")
                print("[verbose] Prompt: \(voicePrompt)")
            }

            do {
                let sampleSentence = SampleSentenceGenerator.defaultSentence(for: item.member.character)
                if verbose {
                    print("[verbose] Sample sentence: \(sampleSentence)")
                }

                let candidateWAV = try await Self.generateCandidateWithPrompt(
                    voicePrompt: voicePrompt,
                    modelManager: modelManager,
                    sampleSentence: sampleSentence
                )

                if verbose {
                    print("[verbose] Generated candidate WAV (\(candidateWAV.count) bytes)")
                }

                candidates.append(CandidateResult(
                    index: item.index,
                    member: item.member,
                    voicePrompt: voicePrompt,
                    candidateWAV: candidateWAV,
                    voxPath: item.voxPath,
                    voxURL: item.voxURL
                ))

            } catch {
                print("  Error generating voice for \(item.member.character): \(error)")
                skippedCount += 1
            }
        }

        // Unload VoiceDesign model before loading Base model
        await modelManager.unloadModel()

        // --- Phase B: Create voice locks and export .vox bundles (Base model loaded once) ---
        let modelRepo = try resolvedModelRepo()
        print("Phase B: Creating voice locks (\(candidates.count) characters, Base \(ttsModelVariant))...")
        fflush(stdout)

        for candidate in candidates {
            if verbose {
                print("[verbose] --- Locking voice: \(candidate.member.character) ---")
            }

            do {
                let voiceLock = try await VoiceLockManager.createLock(
                    characterName: candidate.member.character,
                    candidateAudio: candidate.candidateWAV,
                    designInstruction: candidate.voicePrompt,
                    modelManager: modelManager,
                    modelRepo: modelRepo
                )

                if verbose {
                    print("[verbose] Created voice lock for \(candidate.member.character) (model: \(ttsModelVariant))")
                }

                let vox: VoxFile
                if !forceRegenerate, FileManager.default.fileExists(atPath: candidate.voxURL.path) {
                    vox = try VoxFile(contentsOf: candidate.voxURL)
                    if verbose {
                        print("[verbose] Opened existing \(candidate.voxPath) to add \(ttsModelVariant) embedding")
                    }
                } else {
                    vox = VoxFile(name: candidate.member.character, description: candidate.voicePrompt)
                    vox.manifest.provenance = VoxManifest.Provenance(
                        method: "synthesized",
                        engine: "qwen3-tts",
                        license: "CC0-1.0",
                        notes: "Voice generated from text prompt via echada cast command."
                    )
                }

                try VoxExporter.addClonePrompt(to: vox, data: voiceLock.clonePromptData, modelRepo: modelRepo)
                try VoxExporter.addSampleAudio(to: vox, data: candidate.candidateWAV, modelRepo: modelRepo)
                try vox.write(to: candidate.voxURL)

                if verbose {
                    print("[verbose] Exported \(candidate.voxPath)")
                }

                updatedCast[candidate.index].voices = {
                    var v = candidate.member.voices; v["voxalta"] = candidate.voxPath; return v
                }()
                generatedCount += 1

            } catch {
                print("  Error locking voice for \(candidate.member.character): \(error)")
                skippedCount += 1
            }
        }

        return GenerateResult(
            updatedCast: updatedCast,
            generatedCount: generatedCount,
            skippedCount: skippedCount
        )
    }

    /// Generate candidate audio using a voice prompt string directly.
    private static func generateCandidateWithPrompt(
        voicePrompt: String,
        modelManager: VoxAltaModelManager,
        sampleSentence: String
    ) async throws -> Data {
        let model = try await modelManager.loadModel(.voiceDesign1_7B)

        guard let qwenModel = model as? Qwen3TTSModel else {
            throw VoiceDesignerError.modelCastFailed
        }

        let audioArray = try await qwenModel.generate(
            text: sampleSentence,
            voice: voicePrompt,
            language: "en",
            generationParameters: GenerateParameters()
        )

        Stream.defaultStream(.gpu).synchronize()
        Memory.clearCache()

        return try AudioConversion.mlxArrayToWAVData(audioArray, sampleRate: qwenModel.sampleRate)
    }
}
