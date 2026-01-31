# SwiftEchada

AI-powered cast management for screenplay projects.

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
| `CastMatcher.swift` | Matches cast to TTS voices via LLM with retry logic |
| `SwiftEchada.swift` | Module version constant (`0.3.0`) |

## CLI Commands

| Command | File | Key flags |
|---------|------|-----------|
| `extract` | `ExtractCommand.swift` | `--project`, `--model`, `--dry-run`, `--quiet` |
| `match` | `EchadaCLI.swift` | `--project`, `--provider`, `--model`, `--language`, `--force`, `--dry-run` |
| `download` | `DownloadCommand.swift` | `--model`, `--force`, `--quiet` |

`match` is the default subcommand.

## Dependencies

| Package | Branch | Purpose |
|---------|--------|---------|
| SwiftProyecto | development | `ProjectFrontMatter`, `CastMember`, `ProjectMarkdownParser` |
| SwiftHablare | development | `Voice` type and `GenerationService` for CastMatcher |
| SwiftBruja | main | Local LLM inference (CLI only) |
| swift-argument-parser | 1.3.0+ | CLI argument parsing |

## Build and Test

```bash
swift build
swift test
```

For end-to-end testing with real LLM (requires Metal/Apple Silicon):

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
6. `CastMatcher.match()` sends each unmatched character + voice catalog to LLM, assigns voice URIs
7. Updated front matter is written back to PROJECT.md

## Homebrew

Distributed via `brew tap intrusive-memory/tap && brew install echada`. Formula at `intrusive-memory/homebrew-tap/Formula/echada.rb`. Requires the `mlx-swift_Cmlx.bundle` to be colocated with the binary (installed to libexec).
