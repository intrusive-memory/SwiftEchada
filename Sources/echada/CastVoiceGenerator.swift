import Foundation
import struct SwiftEchada.CharacterAnalyzer
import struct SwiftEchada.CharacterProfile
import struct SwiftEchada.SampleSentenceGenerator
import SwiftProyecto
import SwiftVoxAlta

/// Generates custom on-device voices for cast members using SwiftVoxAlta.
///
/// Pass 2 of the `echada cast` pipeline: for each character, generates a `.vox` bundle
/// containing a voice lock (speaker embedding) using the VoiceDesigner → VoiceLockManager
/// → VoxExporter pipeline.
struct CastVoiceGenerator {

    /// Result of a voice generation operation.
    struct GenerateResult: Sendable {
        let updatedCast: [CastMember]
        let generatedCount: Int
        let skippedCount: Int
    }

    private let projectDirectory: URL
    private let forceRegenerate: Bool
    private let verbose: Bool

    init(projectDirectory: URL, forceRegenerate: Bool = false, verbose: Bool = false) {
        self.projectDirectory = projectDirectory
        self.forceRegenerate = forceRegenerate
        self.verbose = verbose
    }

    /// Generate .vox files for each cast member.
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

        for (index, member) in cast.enumerated() {
            let sanitizedName = member.character.replacingOccurrences(of: " ", with: "_")
            let voxPath = "voices/\(sanitizedName).vox"
            let voxURL = projectDirectory.appending(path: voxPath)

            // Skip if .vox already exists (unless force-regenerate)
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

            if verbose {
                print("[verbose] --- Generating voice: \(member.character) ---")
            }

            do {
                // Build CharacterProfile from voice description
                let profile = try await analyzer.analyze(
                    member: member,
                    queryFn: queryFn,
                    verbose: verbose
                )

                let designInstruction = VoiceDesigner.composeVoiceDescription(from: profile)
                if verbose {
                    print("[verbose] Voice description: \(designInstruction)")
                }

                // Generate sample sentence for this character
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

                // Generate candidate WAV via VoiceDesigner
                let candidateWAV = try await VoiceDesigner.generateCandidate(
                    profile: profile,
                    modelManager: modelManager,
                    sampleSentence: sampleSentence
                )

                if verbose {
                    print("[verbose] Generated candidate WAV (\(candidateWAV.count) bytes)")
                }

                // Create voice lock (speaker embedding)
                let voiceLock = try await VoiceLockManager.createLock(
                    characterName: member.character,
                    candidateAudio: candidateWAV,
                    designInstruction: designInstruction,
                    modelManager: modelManager
                )

                if verbose {
                    print("[verbose] Created voice lock for \(member.character)")
                }

                // Build manifest and export .vox bundle
                let manifest = VoxExporter.buildManifest(
                    from: voiceLock,
                    voiceType: "designed"
                )

                try VoxExporter.export(
                    manifest: manifest,
                    clonePromptData: voiceLock.clonePromptData,
                    to: voxURL
                )

                // Embed candidate WAV as preview sample
                try VoxExporter.updateSampleAudio(in: voxURL, sampleAudioData: candidateWAV)

                if verbose {
                    print("[verbose] Exported \(voxPath)")
                }

                // Update cast member with voxalta voice path
                updatedCast[index].voices = {
                    var v = member.voices; v["voxalta"] = voxPath; return v
                }()
                generatedCount += 1

            } catch {
                if verbose {
                    print("[verbose] Error generating voice for \(member.character): \(error)")
                }
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
