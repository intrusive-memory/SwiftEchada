import Foundation
import Testing
import SwiftProyecto
@testable import SwiftEchada

@Suite("CharacterExtractor Tests")
struct CharacterExtractorTests {

    @Test func parsesValidJSONFromQueryFn() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a test fountain file
        let fountainURL = tempDir.appendingPathComponent("test.fountain")
        try "INT. OFFICE - DAY\n\nBOB\nHello there.\n\nALICE\nHi Bob!\n".write(
            to: fountainURL, atomically: true, encoding: .utf8
        )

        let frontMatter = ProjectFrontMatter(
            type: "screenplay",
            title: "Test",
            author: "Author",
            created: Date(),
            description: nil,
            season: nil,
            episodes: nil,
            genre: nil,
            tags: nil,
            episodesDir: ".",
            audioDir: nil,
            filePattern: "*.fountain",
            exportFormat: nil,
            cast: nil,
            preGenerateHook: nil,
            postGenerateHook: nil,
            tts: nil
        )

        let extractor = CharacterExtractor(
            projectDirectory: tempDir,
            frontMatter: frontMatter
        )

        let mockResponse = """
            [
              {"name": "BOB", "description": "Office worker", "voiceDescription": "Friendly mid-range tenor"},
              {"name": "ALICE", "description": "Bob's colleague", "voiceDescription": "Bright, energetic soprano"}
            ]
            """

        let updated = try await extractor.extractAll { _, _ in
            mockResponse
        }

