---
type: doc
---

# API Reference

**Version**: 0.16.0-dev | **Platforms**: iOS 26.0+, macOS 26.0+
**Swift**: 6.2 | **Language Mode**: v6 (strict concurrency)

---

## Library (`SwiftEchada`)

The library depends **only** on SwiftProyecto. It contains pure data types and utilities with no ML or LLM dependencies.

### `SwiftEchada` (enum)

Module version constant.

```swift
public enum SwiftEchada {
    public static let version: String  // "0.12.0-dev"
}
```

> **Name collision**: `SwiftEchada` is both the module name and an enum type. CLI files must use targeted imports (e.g., `import struct SwiftEchada.CharacterProfile`). See [gotchas.md](gotchas.md).

---

### `CharacterProfile` (struct)

A detailed voice profile for a screenplay character, used to drive voice design.

```swift
public struct CharacterProfile: Codable, Sendable, Equatable {
    public let name: String           // Character name (typically uppercase)
    public let gender: Gender         // From SwiftProyecto
    public let ageRange: String       // e.g. "30s", "elderly", "young adult"
    public let description: String    // Full voice description text
    public let voiceTraits: [String]  // e.g. ["gravelly", "low pitch", "warm"]
    public let summary: String        // One-sentence summary for voice synthesis

    public init(name:gender:ageRange:description:voiceTraits:summary:)

    public var voxFormatGender: String  // "male", "female", "nonbinary", "neutral"
}
```

**Gender mapping** (`voxFormatGender`):
| `Gender` | Output |
|----------|--------|
| `.male` | `"male"` |
| `.female` | `"female"` |
| `.nonBinary` | `"nonbinary"` |
| `.notSpecified` | `"neutral"` |

### `CharacterEvidence` (struct)

Evidence gathered from screenplay text to support a character profile.

```swift
public struct CharacterEvidence: Codable, Sendable, Equatable {
    public let keyDialogue: [String]
    public let stageDirections: [String]
    public let emotionalRange: [String]

    public init(keyDialogue: [String] = [], stageDirections: [String] = [], emotionalRange: [String] = [])
}
```

---

### `CharacterInfo` (struct)

A character extracted from a screenplay file.

```swift
public struct CharacterInfo: Codable, Sendable, Equatable {
    public let name: String
    public let description: String?
    public let voiceDescription: String?

    public init(name:description:voiceDescription:)
}
```

---

### `CharacterMerger` (struct)

Merges extracted character lists from multiple screenplay files into a unified cast list. Deduplicates by name (case-insensitive), preserves existing voice/actor assignments, and sorts alphabetically.

```swift
public struct CharacterMerger: Sendable {
    public init()

    public func merge(
        extracted: [[CharacterInfo]],
        existingCast: [CastMember]?
    ) -> [CastMember]
}
```

**Algorithm**:
1. Build lookup of existing cast by normalized name (lowercased, trimmed)
2. First occurrence of each extracted character wins (dedup)
3. Existing `CastMember` data preserved if character already in cast
4. Unmatched existing members appended
5. Result sorted alphabetically (case-insensitive)

---

## CLI (`echada`)

The CLI executable depends on SwiftEchada, SwiftProyecto, SwiftVoxAlta, MLX, MLXAudioTTS, MLXLMCommon, VoxFormat, and ArgumentParser.

### Commands

| Command | Default? | Description |
|---------|----------|-------------|
| `cast` | Yes | Meta / orchestrator: bootstrap PROJECT.md, then run `generate cast` → `generate prompt` → `generate vox` |
| `generate` | No | Container for the three individual pipeline stages (`cast`, `prompt`, `vox`); no default subcommand |
| `voice` | No | Generate a single .vox voice file from a text prompt |
| `test-voice` | Hidden | Generate a test .vox file for integration testing |

### `echada cast` (default subcommand — full pipeline)

The default command. Bootstraps `PROJECT.md` when absent (no LLM — inferred
title/author/`episodesDir`/`filePattern` from the surrounding directory via
`ProjectService.analyzeForGeneration(at:)`), then runs `generate cast` →
`generate prompt` → `generate vox` in order. Every stage is idempotent, so
re-running only fills the gaps.

```
echada cast [--project <path>] [--character <name>] [--tts-model <variant>]
            [--language <bcp-47>]... [--accent <directive>]
            [--force] [--dry-run] [--verbose]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md file (created if absent) |
| `--character` | all | Limit the prompt and vox stages to a single character |
| `--tts-model` | from PROJECT.md or `1.7b` | TTS model variant for the vox stage (`0.6b`, `1.7b`); forwarded to `generate vox` |
| `--language` | `en` (repeatable) | BCP-47 code(s) for the vox stage's reference sample; forwarded to `generate vox` |
| `--accent` | none | Accent/delivery directive applied to every character's voice in the vox stage; forwarded to `generate vox` |
| `--force` | false | Cascading force: re-syncs the cast list, overwrites existing voice prompts, and regenerates existing `.vox` files (fans out to each stage's own force flag) |
| `--dry-run` | false | Run the offline bootstrap + cast-discovery steps, but stop before the model-backed prompt and vox stages |
| `--verbose` | false | Verbose output for every stage |

### `echada generate` (container, no default subcommand)

Container for the three generative pipeline stages, each runnable standalone
for per-stage control. Running `echada generate` with no subcommand prints
help rather than defaulting to a stage.

```
echada generate <cast|prompt|vox>
```

#### `echada generate cast`

Discovers cast members from the screenplay source (heuristic only, no
LLM/ML) and merges them into PROJECT.md's `cast:` list. Only newly-appearing
characters are added by default; `--force` re-syncs to exactly the characters
found now (matching characters keep their existing downstream fields).

```
echada generate cast [--project <path>] [--force] [--dry-run] [--verbose]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md file |
| `--force` | false | Re-sync the cast list to exactly the characters found in the source now |
| `--dry-run` | false | Preview discovered characters without writing |
| `--verbose` | false | Verbose output |

