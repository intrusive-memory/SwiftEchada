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
    /// - Parameter queryFn: A function that takes (userPrompt, systemPrompt) and returns the LLM response string.
    /// - Returns: Updated `ProjectFrontMatter` with the merged cast list.
    public func extractAll(
        queryFn: @Sendable (String, String) async throws -> String,
        progressFn: (@Sendable (String, Int, Int) -> Void)? = nil
    ) async throws -> ProjectFrontMatter {
        let fileURLs = try discoverFiles()
        var allExtracted: [[CharacterInfo]] = []
        let total = fileURLs.count

        for (index, fileURL) in fileURLs.enumerated() {
            progressFn?(fileURL.lastPathComponent, index + 1, total)
            do {
                let characters = try await extractCharacters(from: fileURL, queryFn: queryFn)
                allExtracted.append(characters)
            } catch is CocoaError {
                // Skip files that can't be read (e.g., binary formats)
                continue
            }
        }

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

        let systemPrompt = """
            You are a screenplay analyst. Extract all speaking characters from the provided screenplay.
            Return ONLY a JSON array with this exact format:
            [
              {"name": "CHARACTER_NAME", "description": "brief description"},
              ...
            ]

            Character names should be in UPPERCASE as they appear in the screenplay.
            Only include characters with dialogue (exclude action-only characters).
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

            // Merge characters from all chunks (deduplicate by name)
            let merger = CharacterMerger()
            let merged = merger.merge(extracted: allCharacters, existingCast: nil)
            return merged.map { CharacterInfo(name: $0.character, description: nil) }
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

        guard let enumerator = fm.enumerator(
            at: projectDirectory,
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

        return try JSONDecoder().decode([CharacterInfo].self, from: data)
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
