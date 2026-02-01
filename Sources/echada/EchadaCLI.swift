import ArgumentParser
import Foundation
import SwiftBruja
import SwiftEchada
import SwiftProyecto

@main
struct EchadaCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "echada",
        abstract: "AI-powered cast-to-voice matching for screenplay projects.",
        version: SwiftEchada.version,
        subcommands: [MatchCommand.self, ExtractCommand.self, DownloadCommand.self],
        defaultSubcommand: MatchCommand.self
    )
}

struct MatchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "match",
        abstract: "Match cast members to TTS voices using a local LLM."
    )

    @Option(name: .long, help: "Path to PROJECT.md file.")
    var project: String = "PROJECT.md"

    @Option(name: .long, help: "TTS provider ID (e.g., apple, elevenlabs, qwen).")
    var provider: String

    @Option(name: .long, help: "LLM model identifier for Bruja.")
    var model: String = Bruja.defaultModel

    @Option(name: .long, help: "Language code (e.g., en, es, fr).")
    var language: String? = nil

    @Flag(name: .long, help: "Re-match all cast members, even those with existing voices.")
    var force: Bool = false

    @Option(name: .long, help: "ElevenLabs API key (or set ELEVENLABS_API_KEY env var).")
    var elevenlabsApiKey: String? = nil

    @Flag(name: .long, help: "Preview matches without writing to file.")
    var dryRun: Bool = false

    func run() async throws {
        let fileURL = URL(fileURLWithPath: project)
        let parser = ProjectMarkdownParser()
        let (frontMatter, body) = try parser.parse(fileURL: fileURL)

        print("Project: \(frontMatter.title)")
        print("Provider: \(provider)")
        print("Model: \(model)")
        if let lang = language { print("Language: \(lang)") }
        print("Force: \(force)")
        print("")

        let apiKey = elevenlabsApiKey ?? ProcessInfo.processInfo.environment["ELEVENLABS_API_KEY"]

        let matcher = CastMatcher(
            providerId: provider,
            languageCode: language,
            model: model,
            force: force,
            elevenLabsAPIKey: apiKey
        )

        let result = try await matcher.match(frontMatter: frontMatter) { prompt, system, mdl in
            try await Bruja.query(prompt, model: mdl, temperature: 0.3, maxTokens: 64, system: system)
        }

        print("Matched: \(result.matchedCount)")
        print("Skipped: \(result.skippedCount)")

        if let cast = result.updatedFrontMatter.cast {
            print("")
            for member in cast {
                let voice = member.primaryVoice ?? "(none)"
                print("  \(member.character): \(voice)")
            }
        }

        if !dryRun {
            let output = parser.generate(frontMatter: result.updatedFrontMatter, body: body)
            try output.write(to: fileURL, atomically: true, encoding: .utf8)
            print("\nWritten to \(project)")
        } else {
            print("\n(dry run — no changes written)")
        }
    }
}
