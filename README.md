# SwiftEchada

AI-powered cast management for screenplay projects. Extracts characters from screenplay files using local LLM inference (via [SwiftBruja](https://github.com/intrusive-memory/SwiftBruja)) and matches them to TTS voices.

## Requirements

- macOS 26+ (Apple Silicon)
- Swift 6.2+

## Installation

### Homebrew

```bash
brew tap intrusive-memory/tap
brew install echada
```

### Swift Package

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftEchada.git", branch: "main"),
]
```

## CLI Usage

The `echada` CLI has three commands:

### Extract Characters

Discover screenplay files in a project directory, extract speaking characters via LLM, and write the merged cast list back to PROJECT.md.

```bash
echada extract --project PROJECT.md [--model <model-id>] [--dry-run] [--quiet]
```

Large screenplays are automatically chunked by scene headings to fit within model context limits.

### Match Cast to TTS Voices

Match cast members to TTS voices from a provider catalog using LLM selection.

```bash
echada match --project PROJECT.md --provider apple [--model <model-id>] [--language en] [--force] [--dry-run]
```

### Download Model

Download an LLM model from HuggingFace for local inference. Shows a progress bar.

```bash
echada download [--model <model-id>] [--force] [--quiet]
```

The default model is `mlx-community/Phi-3-mini-4k-instruct-4bit`. Models are cached at `~/Library/Caches/intrusive-memory/Models/LLM/`.

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

### Voice Matching

```swift
let matcher = CastMatcher(
    providerId: "apple",
    languageCode: "en",
    model: "my-model",
    force: false
)

let result = try await matcher.match(frontMatter: frontMatter) { prompt, system, model in
    try await myLLM.query(prompt, model: model, system: system)
}
// result.updatedFrontMatter contains cast with voice assignments
```

## How It Works

1. Reads PROJECT.md YAML front matter to find screenplay file patterns (e.g., `*.fountain`)
2. Discovers matching files in the project directory
3. For large files, splits by scene headings (`INT.`, `EXT.`, `INT./EXT.`, etc.) into chunks
4. Sends each file/chunk to a local LLM with a character extraction prompt
5. Parses JSON responses into character lists
6. Merges across files and chunks (deduplicates by name, preserves existing voice/actor assignments)
7. Writes the updated cast back to PROJECT.md

## Architecture

```
Layer 0: SwiftFijos, SwiftBruja
Layer 1: SwiftCompartido(->Fijos), SwiftProyecto(->Bruja)
Layer 2: SwiftHablare(->Fijos,Compartido,Proyecto), SwiftSecuencia(->Compartido,Fijos)
Layer 3: SwiftEchada(->Proyecto,Hablare,Bruja)
```

The library uses closure-based dependency injection (`queryFn`) so core logic is testable without MLX hardware.

## Related Projects

- [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto) -- Project metadata and file discovery
- [SwiftHablare](https://github.com/intrusive-memory/SwiftHablare) -- TTS voice providers
- [SwiftBruja](https://github.com/intrusive-memory/SwiftBruja) -- Local LLM inference on Apple Silicon
