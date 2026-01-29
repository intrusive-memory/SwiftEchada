# SwiftEchada

AI-powered cast management for screenplay projects. Extracts characters from screenplay files using local LLM inference and matches them to TTS voices.

## Requirements

- macOS 26+ / iOS 26+
- Swift 6.2+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftEchada.git", branch: "main"),
]
```

## Library Usage

### Character Extraction

```swift
import SwiftEchada
import SwiftProyecto

let parser = ProjectMarkdownParser()
let (frontMatter, body) = try parser.parse(fileURL: projectMdURL)
let projectDir = projectMdURL.deletingLastPathComponent()

let extractor = CharacterExtractor(
    projectDirectory: projectDir,
    frontMatter: frontMatter
)

let updated = try await extractor.extractAll { userPrompt, systemPrompt in
    // Provide your own LLM query implementation
    try await myLLM.query(userPrompt, system: systemPrompt)
}

// updated.cast now contains the merged character list
let output = parser.generate(frontMatter: updated, body: body)
try output.write(to: projectMdURL, atomically: true, encoding: .utf8)
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

## CLI

The `echada` executable provides three commands:

```bash
# Extract characters from screenplay files
echada extract --project PROJECT.md --model <model-id> [--dry-run] [--quiet]

# Match cast members to TTS voices
echada match --project PROJECT.md --provider apple --model <model-id> [--language en] [--force] [--dry-run]

# Download an LLM model
echada download --model <model-id> [--force] [--quiet]
```

## How It Works

1. Reads PROJECT.md to find screenplay file patterns (e.g., `*.fountain`)
2. Discovers matching files in the project directory
3. Sends each file to a local LLM with a character extraction prompt
4. Parses structured JSON responses into character lists
5. Merges across files (deduplicates, preserves existing voice assignments)
6. Writes the updated cast back to PROJECT.md

## Related Projects

- [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto) -- Project metadata and file discovery
- [SwiftHablare](https://github.com/intrusive-memory/SwiftHablare) -- TTS voice providers
- [SwiftBruja](https://github.com/intrusive-memory/SwiftBruja) -- Local LLM inference
