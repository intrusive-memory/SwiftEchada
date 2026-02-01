import Foundation
import SwiftProyecto

/// Orchestrates character extraction from screenplay files using a provided LLM query function.
public struct CharacterExtractor: Sendable {

    private let projectDirectory: URL
    private let frontMatter: ProjectFrontMatter

    public init(projectDirectory: URL, frontMatter: ProjectFrontMatter) {
        self.projectDirectory = projectDirectory
        self.frontMatter = frontMatter
    }

    /// Extract characters from all discovered screenplay files and return updated front matter.
    ///
    /// - Parameters:
    ///   - queryFn: A function that takes (userPrompt, systemPrompt) and returns the LLM response string.
    ///   - progressFn: Optional callback reporting (filename, completedCount, total).
    ///   - maxConcurrency: Maximum number of files to process in parallel (default 4).
    /// - Returns: Updated `ProjectFrontMatter` with the merged cast list.
    public func extractAll(
        queryFn: @escaping @Sendable (String, String) async throws -> String,
        progressFn: (@Sendable (String, Int, Int) -> Void)? = nil,
        maxConcurrency: Int = 4
    ) async throws -> ProjectFrontMatter {
        let fileURLs = try discoverFiles()
        let total = fileURLs.count
        let counter = ProgressCounter()

        let results: [(Int, [CharacterInfo])] = try await withThrowingTaskGroup(
            of: (Int, [CharacterInfo])?.self
        ) { group in
            var collected: [(Int, [CharacterInfo])] = []
            var nextIndex = 0

            // Seed initial batch
            for _ in 0..<min(maxConcurrency, total) {
                let idx = nextIndex
                let fileURL = fileURLs[idx]
                nextIndex += 1
                group.addTask {
                    do {
                        let characters = try await self.extractCharacters(from: fileURL, queryFn: queryFn)
                        let completed = await counter.increment()
                        progressFn?(fileURL.lastPathComponent, completed, total)
                        return (idx, characters)
                    } catch is CocoaError {
                        let completed = await counter.increment()
                        progressFn?(fileURL.lastPathComponent, completed, total)
                        return nil
                    }
                }
            }

            // As each task completes, launch the next
            for try await result in group {
                if let result { collected.append(result) }
                if nextIndex < total {
                    let idx = nextIndex
                    let fileURL = fileURLs[idx]
                    nextIndex += 1
                    group.addTask {
                        do {
                            let characters = try await self.extractCharacters(from: fileURL, queryFn: queryFn)
                            let completed = await counter.increment()
                            progressFn?(fileURL.lastPathComponent, completed, total)
                            return (idx, characters)
                        } catch is CocoaError {
                            let completed = await counter.increment()
                            progressFn?(fileURL.lastPathComponent, completed, total)
                            return nil
                        }
                    }
                }
            }

            return collected
        }

        // Sort by original index to maintain deterministic merge order
        let allExtracted = results.sorted { $0.0 < $1.0 }.map(\.1)

        let merger = CharacterMerger()
        let mergedCast = merger.merge(extracted: allExtracted, existingCast: frontMatter.cast)

        return ProjectFrontMatter(
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
            cast: mergedCast,
            preGenerateHook: frontMatter.preGenerateHook,
            postGenerateHook: frontMatter.postGenerateHook,
            tts: frontMatter.tts
        )
    }

    /// Extract characters from a single screenplay file.
    /// For large files, automatically chunks by scenes to fit within token limits.
    public func extractCharacters(
        from fileURL: URL,
        queryFn: @Sendable (String, String) async throws -> String
    ) async throws -> [CharacterInfo] {
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        let title = frontMatter.title
        let genre = frontMatter.genre ?? "unspecified"
        let tags = frontMatter.tags?.joined(separator: ", ") ?? "none"

        let systemPrompt = """
            You are a screenplay analyst extracting speaking characters from a \(genre) project titled "\(title)" (tags: \(tags)).

            Return ONLY a JSON array with this exact format:
            [
              {"name": "CHARACTER NAME", "description": "brief role description", "voiceDescription": "voice qualities for TTS casting"}
            ]

            Rules:
            - Character names must be UPPERCASE with NO parentheticals (remove V.O., O.S., CONT'D, etc.)
            - Only include characters with dialogue (exclude action-only characters)
            - "description" should be a brief role summary (1 sentence)
            - "voiceDescription" should describe ideal voice qualities for text-to-speech casting, including: pitch (high/low), pace (fast/slow), tone (warm/gravelly/nasal/breathy), accent if relevant, age range, energy level, and emotional quality

            Example output:
            [
              {"name": "NARRATOR", "description": "Omniscient storyteller guiding the audience", "voiceDescription": "Deep, warm baritone with measured pacing and gravitas, middle-aged, calm authority"},
              {"name": "SARAH", "description": "Young detective solving her first case", "voiceDescription": "Clear alto, quick-paced and energetic, late 20s, confident with occasional nervous edge"}
            ]
            """

        // Check if content needs chunking (conservative limit: 2000 tokens ≈ 8000 chars)
        let needsChunking = estimateTokens(content) > 2000

        if needsChunking {
            // Split into scene-based chunks and extract from each
            let chunks = chunkScreenplay(content, maxTokens: 2000)
            var allCharacters: [[CharacterInfo]] = []

            for chunk in chunks {
                let userPrompt = "Extract characters from this screenplay:\n\n\(chunk)"
                let response = try await queryFn(userPrompt, systemPrompt)
                let characters = try parseCharacters(from: response)
                allCharacters.append(characters)
            }

            // Deduplicate characters across chunks, keeping first-seen description/voiceDescription
            var seen: [String: CharacterInfo] = [:]
            var order: [String] = []
            for chunk in allCharacters {
                for character in chunk {
                    let key = character.name.lowercased().trimmingCharacters(in: .whitespaces)
                    guard !key.isEmpty else { continue }
                    if seen[key] == nil {
                        seen[key] = character
                        order.append(key)
                    }
                }
            }
            return order.compactMap { seen[$0] }
        } else {
            // Small file - process as single unit
            let userPrompt = "Extract characters from this screenplay:\n\n\(content)"
            let response = try await queryFn(userPrompt, systemPrompt)
            return try parseCharacters(from: response)
        }
    }

