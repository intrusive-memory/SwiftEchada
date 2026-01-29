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
            episodesDir: nil,
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
              {"name": "BOB", "description": "Office worker"},
              {"name": "ALICE", "description": "Bob's colleague"}
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
            episodes: nil, genre: nil, tags: nil, episodesDir: nil,
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
            episodes: nil, genre: nil, tags: nil, episodesDir: nil,
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
            CastMember(character: "NARRATOR", actor: "Jane", voices: ["apple://en/ava"]),
        ]

        let frontMatter = ProjectFrontMatter(
            type: "screenplay", title: "Test", author: "A",
            created: Date(), description: nil, season: nil,
            episodes: nil, genre: nil, tags: nil, episodesDir: nil,
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
        #expect(updated.cast?.first?.voices == ["apple://en/ava"])
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
            episodes: nil, genre: nil, tags: nil, episodesDir: nil,
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
}
