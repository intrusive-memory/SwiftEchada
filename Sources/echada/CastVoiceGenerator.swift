import Foundation
import struct SwiftEchada.CharacterAnalyzer
import struct SwiftEchada.CharacterProfile
import struct SwiftEchada.SampleSentenceGenerator
import SwiftProyecto
import SwiftVoxAlta
@preconcurrency import VoxFormat

/// Generates custom on-device voices for cast members using SwiftVoxAlta.
///
/// Pass 2 of the `echada cast` pipeline: for each character, generates a `.vox` bundle
/// containing a voice lock (speaker embedding) using the VoiceDesigner → VoiceLockManager
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
        let profile: CharacterProfile
        let designInstruction: String
        let candidateWAV: Data
        let voxPath: String
        let voxURL: URL
    }

    private let projectDirectory: URL
    private let forceRegenerate: Bool
    private let verbose: Bool
    private let ttsModelVariant: String

    init(projectDirectory: URL, forceRegenerate: Bool = false, verbose: Bool = false, ttsModelVariant: String = "1.7b") {
        self.projectDirectory = projectDirectory
        self.forceRegenerate = forceRegenerate
        self.verbose = verbose
        self.ttsModelVariant = ttsModelVariant
    }

    /// Resolves the TTS model variant string to a `Qwen3TTSModelRepo`.
    private var resolvedModelRepo: Qwen3TTSModelRepo {
        switch ttsModelVariant.lowercased() {
        case "0.6b":
            return .base0_6B
        default:
            return .base1_7B
        }
    }

    /// Generate .vox files for each cast member.
    ///
    /// Uses a two-phase approach to avoid model thrashing:
    ///   Phase A loads VoiceDesign 1.7B once for all candidate audio generation.
    ///   Phase B loads the Base model once for all voice lock creation and .vox export.
    ///
    /// - Parameters:
    ///   - cast: The cast list (should already have voice descriptions from Pass 1).
    ///   - queryFn: LLM query function for building CharacterProfiles.
    ///   - model: The LLM model identifier (unused here, reserved for future use).
    /// - Returns: A `GenerateResult` with updated cast and counts.
    func generate(
        cast: [CastMember],
        queryFn: @escaping @Sendable (String, String) async throws -> String,
        model: String
    ) async throws -> GenerateResult {
        let voicesDir = projectDirectory.appending(path: "voices")
        try FileManager.default.createDirectory(at: voicesDir, withIntermediateDirectories: true)

        let modelManager = VoxAltaModelManager()
        let analyzer = CharacterAnalyzer()
        let sentenceGen = SampleSentenceGenerator()
        var updatedCast = cast
        var generatedCount = 0
        var skippedCount = 0

        // Determine which members need generation
        var membersToGenerate: [(index: Int, member: CastMember, voxPath: String, voxURL: URL)] = []

        for (index, member) in cast.enumerated() {
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
            return GenerateResult(updatedCast: updatedCast, generatedCount: 0, skippedCount: 0)
        }

        // --- Phase A: Generate all candidate WAVs (VoiceDesign model loaded once) ---
        print("Phase A: Generating candidate audio (\(membersToGenerate.count) characters, VoiceDesign 1.7B)...")
        fflush(stdout)

        var candidates: [CandidateResult] = []

        for item in membersToGenerate {
            if verbose {
                print("[verbose] --- Designing voice: \(item.member.character) ---")
            }

            do {
                let profile = try await analyzer.analyze(
                    member: item.member,
                    queryFn: queryFn,
                    verbose: verbose
                )

                let designInstruction = VoiceDesigner.composeVoiceDescription(from: profile)
                if verbose {
                    print("[verbose] Voice description: \(designInstruction)")
                }

                let sampleSentence: String
                do {
                    sampleSentence = try await sentenceGen.generate(
                        from: profile,
                        queryFn: queryFn
                    )
                } catch {
                    sampleSentence = SampleSentenceGenerator.defaultSentence(for: profile.name)
                }

                if verbose {
                    print("[verbose] Sample sentence: \(sampleSentence)")
                }

                let candidateWAV = try await VoiceDesigner.generateCandidate(
                    profile: profile,
                    modelManager: modelManager,
                    sampleSentence: sampleSentence
                )

                if verbose {
                    print("[verbose] Generated candidate WAV (\(candidateWAV.count) bytes)")
                }

                candidates.append(CandidateResult(
                    index: item.index,
                    member: item.member,
                    profile: profile,
                    designInstruction: designInstruction,
                    candidateWAV: candidateWAV,
                    voxPath: item.voxPath,
                    voxURL: item.voxURL
                ))

            } catch {
                print("  Error designing voice for \(item.member.character): \(error)")
                skippedCount += 1
            }
        }

        // Unload VoiceDesign model before loading Base model
        await modelManager.unloadModel()

        // --- Phase B: Create voice locks and export .vox bundles (Base model loaded once) ---
        let modelRepo = resolvedModelRepo
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
                    designInstruction: candidate.designInstruction,
                    modelManager: modelManager,
                    modelRepo: modelRepo
                )

                if verbose {
                    print("[verbose] Created voice lock for \(candidate.member.character) (model: \(ttsModelVariant))")
                }

                // Build .vox bundle
                let voxDescription = candidate.member.voiceDescription ?? candidate.designInstruction
                let vox: VoxFile
                if !forceRegenerate, FileManager.default.fileExists(atPath: candidate.voxURL.path) {
                    vox = try VoxFile(contentsOf: candidate.voxURL)
                    if verbose {
                        print("[verbose] Opened existing \(candidate.voxPath) to add \(ttsModelVariant) embedding")
                    }
                } else {
                    vox = VoxFile(name: candidate.member.character, description: voxDescription)
                }

                let slug = VoxExporter.modelSizeSlug(for: modelRepo)
                try vox.add(voiceLock.clonePromptData, at: VoxExporter.clonePromptPath(for: modelRepo), metadata: [
                    "model": modelRepo.rawValue,
                    "engine": "qwen3-tts",
                    "format": "bin",
                    "description": "Clone prompt for voice cloning (\(slug))",
                ])
                try vox.add(candidate.candidateWAV, at: VoxExporter.sampleAudioPath, metadata: [
                    "model": modelRepo.rawValue,
                    "engine": "qwen3-tts",
                    "format": "wav",
                    "description": "Engine-generated voice sample",
                ])
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
}
