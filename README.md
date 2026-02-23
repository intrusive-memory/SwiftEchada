<p align="center">
    <img src="icon.jpg" alt="SwiftEchada" width="200" />
</p>

# SwiftEchada

AI-powered cast management for screenplay projects. Extracts characters from screenplay files using local LLM inference (via [SwiftBruja](https://github.com/intrusive-memory/SwiftBruja)) and generates on-device custom voices (via [SwiftVoxAlta](https://github.com/intrusive-memory/SwiftVoxAlta)).

## Requirements

- macOS 26+ (Apple Silicon)
- Swift 6.2+
- **MLX framework** (via Homebrew)

### Install MLX

SwiftEchada requires the MLX framework for on-device LLM inference and voice generation:

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
    .package(url: "https://github.com/intrusive-memory/SwiftEchada.git", branch: "main"),
]
```

The library target depends only on [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto) — all ML and voice dependencies are CLI-only.

## CLI Usage

The `echada` CLI has three commands:

### Extract Characters (default)

Discover screenplay files in a project directory, extract speaking characters via LLM, and write the merged cast list to PROJECT.md.

```bash
echada extract --project PROJECT.md [--model <model-id>] [--dry-run] [--quiet]
```

Large screenplays are automatically chunked by scene headings to fit within model context limits.

### Cast Voices

Generate on-device custom voices for cast members using Qwen3-TTS. Runs in two passes:

1. **Enrich** — generates voice descriptions for characters missing them
2. **Generate** — creates `.vox` voice files with speaker embeddings for each character

```bash
echada cast --project PROJECT.md [--model <model-id>] [--tts-model <0.6b|1.7b>] [--character <name>] [--force-regenerate] [--dry-run] [--verbose]
```

Use `--tts-model` to select the TTS model variant (default: `1.7b`). Use `--character` to regenerate a single character's voice without affecting others.

Voice files are written as `.vox` bundles containing clone prompts and sample audio.

### Download Model

Download an LLM model from HuggingFace for local inference. Shows a progress bar.

```bash
echada download [--model <model-id>] [--force] [--quiet]
```

Models are cached at `~/Library/Caches/intrusive-memory/Models/LLM/`.

The default model is `mlx-community/Qwen2.5-7B-Instruct-4bit` (4.4GB, reliable JSON output).

## Recommended Models

SwiftEchada works best with models that reliably follow JSON formatting instructions.

| Model | Size | Context | Quality |
|-------|------|---------|---------|
| `mlx-community/Qwen2.5-7B-Instruct-4bit` | 4.4GB | 32k | Best |
| `mlx-community/Llama-3.2-3B-Instruct-4bit` | 2.1GB | 128k | Good |
| `mlx-community/Phi-3.5-mini-instruct-4bit` | 2.9GB | 128k | Fair |

## Library Usage

### Character Extraction

```swift
import SwiftEchada
import SwiftProyecto

let parser = ProjectMarkdownParser()
let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)

let extractor = CharacterExtractor(
    projectDirectory: projectMdURL.deletingLastPathComponent(),
    frontMatter: frontMatter
)

let updated = try await extractor.extractAll(
    queryFn: { userPrompt, systemPrompt in
        try await myLLM.query(userPrompt, system: systemPrompt)
    },
    progressFn: { filename, current, total in
        print("[\(current)/\(total)] \(filename)")
    }
)

// updated.cast contains the merged character list
```

### Character Analysis

```swift
import SwiftEchada

// Build a voice profile from a cast member
let profile = try await CharacterAnalyzer.analyze(castMember: member) { prompt, system in
    try await myLLM.query(prompt, system: system)
}

// Generate a sample sentence in the character's voice
let sentence = try await SampleSentenceGenerator.generate(for: profile) { prompt, system in
    try await myLLM.query(prompt, system: system)
}
```

## How It Works

### Cast Pipeline

#### Phase 1: Character Extraction (`echada extract`)

1. Validates PROJECT.md, parses YAML front matter
2. Discovers screenplay files via `filePattern` in `episodesDir`
3. LLM extracts characters as JSON; large files chunked by scene headings
4. `CharacterMerger` deduplicates across files, preserves existing voice/actor data
5. Writes updated cast to PROJECT.md

#### Phase 2: Voice Generation (`echada cast`)

1. **Pass 1**: `VoiceDescriptionEnricher` generates voice descriptions for characters missing them
2. **Pass 2**: For each character:
   - `CharacterAnalyzer` builds a `CharacterProfile` from the voice description
   - `SampleSentenceGenerator` selects a random quote for audition
   - `VoiceDesigner` generates candidate WAV via Qwen3-TTS VoiceDesign model
   - `VoiceLockManager.createLock()` extracts speaker embedding
   - `VoxFile` writes `.vox` bundle with clone prompt and sample audio
3. Updates PROJECT.md with `voxalta` voice paths

## Architecture

```
Library:  SwiftEchada → SwiftProyecto
CLI:      echada → SwiftEchada + SwiftBruja + SwiftVoxAlta + MLX
```

The library uses closure-based dependency injection (`queryFn`) so core logic is testable without MLX hardware.

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
- [SwiftBruja](https://github.com/intrusive-memory/SwiftBruja) — Local LLM inference on Apple Silicon
