import ArgumentParser
import Foundation
import SwiftBruja
import struct SwiftEchada.VoiceDescriptionEnricher
import SwiftProyecto

struct CastCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cast",
        abstract: "Generate custom on-device voices for cast members using VoxAlta."
    )

    @Option(name: .long, help: "Path to PROJECT.md file.")
    var project: String = "PROJECT.md"

    @Flag(name: .long, help: "Regenerate voices even if .vox files already exist.")
    var forceRegenerate: Bool = false

    @Option(name: .long, help: "LLM model identifier for Bruja.")
    var model: String = Bruja.defaultModel

    @Flag(name: .long, help: "Preview without writing any files.")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Show verbose output including LLM queries.")
    var verbose: Bool = false

    @Option(name: .long, help: "Maximum tokens for LLM response.")
    var maxTokens: Int = 2048

    func run() async throws {
        let fileURL = URL(fileURLWithPath: project)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ValidationError("Project file not found: \(project)")
        }
        let projectDir = fileURL.deletingLastPathComponent()
        let parser = ProjectMarkdownParser()
        let (frontMatter, body) = try parser.parse(fileURL: fileURL)

        guard let cast = frontMatter.cast, !cast.isEmpty else {
            throw ValidationError("No cast members found in \(project). Run 'echada extract' first.")
        }

        print("Project: \(frontMatter.title)")
        print("Model: \(model)")
        print("Cast members: \(cast.count)")
        if forceRegenerate { print("Force regenerate: yes") }
        print("")
        fflush(stdout)

        // Capture locals for closure safety
        let modelId = model
        let tokens = maxTokens
        let isVerbose = verbose

        // --- Pass 1: Voice Description Enrichment ---
        print("Pass 1: Enriching voice descriptions...")
        fflush(stdout)

        let enricher = VoiceDescriptionEnricher()
        let enrichResult = await enricher.enrich(
            cast: cast,
            genre: frontMatter.genre,
            queryFn: { userPrompt, systemPrompt in
                try await Bruja.query(
                    userPrompt,
                    model: modelId,
                    temperature: 0.7,
                    maxTokens: tokens,
                    system: systemPrompt
                )
            },
            verbose: isVerbose
        )

        print("  Enriched: \(enrichResult.enrichedCount)")
        print("  Skipped: \(enrichResult.skippedCount)")
        print("")
        fflush(stdout)

        if dryRun {
            print("Pass 1 results (dry run):")
            for member in enrichResult.updatedCast {
                let desc = member.voiceDescription ?? "(none)"
                print("  \(member.character): \(desc)")
            }
            print("\n(dry run — no voice generation or file writes)")
            return
        }

        // --- Pass 2: Voice Generation ---
        print("Pass 2: Generating voices...")
        print("Loading VoxAlta models (this may take a moment)...")
        fflush(stdout)

        let generator = CastVoiceGenerator(
            projectDirectory: projectDir,
            forceRegenerate: forceRegenerate,
            verbose: isVerbose
        )

        let genResult = try await generator.generate(
            cast: enrichResult.updatedCast,
            queryFn: { userPrompt, systemPrompt in
                try await Bruja.query(
                    userPrompt,
                    model: modelId,
                    temperature: 0.3,
                    maxTokens: tokens,
                    system: systemPrompt
                )
            },
            model: modelId
        )

        print("  Generated: \(genResult.generatedCount)")
        print("  Skipped: \(genResult.skippedCount)")
        print("")

        // Print final cast summary
        for member in genResult.updatedCast {
            if member.voices.isEmpty {
                print("  \(member.character): (none)")
            } else {
                let voiceList = member.voices.map { "\($0.key):\($0.value)" }.joined(separator: ", ")
                print("  \(member.character): \(voiceList)")
            }
        }

        // Write updated PROJECT.md
        let updatedFrontMatter = ProjectFrontMatter(
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
            cast: genResult.updatedCast,
            preGenerateHook: frontMatter.preGenerateHook,
            postGenerateHook: frontMatter.postGenerateHook,
            tts: frontMatter.tts
        )

        let output = parser.generate(frontMatter: updatedFrontMatter, body: body)
        try output.write(to: fileURL, atomically: true, encoding: .utf8)
        print("\nWritten to \(project)")
    }
}
