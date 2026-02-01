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

    public init(
        providerId: String,
        languageCode: String? = nil,
        model: String,
        force: Bool = false,
        elevenLabsAPIKey: String? = nil,
        httpClient: (any ElevenLabsHTTPClient)? = nil
    ) {
        self.providerId = providerId
        self.languageCode = languageCode
        self.model = model
        self.force = force
        self.elevenLabsAPIKey = elevenLabsAPIKey
        self.httpClient = httpClient
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
        if providerId == "elevenlabs", let apiKey = elevenLabsAPIKey {
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
            membersToMatch = cast.filter { !$0.hasVoices }
        }

        var updatedCast = cast
        var matchedCount = 0
        var skippedCount = 0

        for member in membersToMatch {
            let prompt = buildPrompt(character: member, genre: frontMatter.genre, voices: voices)
            let systemPrompt = buildSystemPrompt()

            do {
                let response = try await queryFn(prompt, systemPrompt, model)
                let voiceId = response.trimmingCharacters(in: .whitespacesAndNewlines)

                guard let matchedVoice = voices.first(where: { $0.id == voiceId }) else {
                    // Retry once
                    let retryResponse = try await queryFn(prompt, systemPrompt, model)
                    let retryId = retryResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let retryVoice = voices.first(where: { $0.id == retryId }) else {
                        skippedCount += 1
                        continue
                    }
                    let uri = buildVoiceURI(voice: retryVoice)
                    updateCast(&updatedCast, member: member, voiceURI: uri)
                    matchedCount += 1
                    continue
                }

                let uri = buildVoiceURI(voice: matchedVoice)
                updateCast(&updatedCast, member: member, voiceURI: uri)
                matchedCount += 1
            } catch {
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
            membersToMatch = cast.filter { !$0.hasVoices }
        }

        let client = ElevenLabsClient(apiKey: apiKey, httpClient: httpClient)
        var updatedCast = cast
        var matchedCount = 0
        var skippedCount = 0
        let lang = languageCode ?? "en"

        for member in membersToMatch {
            do {
                let voiceId = try await designAndCreateVoice(
                    client: client, for: member, languageCode: lang
                )
                let uri = "elevenlabs://\(lang)/\(voiceId)"
                updateCast(&updatedCast, member: member, voiceURI: uri)
                matchedCount += 1
            } catch {
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
        let description = member.voiceDescription ?? member.character
        let response = try await client.designVoice(description: description)
        guard let preview = response.previews.first else {
            throw CastMatcherError.voiceDesignFailed(member.character)
        }
        let voice = try await client.createVoice(
            from: preview,
            name: member.character,
            description: member.voiceDescription ?? ""
        )
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

    private func buildVoiceURI(voice: Voice) -> String {
        let lang = voice.language ?? languageCode ?? "en"
        return "\(voice.providerId)://\(lang)/\(voice.id)"
    }

    private func updateCast(_ cast: inout [CastMember], member: CastMember, voiceURI: String) {
        if let index = cast.firstIndex(where: { $0.character == member.character }) {
            cast[index].voices = [voiceURI]
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
