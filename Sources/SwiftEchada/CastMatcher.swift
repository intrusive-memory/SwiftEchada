import SwiftHablare
import SwiftProyecto

/// Matches screenplay cast members to TTS voices using a local LLM.
public struct CastMatcher: Sendable {

    /// Result of a matching operation.
    public struct MatchResult: Sendable {
        public let updatedFrontMatter: ProjectFrontMatter
        public let matchedCount: Int
        public let skippedCount: Int
    }

    private let providerId: String
    private let languageCode: String?
    private let model: String
    private let force: Bool
    private let elevenLabsAPIKey: String?
    private let httpClient: (any ElevenLabsHTTPClient)?
    private let verbose: Bool

    public init(
        providerId: String,
        languageCode: String? = nil,
        model: String,
        force: Bool = false,
        elevenLabsAPIKey: String? = nil,
        httpClient: (any ElevenLabsHTTPClient)? = nil,
        verbose: Bool = false
    ) {
        self.providerId = providerId
        self.languageCode = languageCode
        self.model = model
        self.force = force
        self.elevenLabsAPIKey = elevenLabsAPIKey
        self.httpClient = httpClient
        self.verbose = verbose
    }

    /// Match cast members to voices using LLM selection.
    /// - Parameters:
    ///   - frontMatter: The project front matter containing the cast.
    ///   - queryFn: Function that sends a prompt to the LLM and returns the response.
    /// - Returns: A `MatchResult` with the updated front matter.
    public func match(
        frontMatter: ProjectFrontMatter,
        queryFn: @Sendable (String, String, String) async throws -> String
    ) async throws -> MatchResult {
        if providerId == ElevenLabsDefaults.providerScheme, let apiKey = elevenLabsAPIKey {
            return try await matchViaVoiceDesign(frontMatter: frontMatter, apiKey: apiKey)
        }
        let service = GenerationService()
        let voices = try await service.fetchVoices(from: providerId, languageCode: languageCode)
        return try await match(frontMatter: frontMatter, voices: voices, queryFn: queryFn)
    }

