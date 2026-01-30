# SwiftEchada

AI-powered cast management for screenplay projects.

## Project Structure

- `Sources/SwiftEchada/` -- Library target (no Bruja dependency, uses closure injection)
- `Sources/echada/` -- CLI executable target (depends on Bruja for LLM inference)
- `Tests/SwiftEchadaTests/` -- 31 tests across 5 suites
- `Fixtures/` -- Test fixture files (fountain screenplays, PROJECT.md)

## Key Components

| File | Purpose |
|------|---------|
| `CharacterExtractor.swift` | Discovers screenplay files, extracts characters via LLM, scene-based chunking for large files |
| `CharacterMerger.swift` | Deduplicates characters by name (case-insensitive), preserves voice/actor data |
| `CharacterInfo.swift` | Codable struct for extracted character data |
| `CastMatcher.swift` | Matches cast to TTS voices via LLM with retry logic |
| `SwiftEchada.swift` | Module version constant (`0.1.0`) |

## CLI Commands

| Command | File | Key flags |
|---------|------|-----------|
| `extract` | `ExtractCommand.swift` | `--project`, `--model`, `--dry-run`, `--quiet` |
| `match` | `EchadaCLI.swift` | `--project`, `--provider`, `--model`, `--language`, `--force`, `--dry-run` |
| `download` | `DownloadCommand.swift` | `--model`, `--force`, `--quiet` |

## Dependencies

| Package | Branch | Purpose |
|---------|--------|---------|
| SwiftProyecto | development | `ProjectFrontMatter`, `CastMember`, `ProjectMarkdownParser` |
| SwiftHablare | development | `Voice` type for CastMatcher |
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
- **Strict concurrency**: Swift 6 language mode, `Sendable` throughout, actor-based counters in tests

## Homebrew

Distributed via `brew tap intrusive-memory/tap && brew install echada`. Formula at `intrusive-memory/homebrew-tap/Formula/echada.rb`. Requires the `mlx-swift_Cmlx.bundle` to be colocated with the binary (installed to libexec).