    // MARK: - Private

    private func discoverFiles() throws -> [URL] {
        let patterns = frontMatter.resolvedFilePatterns
        let fm = FileManager.default

        // Extract extensions from glob patterns (e.g., "*.fountain" → "fountain")
        var extensions: Set<String> = []
        var hasWildcard = false
        for pattern in patterns {
            if pattern.hasPrefix("*.") {
                extensions.insert(String(pattern.dropFirst(2)).lowercased())
            } else {
                hasWildcard = true
            }
        }

        let searchRoot = projectDirectory.appending(path: frontMatter.resolvedEpisodesDir)
        guard let enumerator = fm.enumerator(
            at: searchRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [URL] = []
        for case let url as URL in enumerator {
            if hasWildcard || extensions.isEmpty {
                results.append(url)
            } else if extensions.contains(url.pathExtension.lowercased()) {
                results.append(url)
            }
        }

        return results.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func parseCharacters(from response: String) throws -> [CharacterInfo] {
        // Extract JSON array from response (handle markdown code blocks)
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString: String

        if let start = trimmed.range(of: "["),
           let end = trimmed.range(of: "]", options: .backwards) {
            jsonString = String(trimmed[start.lowerBound...end.lowerBound])
        } else {
            jsonString = trimmed
        }

        guard let data = jsonString.data(using: .utf8) else {
            return []
        }

        let characters = try JSONDecoder().decode([CharacterInfo].self, from: data)
        return characters.map { CharacterInfo(name: normalizeCharacterName($0.name), description: $0.description, voiceDescription: $0.voiceDescription) }
    }

    /// Strip parentheticals like (V.O.), (O.S.), (CONT'D) from character names.
    private func normalizeCharacterName(_ name: String) -> String {
        name.replacingOccurrences(of: #"\s*\(.*?\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    /// Estimate token count (rough approximation: 1 token ≈ 4 characters)
    private func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }

    /// Split screenplay into scene-based chunks that fit within token limits
    private func chunkScreenplay(_ content: String, maxTokens: Int) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var scenes: [String] = []
        var currentScene: [String] = []

        // Split into scenes based on scene headings
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if isSceneHeading(trimmed) {
                // Start new scene
                if !currentScene.isEmpty {
                    scenes.append(currentScene.joined(separator: "\n"))
                    currentScene = []
                }
            }
            currentScene.append(line)
        }

        // Add final scene
        if !currentScene.isEmpty {
            scenes.append(currentScene.joined(separator: "\n"))
        }

        // Group scenes into chunks that fit token limits
        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentChunkTokens = 0
        let maxChunkTokens = maxTokens

        for scene in scenes {
            let sceneTokens = estimateTokens(scene)

            // If single scene exceeds limit, add it as its own chunk
            if sceneTokens > maxChunkTokens {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.joined(separator: "\n\n"))
                    currentChunk = []
                    currentChunkTokens = 0
                }
                chunks.append(scene)
                continue
            }

            // If adding this scene would exceed limit, start new chunk
            if currentChunkTokens + sceneTokens > maxChunkTokens {
                chunks.append(currentChunk.joined(separator: "\n\n"))
                currentChunk = [scene]
                currentChunkTokens = sceneTokens
            } else {
                currentChunk.append(scene)
                currentChunkTokens += sceneTokens
            }
        }

        // Add final chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: "\n\n"))
        }

        return chunks
    }

    /// Check if a line is a Fountain scene heading
    private func isSceneHeading(_ line: String) -> Bool {
        let upper = line.uppercased()
        let sceneHeadingPrefixes = [
            "INT./EXT.", "INT/EXT.", "INT.", "EXT.", "I/E.", "EST.", "INT ", "EXT "
        ]

        for prefix in sceneHeadingPrefixes {
            if upper.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }
}

/// Thread-safe progress counter for concurrent file extraction.
private actor ProgressCounter {
    private var count = 0

    func increment() -> Int {
        count += 1
        return count
    }
}

public enum CharacterExtractorError: Error, CustomStringConvertible {
    case noFilesFound(String)
    case malformedResponse(String)

    public var description: String {
        switch self {
        case .noFilesFound(let pattern):
            "No screenplay files found matching pattern '\(pattern)'"
        case .malformedResponse(let detail):
            "Could not parse character list from LLM response: \(detail)"
        }
    }
}
