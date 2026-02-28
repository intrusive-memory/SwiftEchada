<p align="center">
    <img src="icon.jpg" alt="SwiftEchada" width="200" />
</p>

# SwiftEchada

AI-powered cast management for screenplay projects. Generates on-device custom voices from text prompts (via [SwiftVoxAlta](https://github.com/intrusive-memory/SwiftVoxAlta)) and manages cast data in PROJECT.md files (via [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto)).

## Requirements

- macOS 26+ (Apple Silicon)
- Swift 6.2+
- **MLX framework** (via Homebrew)

### Install MLX

SwiftEchada requires the MLX framework for on-device voice generation:

```bash
brew install mlx
```

This installs the compiled Metal shader library (`mlx.metallib`) required for GPU acceleration.

## Installation

### Homebrew

```bash
brew tap intrusive-memory/tap
brew install echada
```

### Swift Package (Library Only)

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftEchada.git", from: "0.10.0"),
]
```

The library target depends only on [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto) — all ML and voice dependencies are CLI-only.

## CLI Usage

The `echada` CLI has three commands:

### Cast Voices (default)

Generate on-device custom voices for cast members using Qwen3-TTS. Reads voice description prompts from PROJECT.md and generates `.vox` voice files.

```bash
echada cast --project PROJECT.md [--tts-model <0.6b|1.7b>] [--character <name>] [--force-regenerate] [--dry-run] [--verbose]
```

Uses a two-phase pipeline:
1. **Phase A** — VoiceDesign 1.7B model generates candidate WAVs from voice prompts
2. **Phase B** — Base model creates voice locks (speaker embeddings) and exports `.vox` bundles

Use `--tts-model` to select the TTS model variant (default: `1.7b`). Use `--character` to regenerate a single character's voice without affecting others.

### Generate a Voice

Generate a single `.vox` voice file from a text prompt (no PROJECT.md required).

```bash
echada voice "A warm female voice with a slight southern accent" --output my-voice.vox --name "Narrator"
```

Appends to existing `.vox` files for multi-model support.

## Library Usage

### Character Merging

```swift
import SwiftEchada
import SwiftProyecto

let merger = CharacterMerger()
let unified = merger.merge(
    extracted: [extractedFromFile1, extractedFromFile2],
    existingCast: currentCast
)
// unified contains deduplicated, sorted cast list
```

### Character Profiles

```swift
import SwiftEchada

let profile = CharacterProfile(
    name: "NARRATOR",
    gender: .male,
    ageRange: "40s",
    description: "A deep, authoritative voice with warmth",
    voiceTraits: ["deep", "authoritative", "warm"],
    summary: "Deep authoritative male narrator voice"
)
```

### Sample Sentences

```swift
import SwiftEchada

// Get a random quote for TTS auditions
let quote = SampleSentenceGenerator.randomQuote()
```

## Architecture

```
Library:  SwiftEchada → SwiftProyecto
CLI:      echada → SwiftEchada + SwiftVoxAlta + MLX
```

The library contains pure data types and utilities with no ML dependencies. Voice generation is entirely prompt-based — voice descriptions are text strings in PROJECT.md, and the CLI generates `.vox` files from these prompts with no LLM involvement.

## Building

```bash
# Build CLI
make build

# Run tests
make test

# Release build + copy to ./bin
make release

# Clean
make clean
```

All `make` targets use `xcodebuild` (required for Metal shader compilation).

## Related Projects

- [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto) — Project metadata and file discovery
- [SwiftVoxAlta](https://github.com/intrusive-memory/SwiftVoxAlta) — On-device neural TTS voice generation
