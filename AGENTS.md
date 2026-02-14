# AGENTS.md

This file provides comprehensive documentation for AI agents working with the SwiftEchada codebase.

**Current Version**: 0.9.0 (February 2026)

---

## Project Overview

SwiftEchada is an AI-powered cast management library for screenplay projects.

## Project Structure

- `Sources/SwiftEchada/` -- Library target (depends on SwiftProyecto and SwiftHablare, uses closure-based DI for LLM queries)
- `Sources/echada/` -- CLI executable target (depends on SwiftBruja for LLM inference)
- `Tests/SwiftEchadaTests/` -- Unit tests (CharacterInfo, CharacterMerger, CastMatcher, version)
- `Tests/SwiftEchadaIntegrationTests/` -- Integration tests (CharacterExtractor end-to-end, fixture-based)
- `Fixtures/` -- Test fixture files (fountain screenplays, PROJECT.md)

## Key Components

| File | Purpose |
|------|---------|
| `CharacterExtractor.swift` | Discovers screenplay files in `episodesDir`, extracts characters via LLM, scene-based chunking for large files, normalizes parentheticals from names |
| `CharacterMerger.swift` | Deduplicates characters by name (case-insensitive), preserves voice/actor data, alphabetical sort |
| `CharacterInfo.swift` | Codable struct for extracted character data (`name`, `description`) |
| `CastMatcher.swift` | Matches cast to TTS voices via LLM with retry logic; provider-aware accumulation |
| `CastMember+Provider.swift` | Extension for provider-aware voice management using dictionary keys |
| `ElevenLabsTypes.swift` | Type aliases for SwiftOnce types (`ElevenLabsClient`, `ElevenLabsHTTPClient`, `ElevenLabsVoice`) |
| `ElevenLabsDefaultsExport.swift` | Re-exports `ElevenLabsDefaults` enum from SwiftOnce via `@_exported import` |
| `SwiftEchada.swift` | Module version constant (`0.9.0`) |

## CLI Commands

| Command | File | Key flags |
|---------|------|-----------|
| `extract` | `ExtractCommand.swift` | `--project`, `--model`, `--concurrency`, `--dry-run`, `--quiet`, `--max-tokens` |
| `match` | `EchadaCLI.swift` | `--project`, `--provider`, `--model`, `--language`, `--force`, `--dry-run` |
| `download` | `DownloadCommand.swift` | `--model`, `--force`, `--quiet` |

`match` is the default subcommand.

## Dependencies

| Package | Branch | Purpose |
|---------|--------|---------|
| SwiftProyecto | development | `ProjectFrontMatter`, `CastMember`, `ProjectMarkdownParser` |
| SwiftHablare | development | `Voice` type and `GenerationService` for CastMatcher |
| SwiftOnce | development | `ElevenLabsDefaults`, shared constants |
| SwiftBruja | main | Local LLM inference (CLI only) |
| swift-argument-parser | 1.3.0+ | CLI argument parsing |

## Build and Test

**CRITICAL**: This library must ONLY be compiled using `xcodebuild`. Do NOT use `swift build` or `swift test`. The `swift` CLI does not correctly resolve all dependencies for this project.

```bash
xcodebuild -scheme SwiftEchada -destination 'platform=macOS,arch=arm64' build
xcodebuild -scheme SwiftEchada -destination 'platform=macOS,arch=arm64' test
```

For the CLI executable:

```bash
xcodebuild -scheme echada -destination 'platform=macOS,arch=arm64' build
# Binary at DerivedData/SwiftEchada-*/Build/Products/Debug/echada
```

Use `GIT_LFS_SKIP_SMUDGE=1` with build commands to avoid pulling large model files from SwiftHablare.

## Design Patterns

