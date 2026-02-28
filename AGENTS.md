# AGENTS.md

This file provides comprehensive documentation for AI agents working with the SwiftEchada codebase.

**Current Version**: 0.10.0 (February 2026)

**See also**: [API.md](API.md) for complete public API reference with type signatures.

---

## Project Overview

SwiftEchada is an AI-powered cast management library for screenplay projects, focused on two core functions:

1. **Generate .vox voice files from text prompts** (CLI, on-device via VoxAlta)
2. **Write casting to PROJECT.md** (CLI, via SwiftProyecto)

The library itself is a lightweight collection of data types and utilities with no ML dependencies.

## Project Structure

- `Sources/SwiftEchada/` -- Library target (depends only on SwiftProyecto)
- `Sources/echada/` -- CLI executable target (depends on SwiftVoxAlta + MLX for voice generation)
- `Tests/SwiftEchadaTests/` -- Unit tests (CharacterProfile, CharacterInfo, CharacterMerger, SampleSentenceGenerator, VoicePromptRoundTrip, version)
- `Fixtures/` -- Test fixture files (fountain screenplays, PROJECT.md)

## Key Components

### Library (`Sources/SwiftEchada/`)

| File | Purpose |
|------|---------|
| `SwiftEchada.swift` | Module version constant (`SwiftEchada.version`) |
| `CharacterProfile.swift` | Detailed voice profile struct (`name`, `gender`, `ageRange`, `voiceTraits`, `summary`, `voxFormatGender`); also contains `CharacterEvidence` |
| `CharacterInfo.swift` | Codable struct for extracted character data (`name`, `description`, `voiceDescription`) |
| `CharacterMerger.swift` | Deduplicates characters by name (case-insensitive), preserves voice/actor data |
| `SampleSentenceGenerator.swift` | Returns random Dorothy Parker / Fran Lebowitz quotes for TTS auditions |

### CLI (`Sources/echada/`)

| File | Purpose |
|------|---------|
| `EchadaCLI.swift` | Entry point, subcommand registration |
| `CastCommand.swift` | Generate on-device voices for cast members from voice prompts in PROJECT.md (default subcommand) |
| `VoiceCommand.swift` | Generate a single .vox voice file from a text prompt |
| `TestVoiceCommand.swift` | Hidden subcommand for integration testing |
| `VoiceDesigner.swift` | Composes voice descriptions and generates candidate WAV via VoiceDesign model |
| `CastVoiceGenerator.swift` | Orchestrates .vox generation pipeline per cast member (two-phase) |
| `ReferenceAudioGenerator.swift` | macOS fallback using `say` command for reference audio |

## CLI Commands

| Command | File | Key flags |
|---------|------|-----------|
| `cast` (default) | `CastCommand.swift` | `--project`, `--force-regenerate`, `--dry-run`, `--verbose`, `--tts-model`, `--character` |
| `voice` | `VoiceCommand.swift` | `<prompt>` (argument), `--output`, `--name`, `--tts-model`, `--verbose` |
| `test-voice` (hidden) | `TestVoiceCommand.swift` | `--output`, `--tts-model` |

`cast` is the default subcommand.

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| SwiftProyecto | branch: development | `ProjectFrontMatter`, `CastMember`, `ProjectMarkdownParser`, `Gender` |
| SwiftVoxAlta | branch: development | On-device voice generation, VoiceLockManager, VoxAltaModelManager, VoxExporter (CLI only) |
| mlx-swift | 0.21.0+ | MLX framework for ML inference (CLI only) |
| mlx-swift-lm | branch: main | MLXLMCommon for GenerateParameters (CLI only) |
| mlx-audio-swift | branch: development | Qwen3TTSModel for voice synthesis (CLI only) |
| vox-format | 0.3.0+ | VoxFile, VoxManifest for .vox archives (CLI only) |
| swift-argument-parser | 1.3.0+ | CLI argument parsing (CLI only) |

**Library target depends only on SwiftProyecto** -- all ML/voice deps are CLI-only.

## Build and Test

**CRITICAL**: This library must ONLY be compiled using `xcodebuild`. Do NOT use `swift build` or `swift test`. The `swift` CLI does not correctly resolve all dependencies for this project.

A Makefile is provided — **always use it** for consistent builds:

```bash
make build            # Debug build
make release          # Release build + copy to ./bin
make install          # Debug build + copy to ./bin (default)
make test             # Unit tests
make integration-test # Multi-model voice + synthesis test
make clean            # Clean build artifacts
make resolve          # Resolve SPM dependencies
```

Or raw xcodebuild (the Makefile wraps these):

```bash
# Library tests
GIT_LFS_SKIP_SMUDGE=1 xcodebuild -scheme SwiftEchada-Package -destination 'platform=macOS,arch=arm64' test

# CLI build
GIT_LFS_SKIP_SMUDGE=1 xcodebuild -scheme echada -destination 'platform=macOS,arch=arm64' build
```

Use `GIT_LFS_SKIP_SMUDGE=1` with build commands to avoid pulling large model files (the Makefile exports this automatically).

## Design Patterns

- **Prompt-based voice generation**: Voice descriptions are text prompts written in PROJECT.md; the CLI generates .vox files from these prompts with no LLM involvement
- **Two-phase pipeline**: Cast voice generation splits into Phase A (VoiceDesign model generates candidate WAVs) and Phase B (Base model creates voice locks and exports .vox bundles) to avoid model thrashing
- **Targeted imports**: CLI files use `import struct SwiftEchada.CharacterProfile` (not `import SwiftEchada`) to avoid the module/type name collision (`SwiftEchada` is both a module and an enum)
- **Multi-model .vox support**: A single .vox file can contain embeddings for multiple model sizes (0.6b and 1.7b); appending to existing .vox files is supported
- **Strict concurrency**: Swift 6 language mode, `Sendable` throughout

## Cast Pipeline (`echada cast`)

1. Reads PROJECT.md, parses front matter and cast list
2. Resolves TTS model: CLI flag > `tts.model` in PROJECT.md > default (`1.7b`)
3. For each cast member with a non-empty `voiceDescription`:
   - **Phase A**: VoiceDesign 1.7B model generates candidate WAV from the voice prompt
   - **Phase B**: Base model creates a voice lock (speaker embedding), exports .vox bundle via `VoxExporter`
4. Updates PROJECT.md with `voxalta` voice paths

## Voice Pipeline (`echada voice`)

1. Takes a text prompt argument describing the desired voice
2. VoiceDesign 1.7B model generates candidate WAV
3. Base model (specified by `--tts-model`) creates voice lock
4. Exports .vox bundle with clone prompt and sample audio
5. Appends to existing .vox files if output path already exists

## Homebrew

Distributed via `brew tap intrusive-memory/tap && brew install echada`. Formula at `intrusive-memory/homebrew-tap/Formula/echada.rb`. Requires the `mlx-swift_Cmlx.bundle` to be colocated with the binary (installed to libexec).