        #expect(updated.cast?.count == 2)
        let names = updated.cast?.map(\.character) ?? []
        #expect(names.contains("ALICE"))
        #expect(names.contains("BOB"))
    }

    @Test func handlesMarkdownCodeBlockResponse() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fountainURL = tempDir.appendingPathComponent("scene.fountain")
        try "NARRATOR\nOnce upon a time.\n".write(
            to: fountainURL, atomically: true, encoding: .utf8
        )

        let frontMatter = ProjectFrontMatter(
            type: "screenplay", title: "Test", author: "A",
            created: Date(), description: nil, season: nil,
            episodes: nil, genre: nil, tags: nil, episodesDir: ".",
            audioDir: nil, filePattern: "*.fountain", exportFormat: nil,
            cast: nil, preGenerateHook: nil, postGenerateHook: nil, tts: nil
        )

        let extractor = CharacterExtractor(
            projectDirectory: tempDir,
            frontMatter: frontMatter
        )

        let response = """
            ```json
            [{"name": "NARRATOR", "description": "Omniscient narrator"}]
            ```
            """

        let updated = try await extractor.extractAll { _, _ in response }
        #expect(updated.cast?.count == 1)
        #expect(updated.cast?.first?.character == "NARRATOR")
    }

    @Test func noFilesReturnsEmptyCast() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let frontMatter = ProjectFrontMatter(
            type: "screenplay", title: "Empty", author: "A",
            created: Date(), description: nil, season: nil,
            episodes: nil, genre: nil, tags: nil, episodesDir: ".",
            audioDir: nil, filePattern: "*.fountain", exportFormat: nil,
            cast: nil, preGenerateHook: nil, postGenerateHook: nil, tts: nil
        )

        let extractor = CharacterExtractor(
            projectDirectory: tempDir,
            frontMatter: frontMatter
        )

        let updated = try await extractor.extractAll { _, _ in "[]" }
        #expect(updated.cast?.isEmpty == true)
    }

    @Test func preservesExistingVoicesOnMerge() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fountainURL = tempDir.appendingPathComponent("ep1.fountain")
        try "NARRATOR\nHello.\n".write(to: fountainURL, atomically: true, encoding: .utf8)

        let existingCast = [
            CastMember(character: "NARRATOR", actor: "Jane", voices: ["apple": "com.apple.voice.premium.en-US.Ava"]),
        ]

        let frontMatter = ProjectFrontMatter(
            type: "screenplay", title: "Test", author: "A",
            created: Date(), description: nil, season: nil,
            episodes: nil, genre: nil, tags: nil, episodesDir: ".",
            audioDir: nil, filePattern: "*.fountain", exportFormat: nil,
            cast: existingCast, preGenerateHook: nil, postGenerateHook: nil, tts: nil
        )

        let extractor = CharacterExtractor(
            projectDirectory: tempDir,
            frontMatter: frontMatter
        )

        let updated = try await extractor.extractAll { _, _ in
            """
            [{"name": "NARRATOR", "description": "The narrator"}]
            """
        }

        #expect(updated.cast?.count == 1)
        #expect(updated.cast?.first?.voices == ["apple": "com.apple.voice.premium.en-US.Ava"])
        #expect(updated.cast?.first?.actor == "Jane")
    }

    @Test func malformedJSONThrows() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fountainURL = tempDir.appendingPathComponent("bad.fountain")
        try "CHAR\nDialog.\n".write(to: fountainURL, atomically: true, encoding: .utf8)

        let frontMatter = ProjectFrontMatter(
            type: "screenplay", title: "Test", author: "A",
            created: Date(), description: nil, season: nil,
            episodes: nil, genre: nil, tags: nil, episodesDir: ".",
            audioDir: nil, filePattern: "*.fountain", exportFormat: nil,
            cast: nil, preGenerateHook: nil, postGenerateHook: nil, tts: nil
        )

        let extractor = CharacterExtractor(
            projectDirectory: tempDir,
            frontMatter: frontMatter
        )

        await #expect(throws: (any Error).self) {
            _ = try await extractor.extractAll { _, _ in
                "This is not JSON at all"
            }
        }
    }

    @Test func largeFileTriggersChunking() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a screenplay with multiple scenes
        var content = ""
        for i in 1...10 {
            content += """
            INT. SCENE \(i) - DAY

            ALICE
            This is scene \(i) with dialogue.

            BOB
            Responding in scene \(i).


            """
        }

        let fountainURL = tempDir.appendingPathComponent("large.fountain")
        try content.write(to: fountainURL, atomically: true, encoding: .utf8)

        let frontMatter = ProjectFrontMatter(
            type: "screenplay", title: "Large Test", author: "A",
            created: Date(), description: nil, season: nil,
            episodes: nil, genre: nil, tags: nil, episodesDir: ".",
            audioDir: nil, filePattern: "*.fountain", exportFormat: nil,
            cast: nil, preGenerateHook: nil, postGenerateHook: nil, tts: nil
        )

        // Use a low maxTokens to reliably trigger chunking with small content
        let extractor = CharacterExtractor(
            projectDirectory: tempDir,
            frontMatter: frontMatter,
            maxTokens: 100
        )

        // Use actor for thread-safe counter
        actor QueryCounter {
            var count = 0
            func increment() -> Int {
                count += 1
                return count
            }
        }
        let counter = QueryCounter()

        let updated = try await extractor.extractAll { userPrompt, _ in
            let currentCount = await counter.increment()
            // Return different characters for different chunks to test merging
            if currentCount == 1 {
                return """
                [{"name": "ALICE", "description": "First character"}]
                """
            } else {
                return """
                [{"name": "BOB", "description": "Second character"}]
                """
            }
        }

        // Verify chunking occurred (multiple queries)
        let finalCount = await counter.count
        #expect(finalCount > 1)

        // Verify characters from all chunks were merged
        #expect(updated.cast?.count == 2)
        let names = updated.cast?.map(\.character).sorted() ?? []
        #expect(names == ["ALICE", "BOB"])
    }

    @Test func smallFileDoesNotTriggerChunking() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Small screenplay (<2000 tokens)
        let smallContent = """
        INT. OFFICE - DAY

        ALICE
        Hello.

        BOB
        Hi there.
        """

        let fountainURL = tempDir.appendingPathComponent("small.fountain")
        try smallContent.write(to: fountainURL, atomically: true, encoding: .utf8)

        let frontMatter = ProjectFrontMatter(
            type: "screenplay", title: "Small Test", author: "A",
            created: Date(), description: nil, season: nil,
            episodes: nil, genre: nil, tags: nil, episodesDir: ".",
            audioDir: nil, filePattern: "*.fountain", exportFormat: nil,
            cast: nil, preGenerateHook: nil, postGenerateHook: nil, tts: nil
        )

        let extractor = CharacterExtractor(
            projectDirectory: tempDir,
            frontMatter: frontMatter
        )

        actor QueryCounter {
            var count = 0
            func increment() { count += 1 }
        }
        let counter = QueryCounter()

        let updated = try await extractor.extractAll { _, _ in
            await counter.increment()
            return """
            [{"name": "ALICE", "description": "First"}, {"name": "BOB", "description": "Second"}]
            """
        }

        // Verify NO chunking occurred (single query per file)
        let queryCount = await counter.count
        #expect(queryCount == 1)
        #expect(updated.cast?.count == 2)
    }

    @Test func chunkingMergesCharactersAcrossChunks() async throws {
        // Use real large screenplay from podcast-mr-mr-charles project (38K file)
        let realProjectDir = URL(fileURLWithPath: "/Users/stovak/Projects/podcast-mr-mr-charles/episodes")
        guard FileManager.default.fileExists(atPath: realProjectDir.path) else {
            // Skip test if test project not available
            return
        }

        let frontMatter = ProjectFrontMatter(
            type: "screenplay", title: "Mr & Mr Charles", author: "A",
            created: Date(), description: nil, season: nil,
            episodes: nil, genre: nil, tags: nil, episodesDir: ".",
            audioDir: nil, filePattern: "08-the-missing-piece.fountain", exportFormat: nil,
            cast: nil, preGenerateHook: nil, postGenerateHook: nil, tts: nil
        )

        let extractor = CharacterExtractor(
            projectDirectory: realProjectDir,
            frontMatter: frontMatter
        )

        actor QueryCounter {
            var count = 0
            func increment() { count += 1 }
        }
        let counter = QueryCounter()

        let updated = try await extractor.extractAll { _, _ in
            await counter.increment()
            // All chunks return same characters (test deduplication)
            return """
            [
                {"name": "MITCH CHARLES", "description": "Photojournalist"},
                {"name": "BILLY CHARLES", "description": "Husband"},
                {"name": "NARRATOR", "description": "Narrator"}
            ]
            """
        }

        // Verify chunking occurred (38K file should split into multiple chunks)
        let chunkCount = await counter.count
        #expect(chunkCount > 1)

        // Verify characters were deduplicated (only 3 unique characters)
        #expect(updated.cast?.count == 3)
        let names = updated.cast?.map(\.character).sorted() ?? []
        #expect(names == ["BILLY CHARLES", "MITCH CHARLES", "NARRATOR"])
    }
}