    /// Match cast members to voices using LLM selection with pre-fetched voices.
    /// - Parameters:
    ///   - frontMatter: The project front matter containing the cast.
    ///   - voices: Available voices to match against.
    ///   - queryFn: Function that sends a prompt to the LLM and returns the response.
    /// - Returns: A `MatchResult` with the updated front matter.
    public func match(
        frontMatter: ProjectFrontMatter,
        voices: [Voice],
        queryFn: @Sendable (String, String, String) async throws -> String
    ) async throws -> MatchResult {
        guard !voices.isEmpty else {
            throw CastMatcherError.noVoicesAvailable(providerId)
        }

        guard let cast = frontMatter.cast, !cast.isEmpty else {
            throw CastMatcherError.noCastMembers
        }

        let membersToMatch: [CastMember]
        if force {
            membersToMatch = cast
        } else {
            membersToMatch = cast.filter { !$0.hasVoice(for: providerId) }
        }

        var updatedCast = cast
        var matchedCount = 0
        var skippedCount = 0

        if verbose {
            print("[verbose] Fetched \(voices.count) voices from provider '\(providerId)'")
        }

        for member in membersToMatch {
            let prompt = buildPrompt(character: member, genre: frontMatter.genre, voices: voices)
            let systemPrompt = buildSystemPrompt()

            if verbose {
                print("[verbose] --- Matching: \(member.character) ---")
                print("[verbose] System prompt:\n\(systemPrompt)")
                print("[verbose] User prompt:\n\(prompt)")
            }

            do {
                let response = try await queryFn(prompt, systemPrompt, model)
                let voiceId = response.trimmingCharacters(in: .whitespacesAndNewlines)

                if verbose {
                    print("[verbose] LLM response: \(voiceId)")
                }

                guard let matchedVoice = voices.first(where: { $0.id == voiceId }) else {
                    if verbose {
                        print("[verbose] Voice ID '\(voiceId)' not found in catalog, retrying...")
                    }
                    // Retry once
                    let retryResponse = try await queryFn(prompt, systemPrompt, model)
                    let retryId = retryResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    if verbose {
                        print("[verbose] Retry response: \(retryId)")
                    }
                    guard let retryVoice = voices.first(where: { $0.id == retryId }) else {
                        if verbose {
                            print("[verbose] Retry also failed, skipping \(member.character)")
                        }
                        skippedCount += 1
                        continue
                    }
                    updateCast(&updatedCast, member: member, voiceId: retryVoice.id)
                    matchedCount += 1
                    continue
                }

                if verbose {
                    print("[verbose] Matched \(member.character) -> \(matchedVoice.name) (\(matchedVoice.id))")
                }
                updateCast(&updatedCast, member: member, voiceId: matchedVoice.id)
                matchedCount += 1
            } catch {
                if verbose {
                    print("[verbose] Error matching \(member.character): \(error)")
                }
                skippedCount += 1
            }
        }

        let updated = ProjectFrontMatter(
            type: frontMatter.type,
            title: frontMatter.title,
            author: frontMatter.author,
            created: frontMatter.created,
            description: frontMatter.description,
            season: frontMatter.season,
            episodes: frontMatter.episodes,
            genre: frontMatter.genre,
            tags: frontMatter.tags,
            episodesDir: frontMatter.episodesDir,
            audioDir: frontMatter.audioDir,
            filePattern: frontMatter.filePattern,
            exportFormat: frontMatter.exportFormat,
            cast: updatedCast,
            preGenerateHook: frontMatter.preGenerateHook,
            postGenerateHook: frontMatter.postGenerateHook,
            tts: frontMatter.tts
        )

        return MatchResult(
            updatedFrontMatter: updated,
            matchedCount: matchedCount,
            skippedCount: skippedCount
        )
    }

    private func matchViaVoiceDesign(
        frontMatter: ProjectFrontMatter,
        apiKey: String
    ) async throws -> MatchResult {
        guard let cast = frontMatter.cast, !cast.isEmpty else {
            throw CastMatcherError.noCastMembers
        }

        let membersToMatch: [CastMember]
        if force {
            membersToMatch = cast
        } else {
            membersToMatch = cast.filter { !$0.hasVoice(for: providerId) }
        }

        let client = ElevenLabsClient(apiKey: apiKey, httpClient: httpClient)
        var updatedCast = cast
        var matchedCount = 0
        var skippedCount = 0
        let lang = languageCode ?? "en"

        for member in membersToMatch {
            do {
                // Check if a voice already exists for this character name
                let existing = try await client.voices(search: member.character)
                if let match = existing.voices.first(where: {
                    $0.name.caseInsensitiveCompare(member.character) == .orderedSame
                }) {
                    if verbose {
                        print("[verbose] Found existing voice for \(member.character): \(match.voiceId)")
                    }
                    updateCast(&updatedCast, member: member, voiceId: match.voiceId)
                    matchedCount += 1
                    continue
                }

                if verbose {
                    print("[verbose] No existing voice found for \(member.character), designing new one")
                }
                let voiceId = try await designAndCreateVoice(
                    client: client, for: member, languageCode: lang
                )
                if verbose {
                    print("[verbose] Created voice for \(member.character) -> \(voiceId)")
                }
                updateCast(&updatedCast, member: member, voiceId: voiceId)
                matchedCount += 1
            } catch {
                if verbose {
                    print("[verbose] Failed to design voice for \(member.character): \(error)")
                }
                skippedCount += 1
            }
        }

        let updated = ProjectFrontMatter(
            type: frontMatter.type,
            title: frontMatter.title,
            author: frontMatter.author,
            created: frontMatter.created,
            description: frontMatter.description,
            season: frontMatter.season,
            episodes: frontMatter.episodes,
            genre: frontMatter.genre,
            tags: frontMatter.tags,
            episodesDir: frontMatter.episodesDir,
            audioDir: frontMatter.audioDir,
            filePattern: frontMatter.filePattern,
            exportFormat: frontMatter.exportFormat,
            cast: updatedCast,
            preGenerateHook: frontMatter.preGenerateHook,
            postGenerateHook: frontMatter.postGenerateHook,
            tts: frontMatter.tts
        )

        return MatchResult(
            updatedFrontMatter: updated,
            matchedCount: matchedCount,
            skippedCount: skippedCount
        )
    }

