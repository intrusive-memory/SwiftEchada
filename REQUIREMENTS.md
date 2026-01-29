# SwiftEchada - Character Extraction via Local LLM

## Overview

A Swift library that analyzes screenplay files referenced in a PROJECT.md, extracts character lists using MLX-based local LLM inference, merges them into a unified cast list, and writes the result back to the PROJECT.md YAML front matter.

**Core Responsibility**: Character extraction from screenplays (not voice assignment or audio generation).

## Workflow

1. **Read** PROJECT.md via `ProjectMarkdownParser` (SwiftProyecto) → get project directory and episode file patterns
2. **Discover** screenplay files matching the project's `filePatterns` (e.g., `*.fountain`)
3. **Extract** characters from each screenplay file:
   - Read file content
   - Query MLX model with screenplay text → get structured JSON character list
   - Parse JSON response into `CharacterInfo` structs
4. **Merge** character lists from all files into unified cast list (deduplicate by character name)
5. **Write** unified cast list as `CastMember` array back to PROJECT.md YAML front matter (preserves existing voice assignments if present)

## Architecture

### Library Target: `SwiftEchada`

Core logic, reusable from Produciesta and other Swift packages.

#### Key Components

**CharacterExtractor** - Orchestrates character extraction workflow:
- Takes a `ProjectFrontMatter` (from SwiftProyecto) and project directory URL
- Discovers screenplay files using project's `filePatterns` (default: `["*.fountain"]`)
- For each file:
  - Reads screenplay content
  - Queries MLX model with extraction prompt
  - Parses structured JSON response → `[CharacterInfo]`
- Merges all character lists (deduplicates by character name)
- Maps `CharacterInfo` → `CastMember` (preserves existing voice assignments)
- Returns updated `ProjectFrontMatter` with merged cast list

**MLXQueryService** - Wrapper around MLX inference:
- `query(prompt: String, systemPrompt: String?) async throws -> String`
- Uses MLX Python bindings or native Swift MLX library
- Returns structured JSON response (character list)

**CharacterMerger** - Deduplicates and merges character lists:
- Takes `[[CharacterInfo]]` (one array per screenplay file)
- Deduplicates by character name (case-insensitive)
- Preserves existing voice assignments from PROJECT.md if character already in cast
- Returns unified `[CastMember]` array

**PROJECT.md I/O** - Read/write via `ProjectMarkdownParser` (from SwiftProyecto):
- Read existing cast list from YAML front matter
- Write merged cast list back (preserves other front matter fields)

### Key Types

```swift
/// Character extracted from screenplay
public struct CharacterInfo: Codable {
    let name: String           // Character name (e.g., "NARRATOR", "PROTAGONIST")
    let description: String?   // Brief character description from screenplay
}

/// Merged cast member (maps to SwiftProyecto's CastMember)
// CastMember from SwiftProyecto:
// - character: String
// - actor: String?
// - voices: [String]  // VoiceURI array
```

### API Design

```swift
/// Main entry point for character extraction
public struct CharacterExtractor {
    public init(
        projectURL: URL,
        mlxModel: String = "mlx-community/Llama-3.2-3B-Instruct-4bit"
    )

    /// Extract characters from all screenplay files and merge into cast list
    public func extractAndMergeCast() async throws -> [CastMember]

    /// Extract characters from a single screenplay file
    public func extractCharacters(from fileURL: URL) async throws -> [CharacterInfo]
}

/// Write merged cast list back to PROJECT.md
public struct ProjectCastWriter {
    public init(projectURL: URL)

    /// Update PROJECT.md with merged cast list (preserves existing voice assignments)
    public func updateCastList(_ cast: [CastMember]) throws
}
```

### Dependencies

| Package | Purpose |
|---------|---------|
| SwiftProyecto | `ProjectFrontMatter`, `CastMember`, `ProjectMarkdownParser` |
| MLX Swift (or Python bindings) | Local LLM inference for character extraction |

**Note**: SwiftHablare and voice assignment logic live in Produciesta, not SwiftEchada.

### MLX Integration Options

**Option 1: MLX Python Bindings** (simpler, requires Python)
- Use `PythonKit` or `subprocess` to call MLX Python API
- Pass screenplay text as prompt, get JSON response
- Faster initial development

**Option 2: MLX Swift** (native, no Python dependency)
- Use `mlx-swift` or native Swift bindings if available
- Pure Swift implementation
- Better performance and integration

**Recommended**: Start with Option 1 (Python bindings) for rapid prototyping, migrate to Option 2 if performance becomes an issue.

## MLX Prompt Strategy

One query per screenplay file. The prompt includes:
- The full screenplay text (or chunked if too large)
- Instruction to extract all speaking characters
- JSON schema for structured output

**Prompt Template**:

```
System: You are a screenplay analyst. Extract all speaking characters from the provided screenplay.
Return ONLY a JSON array with this exact format:
[
  {"name": "CHARACTER_NAME", "description": "brief description"},
  ...
]

Character names should be in UPPERCASE as they appear in the screenplay.
Only include characters with dialogue (exclude action-only characters).

User: Extract characters from this screenplay:

{screenplay_text}
```

**Expected JSON Response**:

```json
[
  {"name": "NARRATOR", "description": "Omniscient narrator"},
  {"name": "PROTAGONIST", "description": "Main character"},
  {"name": "BOB", "description": "Supporting character"}
]
```

## Character Merging Strategy

When merging character lists from multiple screenplay files:

1. **Deduplicate by name** (case-insensitive, normalized)
   - "NARRATOR" == "narrator" == "Narrator"
   - First occurrence keeps its description

2. **Preserve existing voice assignments**
   - If character already in PROJECT.md cast with voice URIs, keep them
   - If character is new, add with empty `voices` array

3. **Sort alphabetically**
   - Final cast list sorted by character name for consistency

**Example**:

```yaml
# PROJECT.md front matter (before)
cast:
  - character: NARRATOR
    voices: ["apple://com.apple.voice.premium.en-US.Ava"]

# After running SwiftEchada (merged from 3 screenplay files):
cast:
  - character: NARRATOR
    voices: ["apple://com.apple.voice.premium.en-US.Ava"]  # Preserved
  - character: PROTAGONIST
    voices: []  # New character, no voice assigned yet
  - character: BOB
    voices: []
```

## Integration with Produciesta

SwiftEchada is used as a library in Produciesta for automatic cast list discovery:

```swift
// In Produciesta CLI or GUI
import SwiftEchada
import SwiftProyecto

let extractor = CharacterExtractor(projectURL: projectURL)
let mergedCast = try await extractor.extractAndMergeCast()

let writer = ProjectCastWriter(projectURL: projectURL)
try writer.updateCastList(mergedCast)

// Now Produciesta can proceed with voice assignment using SwiftHablare
```

**Separation of Concerns**:
- **SwiftEchada**: Character extraction (what characters exist)
- **Produciesta**: Voice assignment + audio generation (what voices to use, generate audio)

## Success Criteria

- Extract characters from all screenplay files matching `filePatterns` in PROJECT.md
- MLX returns structured JSON with character names and descriptions
- Deduplicate characters across multiple files (case-insensitive)
- Preserve existing voice assignments when merging
- Write merged cast list back to PROJECT.md in correct YAML format
- Library API is simple and composable for use in Produciesta
- Works fully offline via local MLX model (no network required)

## Future Enhancements (Out of Scope for v1)

- Character relationship extraction (who interacts with whom)
- Scene-by-scene character tracking
- Dialogue amount estimation per character
- Voice recommendation based on character description (this would be a separate voice matching feature)
