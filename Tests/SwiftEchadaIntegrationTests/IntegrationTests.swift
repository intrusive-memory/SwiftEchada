import Foundation
import Testing
import SwiftProyecto
@testable import SwiftEchada

@Suite("Integration Tests")
struct IntegrationTests {

    /// Returns the Fixtures directory URL.
    private var fixturesDir: URL {
        // Navigate from the test file location to the project root
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // SwiftEchadaTests/
            .deletingLastPathComponent()  // Tests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("Fixtures")
    }

    @Test func extractFromFixtureFountainFiles() async throws {
        let dir = fixturesDir
        guard FileManager.default.fileExists(atPath: dir.path) else {
            Issue.record("Fixtures directory not found at \(dir.path)")
            return
        }

        let frontMatter = ProjectFrontMatter(
            title: "Test Project", author: "Test",
            created: Date(), episodesDir: ".", filePattern: "*.fountain"
        )

        let extractor = CharacterExtractor(
            projectDirectory: dir,
            frontMatter: frontMatter
        )

        // Mock LLM response simulating character extraction
        let mockResponse = """
            [
              {"name": "BERNARD", "description": "A middle-aged man planning something sinister"},
              {"name": "KILLIAN", "description": "Bernard's gym companion and co-conspirator"},
              {"name": "MASON", "description": "Killian's husband, the victim"},
              {"name": "SYLVIA", "description": "Bernard's overbearing mother"},
              {"name": "DOG WALKER", "description": "A bystander at the trail"}
            ]
            """

        let updated = try await extractor.extractAll { _, _ in
            mockResponse
        }

        let cast = try #require(updated.cast)
        // Should have 5 characters from 2 fountain files (test.fountain, bigfish.fountain)
        // but since mock returns same response for both, dedup should still yield 5
        #expect(cast.count == 5)

        // Should be sorted alphabetically
        let names = cast.map(\.character)
        #expect(names == names.sorted())

        // All should have empty voices (no existing cast)
        for member in cast {
            #expect(member.voices.isEmpty)
        }
    }

    @Test func extractPreservesExistingCastFromFixtures() async throws {
        let dir = fixturesDir
        guard FileManager.default.fileExists(atPath: dir.path) else {
            Issue.record("Fixtures directory not found at \(dir.path)")
            return
        }

        let existingCast = [
            CastMember(character: "BERNARD", actor: "Tom", voices: ["apple": "com.apple.voice.premium.en-US.Ava"]),
        ]

        let frontMatter = ProjectFrontMatter(
            title: "Test", author: "A", created: Date(),
            episodesDir: ".", filePattern: "*.fountain", cast: existingCast
        )

        let extractor = CharacterExtractor(
            projectDirectory: dir,
            frontMatter: frontMatter
        )

        let updated = try await extractor.extractAll { _, _ in
            """
            [{"name": "BERNARD", "description": "Main character"}, {"name": "KILLIAN", "description": "Friend"}]
            """
        }

        let cast = try #require(updated.cast)
        let bernard = try #require(cast.first(where: { $0.character == "BERNARD" }))
        #expect(bernard.voices == ["apple://com.apple.voice.premium.en-US.Ava"])
        #expect(bernard.actor == "Tom")

        let killian = try #require(cast.first(where: { $0.character == "KILLIAN" }))
        #expect(killian.voices.isEmpty)
    }

    @Test func extractWithMultipleFilePatterns() async throws {
        let dir = fixturesDir
        guard FileManager.default.fileExists(atPath: dir.path) else {
            Issue.record("Fixtures directory not found at \(dir.path)")
            return
        }

        let frontMatter = ProjectFrontMatter(
            title: "Test", author: "A", created: Date(),
            episodesDir: ".", filePattern: FilePattern(["*.fountain", "*.highland"])
        )

        let extractor = CharacterExtractor(
            projectDirectory: dir,
            frontMatter: frontMatter
        )

        let counter = CallCounterActor()
        let updated = try await extractor.extractAll { _, _ in
            await counter.increment()
            return """
            [{"name": "CHAR_A"}]
            """
        }

        // Should have found both .fountain and .highland files
        let callsMade = await counter.count
        #expect(callsMade > 2, "Expected queries for multiple file types, got \(callsMade)")

        // All deduplicated to one character
        #expect(updated.cast?.count == 1)
    }
}

private actor CallCounterActor {
    var count = 0
    func increment() {
        count += 1
    }
}