- **Closure-based DI**: Library accepts `queryFn` closures so tests use mocks, CLI passes `Bruja.query`
- **Scene-based chunking**: Files >2000 estimated tokens are split at scene headings (`INT.`, `EXT.`, `INT./EXT.`, `INT/EXT.`, `I/E.`, `EST.`)
- **Character name normalization**: Parentheticals like `(V.O.)`, `(O.S.)`, `(CONT'D)` are stripped during extraction
- **EpisodesDir-based discovery**: File discovery searches `projectDirectory/resolvedEpisodesDir` (default `episodes`), not the project root
- **Early validation**: Extract command validates PROJECT.md exists before parsing
- **Strict concurrency**: Swift 6 language mode, `Sendable` throughout, actor-based counters in tests

## Cast Resolution Pipeline

1. `ExtractCommand` validates PROJECT.md, parses front matter, creates `CharacterExtractor`
2. `CharacterExtractor.discoverFiles()` enumerates `<projectDir>/<episodesDir>/` filtered by `filePattern`
3. Each file is read; large files are chunked by scene headings
4. LLM extracts characters as JSON; response is parsed and names are normalized (parentheticals stripped)
5. `CharacterMerger.merge()` deduplicates across files/chunks (case-insensitive), preserves existing voice/actor data
6. `CastMatcher.match()` sends each unmatched character + voice catalog to LLM, assigns voice URIs (provider-aware: only matches characters missing a voice for the current provider, preserves voices from other providers)
7. Updated front matter is written back to PROJECT.md

## Provider-Aware Voice Accumulation

Voice matching is scoped by provider. Running `match --provider apple` followed by `match --provider elevenlabs` accumulates voices rather than overwriting.

**Voice Dictionary Format** (as of v0.9.0):

Voices are stored as a `[String: String]` dictionary mapping provider IDs to voice IDs:

```swift
voices: [
  "apple": "com.apple.voice.premium.en-US.Aaron",
  "elevenlabs": "vid-abc123"
]
```

**Key behaviors:**

- **Filtering**: Characters are only matched if they lack a voice for the *current* provider. A character with an `apple` voice is still eligible for `elevenlabs` matching.
- **Assignment**: `updateCast()` calls `CastMember.voicesReplacingProvider()` which sets/updates only the current provider's voice ID, preserving all others.
- **Force mode**: `--force` re-matches all characters but only replaces the current provider's voice. Other providers' voices are preserved.

**Implementation** (`CastMember+Provider.swift`):

| Method | Purpose |
|--------|---------|
| `hasVoice(for:)` | Returns `true` if a voice exists for the given provider (case-insensitive key match) |
| `voicesReplacingProvider(_:with:)` | Returns updated dictionary with the provider's voice set to the given voice ID, preserving other providers |

## Default Voice Handling

ElevenLabs constants (`defaultVoiceId`, `providerScheme`, URI helpers) come from `ElevenLabsDefaults` in **SwiftOnce** (single source of truth).

The `VoiceProvider` protocol in **SwiftHablare** exposes an optional `defaultVoiceId` property (nil by default). Only `ElevenLabsVoiceProvider` overrides it, returning `ElevenLabsDefaults.defaultVoiceId`.

SwiftEchada re-exports the `ElevenLabsDefaults` enum from SwiftOnce via `@_exported import enum SwiftOnce.ElevenLabsDefaults` in `ElevenLabsDefaultsExport.swift`. This makes the type available to all files in the module (and consumers) without duplicating constants. The targeted `import enum` syntax is required because the SwiftOnce module and `SwiftOnce` actor share the same name, making `SwiftOnce.ElevenLabsDefaults` ambiguous with a bare `import SwiftOnce`. Files in SwiftEchada should NOT `import SwiftOnce` directly (it causes `Voice` type ambiguity with SwiftHablare).

## Homebrew

Distributed via `brew tap intrusive-memory/tap && brew install echada`. Formula at `intrusive-memory/homebrew-tap/Formula/echada.rb`. Requires the `mlx-swift_Cmlx.bundle` to be colocated with the binary (installed to libexec).
