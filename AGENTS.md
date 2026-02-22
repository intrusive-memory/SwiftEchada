# AGENTS.md

This file provides comprehensive documentation for AI agents working with the SwiftEchada codebase.

**Current Version**: 0.9.4 (February 2026)

---

## Project Overview

SwiftEchada is an AI-powered cast management library for screenplay projects, focused on three core functions:

1. **Extract characters + generate voice prompts** (library)
2. **Generate .vox voice files from prompts** (CLI, on-device via VoxAlta)
3. **Write casting to PROJECT.md** (library, via SwiftProyecto)

## Project Structure

- `Sources/SwiftEchada/` -- Library target (depends only on SwiftProyecto, uses closure-based DI for LLM queries)
- `Sources/echada/` -- CLI executable target (depends on SwiftBruja for LLM, SwiftVoxAlta + MLX for voice generation)
- `Tests/SwiftEchadaTests/` -- Unit tests (CharacterProfile, CharacterAnalyzer, SampleSentenceGenerator, ParentheticalMapper, CharacterInfo, CharacterMerger, VoiceDescriptionEnricher, version)
- `Tests/SwiftEchadaIntegrationTests/` -- Integration tests (CharacterExtractor end-to-end, fixture-based)
- `Fixtures/` -- Test fixture files (fountain screenplays, PROJECT.md)

## Key Components

### Library (`Sources/SwiftEchada/`)

| File | Purpose |
|------|---------|
| `CharacterExtractor.swift` | Discovers screenplay files in `episodesDir`, extracts characters via LLM, scene-based chunking for large files |
| `CharacterMerger.swift` | Deduplicates characters by name (case-insensitive), preserves voice/actor data |
| `CharacterInfo.swift` | Codable struct for extracted character data (`name`, `description`, `voiceDescription`) |
| `CharacterProfile.swift` | Detailed voice profile for a character (`name`, `gender`, `ageRange`, `voiceTraits`, `summary`) |
| `CharacterAnalyzer.swift` | Builds `CharacterProfile` from `CastMember` via LLM with heuristic fallback |
| `SampleSentenceGenerator.swift` | Returns random Dorothy Parker / Fran Lebowitz quotes for TTS auditions |
| `ParentheticalMapper.swift` | Maps screenplay parentheticals to TTS instruct strings (static lookup + LLM fallback) |
| `VoiceDescriptionEnricher.swift` | Enriches cast members missing voice descriptions via LLM |
| `SwiftEchada.swift` | Module version constant |

### CLI (`Sources/echada/`)

| File | Purpose |
|------|---------|
| `EchadaCLI.swift` | Entry point, subcommand registration |
| `ExtractCommand.swift` | Extract characters from screenplay files |
| `CastCommand.swift` | Generate on-device voices (Pass 1: enrich, Pass 2: generate .vox) |
| `DownloadCommand.swift` | Download LLM models |
| `VoiceDesigner.swift` | Composes voice descriptions and generates candidate WAV via VoiceDesign model |
| `CastVoiceGenerator.swift` | Orchestrates .vox generation pipeline per cast member |
| `ReferenceAudioGenerator.swift` | macOS fallback using `say` command for reference audio |

## CLI Commands

| Command | File | Key flags |
|---------|------|-----------|
| `extract` (default) | `ExtractCommand.swift` | `--project`, `--model`, `--concurrency`, `--dry-run`, `--quiet`, `--max-tokens` |
| `cast` | `CastCommand.swift` | `--project`, `--model`, `--force-regenerate`, `--dry-run`, `--verbose`, `--max-tokens`, `--tts-model`, `--character` |
| `download` | `DownloadCommand.swift` | `--model`, `--force`, `--quiet` |

`extract` is the default subcommand.

## Dependencies

| Package | Branch | Purpose |
|---------|--------|---------|
| SwiftProyecto | development | `ProjectFrontMatter`, `CastMember`, `ProjectMarkdownParser`, `Gender` |
| SwiftBruja | main | Local LLM inference (CLI only) |
| SwiftVoxAlta | development | On-device voice generation, VoiceLockManager, VoxAltaModelManager (CLI only) |
| mlx-swift | 0.21.0+ | MLX framework for ML inference (CLI only) |
| mlx-swift-lm | main | MLXLMCommon for GenerateParameters (CLI only) |
| mlx-audio-swift | development | Qwen3TTSModel for voice synthesis (CLI only) |
| vox-format | 0.2.0+ | VoxFile, VoxManifest for .vox archives (CLI only) |
| swift-argument-parser | 1.3.0+ | CLI argument parsing |

**Library target depends only on SwiftProyecto** -- all ML/voice deps are CLI-only.

## Build and Test

**CRITICAL**: This library must ONLY be compiled using `xcodebuild`. Do NOT use `swift build` or `swift test`. The `swift` CLI does not correctly resolve all dependencies for this project.

```bash
# Library tests
GIT_LFS_SKIP_SMUDGE=1 xcodebuild -scheme SwiftEchada-Package -destination 'platform=macOS,arch=arm64' test

# CLI build
GIT_LFS_SKIP_SMUDGE=1 xcodebuild -scheme echada -destination 'platform=macOS,arch=arm64' build
```

Use `GIT_LFS_SKIP_SMUDGE=1` with build commands to avoid pulling large model files.

## Design Patterns

- **Closure-based DI**: Library accepts `queryFn` closures so tests use mocks, CLI passes `Bruja.query`
- **Targeted imports**: CLI files use `import struct SwiftEchada.CharacterProfile` (not `import SwiftEchada`) to avoid the module/type name collision (`SwiftEchada` is both a module and an enum)
- **Scene-based chunking**: Files >2000 estimated tokens are split at scene headings
- **Character name normalization**: Parentheticals stripped during extraction
- **Strict concurrency**: Swift 6 language mode, `Sendable` throughout

## Cast Pipeline

### Extract (`echada extract`)
1. Validates PROJECT.md, parses front matter
2. Discovers screenplay files via `filePattern` in `episodesDir`
3. LLM extracts characters as JSON; large files chunked by scene headings
4. `CharacterMerger` deduplicates across files, preserves existing voice/actor data
5. Writes updated cast to PROJECT.md

### Cast (`echada cast`)
1. **Pass 1**: `VoiceDescriptionEnricher` generates voice descriptions for characters missing them
2. **Pass 2**: For each character:
   - `CharacterAnalyzer` builds a `CharacterProfile` from the voice description
   - `SampleSentenceGenerator` selects a random quote for audition
   - `VoiceDesigner` generates candidate WAV via Qwen3-TTS VoiceDesign model
   - `VoiceLockManager.createLock()` extracts speaker embedding from candidate
   - `VoxFile` writes `.vox` bundle with clone prompt and sample audio
3. Updates PROJECT.md with `voxalta` voice paths

## Homebrew

Distributed via `brew tap intrusive-memory/tap && brew install echada`. Formula at `intrusive-memory/homebrew-tap/Formula/echada.rb`. Requires the `mlx-swift_Cmlx.bundle` to be colocated with the binary (installed to libexec).
