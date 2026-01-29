# SwiftEchada - AI-Powered Cast Management for Screenplays

## Overview

A Swift library and CLI that analyzes screenplay files referenced in a PROJECT.md, extracts character lists using local LLM inference (via SwiftBruja), merges them into a unified cast list, and optionally matches characters to TTS voices. Results are written back to the PROJECT.md YAML front matter.

**Two core capabilities:**
1. **Character extraction** from screenplays via LLM
2. **Cast-to-voice matching** using TTS provider voice catalogs

## Implementation Status

### Completed

- **CharacterExtractor** — Discovers screenplay files, queries LLM per file, parses JSON character lists, merges via CharacterMerger, returns updated ProjectFrontMatter
- **Scene-based chunking** — Automatically splits large screenplays (>2000 tokens) by scene headings, processes chunks in parallel, merges character extractions
- **CharacterMerger** — Deduplicates by name (case-insensitive), preserves existing voice/actor assignments, sorts alphabetically
- **CharacterInfo** — Codable/Sendable struct for extracted character data
- **CastMatcher** — Matches cast members to TTS voices using LLM selection with retry logic
- **CLI (`echada`)** — Three subcommands: `extract`, `match`, `download`
- **CLI progress output** — Download command has a visual progress bar; extract command shows per-file progress with stdout flushing for non-TTY environments
- **End-to-end verified** — Full pipeline tested with real Phi-3-mini-4k model on fixture screenplay
- **Test suite** — 31 tests across 5 suites (all passing)
- **CI/CD** — GitHub Actions on macOS-26 with coverage reporting; branch protection on main
- **Dependency resolution** — SwiftHablare `swift-transformers` bumped to 1.1.6 (PR #84)

### Architecture

```
Layer 0: SwiftFijos, SwiftBruja
Layer 1: SwiftCompartido(→Fijos), SwiftProyecto(→Bruja)
Layer 2: SwiftHablare(→Fijos,Compartido,Proyecto), SwiftSecuencia(→Compartido,Fijos)
Layer 3: SwiftEchada(→Proyecto,Hablare,Bruja)
```

### Library Target: `SwiftEchada`

Depends on SwiftProyecto and SwiftHablare. Uses closure-based dependency injection (`queryFn`) so core logic is testable without MLX hardware.

| Component | File | Purpose |
|-----------|------|---------|
| `CharacterExtractor` | `CharacterExtractor.swift` | Orchestrates file discovery, LLM extraction, merging |
| `CharacterMerger` | `CharacterMerger.swift` | Deduplicates and merges character lists across files |
| `CharacterInfo` | `CharacterInfo.swift` | Extracted character data struct |
| `CastMatcher` | `CastMatcher.swift` | Matches cast members to TTS voices via LLM |
| `SwiftEchada` | `SwiftEchada.swift` | Module version constant |

### CLI Target: `echada`

Depends on SwiftEchada, SwiftBruja, and ArgumentParser.

| Command | File | Purpose |
|---------|------|---------|
| `extract` | `ExtractCommand.swift` | Extract characters from screenplay files |
| `match` | `MatchCommand` (in EchadaCLI.swift) | Match cast to TTS voices |
| `download` | `DownloadCommand.swift` | Download LLM models |

## Key Types

```swift
public struct CharacterInfo: Codable, Sendable, Equatable {
    public let name: String
    public let description: String?
}

public struct CharacterExtractor: Sendable {
    public init(projectDirectory: URL, frontMatter: ProjectFrontMatter)
    public func extractAll(
        queryFn: @Sendable (String, String) async throws -> String,
        progressFn: (@Sendable (String, Int, Int) -> Void)? = nil
    ) async throws -> ProjectFrontMatter
    public func extractCharacters(
        from fileURL: URL,
        queryFn: @Sendable (String, String) async throws -> String
    ) async throws -> [CharacterInfo]
}

public struct CharacterMerger: Sendable {
    public func merge(
        extracted: [[CharacterInfo]],
        existingCast: [CastMember]?
    ) -> [CastMember]
}

public struct CastMatcher: Sendable {
    public init(providerId: String, languageCode: String?, model: String, force: Bool)
    public func match(
        frontMatter: ProjectFrontMatter,
        queryFn: @Sendable (String, String, String) async throws -> String
    ) async throws -> MatchResult
}
```

## Dependencies

| Package | Branch | Purpose |
|---------|--------|---------|
| SwiftProyecto | development | `ProjectFrontMatter`, `CastMember`, `ProjectMarkdownParser`, `FilePattern` |
| SwiftHablare | development | `GenerationService`, `Voice` (for CastMatcher voice fetching) |
| SwiftBruja | main | Local LLM inference (CLI only, injected via closure in library) |
| swift-argument-parser | 1.3.0+ | CLI argument parsing |

## Workflow

### Character Extraction

1. Parse PROJECT.md via `ProjectMarkdownParser` → `ProjectFrontMatter`
2. Discover screenplay files matching `resolvedFilePatterns` in project directory
3. For each file: read content → build prompt → call `queryFn` → parse JSON `[CharacterInfo]`
4. Merge all character lists via `CharacterMerger` (dedup, preserve voices, sort)
5. Return updated `ProjectFrontMatter` with merged cast

### Voice Matching

1. Parse PROJECT.md → `ProjectFrontMatter` with existing cast
2. Fetch available voices from TTS provider via `GenerationService`
3. For each unmatched cast member: build prompt with character + voice options → call `queryFn`
4. Parse voice ID from response, build voice URI, update cast
5. Return updated `ProjectFrontMatter` with voice assignments

## LLM Prompt Strategy

**Character extraction** — one query per screenplay file:

```
System: You are a screenplay analyst. Extract all speaking characters...
        Return ONLY a JSON array: [{"name": "NAME", "description": "..."}]

User: Extract characters from this screenplay:
      {screenplay_text}
```

**Voice matching** — one query per cast member:

```
System: You are a casting director assigning TTS voices...
        Respond with ONLY the voice ID.

User: Character: {name}, Actor: {actor}, Genre: {genre}
      Available voices: {voice_list}
      Which voice ID best fits?
```

## Character Merging Rules

1. **Deduplicate by name** — case-insensitive, whitespace-trimmed
2. **Preserve existing data** — voice URIs, actor names, gender from PROJECT.md
3. **New characters** — added with empty voices array
4. **Existing-only characters** — preserved even if not in extracted files
5. **Sort alphabetically** — by character name

## Test Coverage

| Suite | Tests | Coverage |
|-------|-------|----------|
| CharacterInfoTests | 4 | JSON encode/decode, nil description |
| CharacterMergerTests | 6 | Dedup, voice preservation, sort, multi-file merge |
| CharacterExtractorTests | 8 | Mock queryFn, markdown blocks, empty dir, voice preservation, malformed JSON, chunking (large/small files, deduplication) |
| CastMatcherTests | 8 | Voice matching, skip/force logic, retry, error handling, language fallback |
| IntegrationTests | 3 | Fixture file extraction, existing cast preservation, multi-pattern discovery |
| SwiftEchadaTests | 1 | Version check |
| **Total** | **31** | All passing |

## Future Work

- Character relationship extraction
- Dialogue amount estimation per character
- Scene-level character tracking
