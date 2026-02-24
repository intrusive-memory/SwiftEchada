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

    @Option(name: .long, help: "TTS model variant for voice generation (0.6b, 1.7b). Defaults to tts.model from PROJECT.md, then 1.7b.")
    var ttsModel: String?

    @Option(name: .long, help: "Generate voice for a single character (by name).")
    var character: String?

    func run() async throws {
        let fileURL = URL(fileURLWithPath: project)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ValidationError("Project file not found: \(project)")
        }
        let projectDir = fileURL.deletingLastPathComponent()
        let parser = ProjectMarkdownParser()
        let (frontMatter, body) = try parser.parse(fileURL: fileURL)

        // Resolve TTS model: CLI flag > PROJECT.md tts.model > default slug
        let effectiveTTSModel = ttsModel ?? frontMatter.tts?.model ?? CastVoiceGenerator.defaultModelSlug

        // Validate TTS model variant before any expensive work
        guard CastVoiceGenerator.supportedVariants.contains(effectiveTTSModel.lowercased()) else {
            throw ValidationError(
                "Unsupported TTS model variant '\(effectiveTTSModel)'. " +
                "Supported values: \(CastVoiceGenerator.supportedVariants.sorted().joined(separator: ", "))"
            )
        }

        guard let cast = frontMatter.cast, !cast.isEmpty else {
            throw ValidationError("No cast members found in \(project). Run 'echada extract' first.")
        }

        // Filter cast to a single character if requested
        let targetCast: [CastMember]
        if let characterName = character {
            targetCast = cast.filter { $0.character.localizedCaseInsensitiveCompare(characterName) == .orderedSame }
            guard !targetCast.isEmpty else {
                throw ValidationError("Character '\(characterName)' not found in cast. Available: \(cast.map(\.character).joined(separator: ", "))")
            }
        } else {
            targetCast = cast
        }

        print("Project: \(frontMatter.title)")
        print("Model: \(model)")
        print("TTS model: \(effectiveTTSModel)\(ttsModel != nil ? "" : " (from \(frontMatter.tts?.model != nil ? "PROJECT.md" : "default"))")")
        print("Cast members: \(targetCast.count)\(character != nil ? " (filtered: \(character!))" : "")")
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
            cast: targetCast,
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
            verbose: isVerbose,
            ttsModelVariant: effectiveTTSModel
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

        // Merge filtered results back into the full cast list
        let finalCast: [CastMember]
        if character != nil {
            // Build a lookup of updated members by character name
            let updatedByName = Dictionary(
                genResult.updatedCast.map { ($0.character, $0) },
                uniquingKeysWith: { _, last in last }
            )
            finalCast = cast.map { updatedByName[$0.character] ?? $0 }
        } else {
            finalCast = genResult.updatedCast
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
            cast: finalCast,
            preGenerateHook: frontMatter.preGenerateHook,
            postGenerateHook: frontMatter.postGenerateHook,
            tts: frontMatter.tts
        )

        let output = parser.generate(frontMatter: updatedFrontMatter, body: body)
        try output.write(to: fileURL, atomically: true, encoding: .utf8)
        print("\nWritten to \(project)")
    }
}