#### `echada generate prompt`

Examines each cast member's dialogue in the screenplay source and writes a
`voicePrompt` via the on-device Foundation Model. This is the command
formerly known as the standalone `echada prompt` (removed in v0.16.0).

```
echada generate prompt [--project <path>] [--character <name>] [--force] [--dry-run] [--verbose]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md file |
| `--character` | all | Generate a voice prompt for a single character |
| `--force` | false | Overwrite voice prompts for members that already have one (default: fill empty only) |
| `--dry-run` | false | Preview gathered source material without calling the model or writing |
| `--verbose` | false | Verbose output |

#### `echada generate vox`

Synthesizes an on-device `.vox` voice for each cast member from their
`voicePrompt`, recorded under `voices.voxalta` in PROJECT.md. This is the
command formerly known as `echada cast` before it was repurposed into the
pipeline orchestrator in v0.16.0.

```
echada generate vox [--project <path>] [--force-regenerate] [--dry-run] [--verbose]
                    [--tts-model <variant>] [--character <name>]
                    [--language <bcp-47>]... [--accent <directive>]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md |
| `--force-regenerate` | false | Regenerate even if .vox exists |
| `--dry-run` | false | Preview without writing files |
| `--verbose` | false | Verbose output |
| `--tts-model` | from PROJECT.md or `1.7b` | TTS model variant (`0.6b`, `1.7b`) |
| `--character` | all | Generate for single character by name |
| `--language` | `en` (repeatable) | BCP-47 code(s) for the reference sample; repeat to cast multiple languages into one `.vox` |
| `--accent` | none | Accent/delivery directive applied to every character's voice prompt |

### `echada voice`

```
echada voice <prompt> [--output <path>] [--name <name>]
             [--tts-model <variant>] [--verbose]
```

| Flag | Default | Description |
|------|---------|-------------|
| `<prompt>` | required | Voice description text |
| `--output` | `voice.vox` | Output .vox path |
| `--name` | `Voice` | Character name for manifest |
| `--tts-model` | `1.7b` | TTS model variant |
| `--verbose` | false | Verbose output |

Appends to existing .vox files (multi-model support).

### `echada test-voice` (hidden)

```
echada test-voice --output <path> [--tts-model <variant>]
```

Hardcoded NARRATOR profile: male, 40s, "Deep authoritative baritone with warmth and gravitas".

---

## CLI Internal Types

### `VoiceDesigner` (enum)

```swift
enum VoiceDesigner {
    static func composeVoiceDescription(from profile: CharacterProfile) -> String
    static func generateCandidate(profile:modelManager:sampleSentence:) async throws -> Data
    static func generateCandidates(profile:count:modelManager:sampleSentence:) async throws -> [Data]
}
```

Output: WAV Data (24kHz, 16-bit PCM, mono). Generation params: `maxTokens: 16384, temperature: 0.6, topP: 0.6, repetitionPenalty: 1.5`.

### `CastVoiceGenerator` (struct)

```swift
struct CastVoiceGenerator {
    static let defaultModelSlug: String       // "1.7b"
    static let supportedVariants: [String]    // ["0.6b", "1.7b"]

    init(projectDirectory:forceRegenerate:verbose:ttsModelVariant:)
    func generate(cast: [CastMember]) async throws -> GenerateResult
}
```

### `ReferenceAudioGenerator` (enum, macOS only)

```swift
#if os(macOS)
enum ReferenceAudioGenerator {
    static func generate(text:voice:outputURL:) async throws
    static func generateData(text:voice:) async throws -> Data
}
#endif
```

Fallback using macOS `say` + `afconvert`. Same 24kHz/16-bit/mono spec.

---

## Dependencies

| Package | Version | Target | Key Types Used |
|---------|---------|--------|----------------|
| SwiftProyecto | branch: development | Library | `Gender`, `CastMember`, `ProjectMarkdownParser`, `ProjectFrontMatter` |
| SwiftVoxAlta | branch: development | CLI | `VoxAltaModelManager`, `VoiceLockManager`, `VoxExporter`, `Qwen3TTSModelRepo` |
| swift-argument-parser | 1.3.0+ | CLI | `AsyncParsableCommand`, `CommandConfiguration` |
| mlx-swift | 0.21.0+ | CLI | `MLXArray`, `Stream`, `Memory` |
| mlx-swift-lm | branch: main | CLI | `GenerateParameters` |
| mlx-audio-swift | branch: development | CLI | `Qwen3TTSModel`, `AudioConversion` |
| vox-format | 0.3.0+ | CLI | `VoxFile`, `VoxManifest`, `VoxManifest.Provenance` |
