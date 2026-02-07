import ArgumentParser
import Foundation
import SwiftBruja
import SwiftEchada
import SwiftProyecto

struct ExtractCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "extract",
        abstract: "Extract characters from screenplay files using a local LLM."
    )

    @Option(name: .long, help: "Path to PROJECT.md file.")
    var project: String = "PROJECT.md"

    @Option(name: .long, help: "LLM model identifier for Bruja.")
    var model: String = Bruja.defaultModel

    @Flag(name: .long, help: "Preview extraction without writing to file.")
    var dryRun: Bool = false

    @Option(name: .long, help: "Maximum number of files to process in parallel.")
    var concurrency: Int = 4

    @Flag(name: .long, help: "Suppress progress output.")
    var quiet: Bool = false

    @Option(name: .long, help: "Maximum tokens for LLM response.")
    var maxTokens: Int = 8192

    func run() async throws {
        let fileURL = URL(fileURLWithPath: project)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ValidationError("Project file not found: \(project)")
        }
        let projectDir = fileURL.deletingLastPathComponent()
        let parser = ProjectMarkdownParser()
        let (frontMatter, body) = try parser.parse(fileURL: fileURL)

        if !quiet {
            print("Project: \(frontMatter.title)")
            print("Model: \(model)")
            print("Pattern: \(frontMatter.resolvedFilePatterns.joined(separator: ", "))")
            print("Loading model...")
            print("")
            fflush(stdout)
        }

        let extractor = CharacterExtractor(
            projectDirectory: projectDir,
            frontMatter: frontMatter,
            maxTokens: maxTokens
        )

        let modelId = model
        let isQuiet = quiet
        let concurrencyLimit = concurrency
        let tokens = maxTokens
        let updated = try await extractor.extractAll(
            queryFn: { userPrompt, systemPrompt in
                try await Bruja.query(
                    userPrompt,
                    model: modelId,
                    temperature: 0.3,
                    maxTokens: tokens,
                    system: systemPrompt
                )
            },
            progressFn: { filename, current, total in
                if !isQuiet {
                    print("[\(current)/\(total)] Extracted: \(filename)")
                    fflush(stdout)
                }
            },
            maxConcurrency: concurrencyLimit
        )

        if let cast = updated.cast {
            if !quiet {
                print("Extracted \(cast.count) character(s):")
                for member in cast {
                    let voice = member.primaryVoice ?? "(none)"
                    print("  \(member.character): \(voice)")
                }
            }
        }

        if !dryRun {
            let output = parser.generate(frontMatter: updated, body: body)
            try output.write(to: fileURL, atomically: true, encoding: .utf8)
            if !quiet { print("\nWritten to \(project)") }
        } else {
            if !quiet { print("\n(dry run — no changes written)") }
        }
    }
}
