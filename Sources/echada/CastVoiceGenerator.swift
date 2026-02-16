import Foundation
import SwiftEchada
import enum SwiftProyecto.Gender
import struct SwiftProyecto.CastMember
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
    ///   - queryFn: LLM query function for parsing voice descriptions into CharacterProfiles.
    ///   - model: The LLM model identifier.
    /// - Returns: A `GenerateResult` with updated cast and counts.
    func generate(
        cast: [CastMember],
        queryFn: @escaping @Sendable (String, String) async throws -> String,
        model: String
    ) async throws -> GenerateResult {
        let voicesDir = projectDirectory.appending(path: "voices")
        try FileManager.default.createDirectory(at: voicesDir, withIntermediateDirectories: true)

        let modelManager = VoxAltaModelManager()
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
                // Ensure the cast member has the voxalta voice path
                if member.voices["voxalta"] == nil {
                    updatedCast[index].voices = { var v = member.voices; v["voxalta"] = voxPath; return v }()
                }
                continue
            }

            if verbose {
                print("[verbose] --- Generating voice: \(member.character) ---")
            }

            do {
                // Build CharacterProfile from voice description
                let profile = try await buildProfile(
                    for: member, queryFn: queryFn, model: model
                )

                if verbose {
                    let desc = VoiceDesigner.composeVoiceDescription(from: profile)
                    print("[verbose] Voice description: \(desc)")
                }

                // Generate candidate WAV
                let candidateWAV = try await VoiceDesigner.generateCandidate(
                    profile: profile,
                    modelManager: modelManager
                )

                if verbose {
                    print("[verbose] Generated candidate WAV (\(candidateWAV.count) bytes)")
                }

                // Create voice lock (speaker embedding)
                let designInstruction = VoiceDesigner.composeVoiceDescription(from: profile)
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
                updatedCast[index].voices = { var v = member.voices; v["voxalta"] = voxPath; return v }()
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

    // MARK: - Private

    /// Build a CharacterProfile from a CastMember's voice description using LLM structured output,
    /// with heuristic fallback on parse failure.
    private func buildProfile(
        for member: CastMember,
        queryFn: @escaping @Sendable (String, String) async throws -> String,
        model: String
    ) async throws -> CharacterProfile {
        let description = member.voiceDescription ?? member.character

        let systemPrompt = """
            You are a voice profile analyzer. Given a character and voice description, \
            return a JSON object with these exact fields:
            {
              "name": "CHARACTER NAME (uppercase)",
              "gender": "male" or "female" or "nonBinary" or "unknown",
              "ageRange": "e.g. 30s, elderly, young adult",
              "description": "the full voice description",
              "voiceTraits": ["trait1", "trait2"],
              "summary": "concise 1-sentence summary for voice synthesis"
            }
            Return ONLY the JSON object, nothing else.
            """

        let userPrompt = """
            Character: \(member.character)
            Gender: \(member.gender?.displayName ?? "not specified")
            Voice description: \(description)
            """

        do {
            let response = try await queryFn(userPrompt, systemPrompt)
            if let profile = parseProfile(from: response) {
                return profile
            }
        } catch {
            if verbose {
                print("[verbose] LLM profile parse failed for \(member.character), using heuristic fallback")
            }
        }

        // Heuristic fallback
        return CharacterProfile(
            name: member.character.uppercased(),
            gender: mapGender(member.gender),
            ageRange: "adult",
            description: description,
            voiceTraits: description.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty },
            summary: description
        )
    }

    /// Parse a CharacterProfile from LLM JSON response.
    private func parseProfile(from response: String) -> CharacterProfile? {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract JSON object from response (handle markdown code blocks)
        let jsonString: String
        if let start = trimmed.range(of: "{"),
           let end = trimmed.range(of: "}", options: .backwards) {
            jsonString = String(trimmed[start.lowerBound...end.lowerBound])
        } else {
            jsonString = trimmed
        }

        guard let data = jsonString.data(using: .utf8) else { return nil }

        struct ProfileJSON: Decodable {
            let name: String
            let gender: String
            let ageRange: String
            let description: String
            let voiceTraits: [String]
            let summary: String
        }

        guard let parsed = try? JSONDecoder().decode(ProfileJSON.self, from: data) else {
            return nil
        }

        let gender: SwiftVoxAlta.Gender
        switch parsed.gender.lowercased() {
        case "male": gender = .male
        case "female": gender = .female
        case "nonbinary": gender = .nonBinary
        default: gender = .unknown
        }

        return CharacterProfile(
            name: parsed.name,
            gender: gender,
            ageRange: parsed.ageRange,
            description: parsed.description,
            voiceTraits: parsed.voiceTraits,
            summary: parsed.summary
        )
    }

    /// Map SwiftProyecto Gender to SwiftVoxAlta Gender.
    private func mapGender(_ gender: Gender?) -> SwiftVoxAlta.Gender {
        switch gender {
        case .male: return .male
        case .female: return .female
        case .nonBinary: return .nonBinary
        case .notSpecified, .none: return .unknown
        }
    }
}