    private func designAndCreateVoice(
        client: ElevenLabsClient,
        for member: CastMember,
        languageCode: String
    ) async throws -> String {
        var description = member.voiceDescription ?? member.character
        if member.character.uppercased().contains("NARRATOR") {
            description = "Deep voice with gravitas and an English accent. " + description
        }
        // ElevenLabs requires at least 20 characters for voice_description
        if description.count < 20 {
            description = "A distinctive voice for the character \(description)"
        }
        if verbose {
            print("[verbose] --- Voice Design: \(member.character) ---")
            print("[verbose] Description: \(description)")
        }
        let previewText = "Hello, my name is \(member.character). I am a character in this story, and this is a preview of how my voice will sound when reading the script aloud."
        let response = try await client.designVoice(description: description, previewText: previewText)
        if verbose {
            print("[verbose] Got \(response.previews.count) preview(s)")
        }
        guard let preview = response.previews.first else {
            throw CastMatcherError.voiceDesignFailed(member.character)
        }
        let voice = try await client.createVoice(
            from: preview,
            name: member.character,
            description: description
        )
        if verbose {
            print("[verbose] Created voice: id=\(voice.voiceId) name=\(member.character)")
        }
        return voice.voiceId
    }

    private func buildSystemPrompt() -> String {
        var prompt = """
            You are a casting director assigning text-to-speech voices to screenplay characters.
            Given a character and a list of available voices, pick the single best voice match.
            Respond with ONLY the voice ID, nothing else.
            """
        if providerId == "apple" {
            prompt += "\nPrefer voices with quality labeled \"premium\" when available. " +
                "Only fall back to \"enhanced\" or \"default\" quality if no premium voice is a good fit."
        }
        return prompt
    }

    private func buildPrompt(character: CastMember, genre: String?, voices: [Voice]) -> String {
        let actorLine = character.actor ?? "unspecified"
        let genreLine = genre ?? "unspecified"
        let voiceDescLine = character.voiceDescription ?? "unspecified"

        var voiceList = ""
        for voice in voices {
            let gender = voice.gender ?? "unknown"
            let lang = voice.language ?? "unknown"
            let quality = voice.quality ?? "unknown"
            voiceList += "- \(voice.id) | \(voice.name) | \(gender) | \(lang) | quality: \(quality)\n"
        }

        return """
            Character: \(character.character)
            Voice Description: \(voiceDescLine)
            Actor: \(actorLine)
            Genre: \(genreLine)

            Available voices:
            \(voiceList)
            Which voice ID best fits this character?
            """
    }

    private func updateCast(_ cast: inout [CastMember], member: CastMember, voiceId: String) {
        if let index = cast.firstIndex(where: { $0.character == member.character }) {
            cast[index].voices = cast[index].voicesReplacingProvider(providerId, with: voiceId)
        }
    }
}

public enum CastMatcherError: Error, CustomStringConvertible {
    case noVoicesAvailable(String)
    case noCastMembers
    case voiceDesignFailed(String)

    public var description: String {
        switch self {
        case .noVoicesAvailable(let provider):
            "No voices available for provider '\(provider)'"
        case .noCastMembers:
            "No cast members found in project"
        case .voiceDesignFailed(let character):
            "Voice design returned no previews for '\(character)'"
        }
    }
}
