---
type: doc
---

# API Reference

**Version**: 1.0.0 | **Platforms**: iOS 26.0+, macOS 26.0+
**Swift**: 6.2 | **Language Mode**: v6 (strict concurrency)

---

## Library (`SwiftEchada`)

The library depends **only** on [SwiftReparto](https://github.com/intrusive-memory/SwiftReparto), the leaf package that owns the CAST.md cast schema. It contains pure data types and utilities with no ML or LLM dependencies. SwiftProyecto is no longer a library dependency — it survives on `EchadaCLICore` only.

### `SwiftEchada` (enum)

Module version constant.

```swift
public enum SwiftEchada {
    public static let version: String
}
```

> **Name collision**: `SwiftEchada` is both the module name and an enum type. CLI files must use targeted imports (e.g., `import struct SwiftEchada.CharacterProfile`). See [gotchas.md](gotchas.md).

---

### `CharacterProfile` (struct)

A detailed voice profile for a screenplay character, used to drive voice design.

```swift
public struct CharacterProfile: Codable, Sendable, Equatable {
    public let name: String           // Character name (typically uppercase)
    public let gender: Gender         // SwiftReparto.Gender (was SwiftProyecto's)
    public let ageRange: String       // e.g. "30s", "elderly", "young adult"
    public let description: String    // Full voice description text
    public let voiceTraits: [String]  // e.g. ["gravelly", "low pitch", "warm"]
    public let summary: String        // One-sentence summary for voice synthesis

    public init(name:gender:ageRange:description:voiceTraits:summary:)

    public var voxFormatGender: String  // "male", "female", "nonbinary", "neutral"
}
```

> **`CharacterProfile.gender` is now `SwiftReparto.Gender`.** Before the
> CAST.md extraction it was SwiftProyecto's `Gender`. Consumers that spelled
> out the module name must import SwiftReparto instead; the cases are
> unchanged (`.male`, `.female`, `.nonBinary`, `.notSpecified`).

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

Merges extracted character lists from multiple screenplay files into a unified cast list (`[SwiftReparto.CastMember]`, i.e. a CAST.md roster). Deduplicates by name (case-insensitive), preserves existing voice/actor assignments, and sorts alphabetically.

```swift
public struct CharacterMerger: Sendable {
    public init()

    public func merge(
        extracted: [[CharacterInfo]],
        existingCast: [CastMember]?   // SwiftReparto.CastMember
    ) -> [CastMember]
}
```

**Algorithm**:
1. Dedup the extracted lists — first occurrence of each name wins (case- and whitespace-insensitive)
2. Delegate reconciliation to SwiftReparto's additive `CastMember.merging(_:)` (RQ-14): existing members keep every field, discovered newcomers are appended
3. Result sorted alphabetically (case-insensitive)

---

## Cast Types (from SwiftReparto)

The library re-uses SwiftReparto's cast schema rather than defining its own.
These are the types SwiftEchada consumers see:

### `CastMember` (struct)

```swift
public struct CastMember: Codable, Sendable, Equatable, Hashable, Identifiable {
    public var character: String              // required; also `id`
    public var actor: String?
    public var gender: Gender?
    public var language: String?              // BCP-47 ("en", "es-MX")
    public var voicePrompt: String?           // legacy wire key voiceDescription: still decodes
    public var voices: [String: [String]]     // provider → paths relative to CAST.md's directory
    public private(set) var extraKeys: [String: AnyCodable]  // undeclared keys, preserved verbatim

    public subscript(extra key: String) -> AnyCodable? { get }
    public mutating func setExtra(_ value: AnyCodable?, forKey key: String)
    public func merging(_ discovered: [CastMember]) -> [CastMember]  // on Array<CastMember>
}
```

**`portrait`**: character portraits ride in the reserved `appearance:` block
(`appearance.portrait`), which is *not* a declared field in SwiftReparto 0.1.x —
it is preserved losslessly through `extraKeys` for SwiftSemblanzas, and
`echada` never invents it (`generate cast` seeding emits no `portrait:` key a
member did not already carry).

### `Gender` (enum)

```swift
public enum Gender: String { case male = "M", female = "F", nonBinary = "NB", notSpecified = "NS" }
```

### `CastDocument` (struct)

```swift
public struct CastDocument: Codable, Sendable, Equatable {
    public static let documentType: String    // "cast" — front matter must carry type: cast AND a cast: array
    public var cast: [CastMember]
    public var body: String                   // opaque markdown, re-emitted byte-for-byte
    public var schemaVersion: Int
}
```

### `CastMarkdownParser` / `CastMarkdownGenerator` (structs)

```swift
public struct CastMarkdownParser: Sendable {
    public func parse(content: String) throws -> CastDocument
    public func parse(fileURL: URL) throws -> CastDocument
}

public struct CastMarkdownGenerator {
    public func generate(document: CastDocument) throws -> String
    public func write(document: CastDocument, to fileURL: URL) throws
}
```

The generator is the **only** CAST.md serializer in the ecosystem — `echada`
never builds YAML or splices CAST.md text.

---

## CLI (`echada`)

The `echada` executable is a thin `@main` shim over `EchadaCLICore`, which depends on SwiftEchada, SwiftReparto, SwiftProyecto, SwiftVoxAlta, MLX, MLXAudioTTS, MLXLMCommon, VoxFormat, and ArgumentParser.

**File ownership**: all cast reads and writes go to `CAST.md` (SwiftReparto). `PROJECT.md` (SwiftProyecto) supplies project-level fields — `title`, `episodesDir`, `filePattern`, `tts.model` — and its legacy `cast:` block is read-only (`LegacyProjectCastReader`, for seeding and `verify cast`); the only command that writes it is `prune cast`, which removes the block.

### Commands

There is **no** default subcommand: running bare `echada` prints help. Invoke
a command explicitly.

| Command | Description |
|---------|-------------|
| `cast` | Meta / orchestrator: bootstrap PROJECT.md + CAST.md, then run `generate cast` → `generate prompt` → `generate vox` |
| `generate` | Container for the three individual pipeline stages (`cast`, `prompt`, `vox`); no default subcommand |
| `verify` | Container for report-only migration gates; `verify cast` compares CAST.md against PROJECT.md's legacy `cast:` |
| `prune` | Container for explicit legacy-data removal; `prune cast` strips the migrated `cast:` block from PROJECT.md |
| `voice` | Generate a single .vox voice file from a text prompt |
| `test-voice` | Hidden — generate a test .vox file for integration testing |

**The `--cast` flag**: every roster-touching command (`cast`, `generate cast`,
`generate prompt`, `generate vox`, `verify cast`, `prune cast`) accepts
`--cast <filename>` (default `CAST.md`). It is a **bare filename only** — the
roster always lives in `--project`'s directory, and path separators are
rejected.

### `echada cast` — full pipeline

Bootstraps `PROJECT.md` when absent (no LLM — inferred
title/author/`episodesDir`/`filePattern` from the surrounding directory via
`ProjectService.analyzeForGeneration(at:)`), ensures the `--cast` roster file
beside it (seeded from a legacy `cast:` block when present, created empty
otherwise; an existing roster is left untouched), then runs `generate cast` →
`generate prompt` → `generate vox` in order. Every stage is idempotent, so
re-running only fills the gaps.

```
echada cast [--project <path>] [--cast <filename>] [--character <name>]
            [--tts-model <variant>] [--language <bcp-47>]... [--accent <directive>]
            [--force] [--dry-run] [--verbose]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md file (created if absent) |
| `--cast` | `CAST.md` | Filename of the cast roster (created if absent); bare filename resolved beside `--project`. Forwarded to every stage |
| `--character` | all | Limit the prompt and vox stages to a single character |
| `--tts-model` | from PROJECT.md or `1.7b` | TTS model variant for the vox stage (`0.6b`, `1.7b`); forwarded to `generate vox` |
| `--language` | `en` (repeatable) | BCP-47 code(s) for the vox stage's reference sample; forwarded to `generate vox` |
| `--accent` | none | Accent/delivery directive applied to every character's voice in the vox stage; forwarded to `generate vox` |
| `--force` | false | Cascading force: re-syncs the cast list, overwrites existing voice prompts, and regenerates existing `.vox` files (fans out to each stage's own force flag) |
| `--dry-run` | false | Run the offline bootstrap + cast-discovery steps (writing the discovered cast to CAST.md), but stop before the model-backed prompt and vox stages |
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
LLM/ML) and merges them into the CAST.md roster. PROJECT.md is read-only to
this command (episode discovery config, and the legacy `cast:` block used to
seed a brand-new CAST.md verbatim). Only newly-appearing
characters are added by default; `--force` re-syncs to exactly the characters
found now (matching characters keep their existing downstream fields).

```
echada generate cast [--project <path>] [--cast <filename>] [--force] [--dry-run] [--verbose]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md file (never written) |
| `--cast` | `CAST.md` | Filename of the cast roster; bare filename resolved beside `--project` |
| `--force` | false | Re-sync the cast list to exactly the characters found in the source now |
| `--dry-run` | false | Preview discovered characters without writing |
| `--verbose` | false | Verbose output |

#### `echada generate prompt`

Examines each cast member's dialogue in the screenplay source and writes a
`voicePrompt` into CAST.md via the on-device Foundation Model. This is the
command formerly known as the standalone `echada prompt` (removed in v0.16.0).

```
echada generate prompt [--project <path>] [--cast <filename>] [--character <name>] [--force] [--dry-run] [--verbose]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md file (read-only: episode discovery config) |
| `--cast` | `CAST.md` | Filename of the cast roster; bare filename resolved beside `--project` |
| `--character` | all | Generate a voice prompt for a single character |
| `--force` | false | Overwrite voice prompts for members that already have one (default: fill empty only) |
| `--dry-run` | false | Preview gathered source material without calling the model or writing |
| `--verbose` | false | Verbose output |

#### `echada generate vox`

Synthesizes an on-device `.vox` voice for each cast member from their
`voicePrompt`, recorded under `voices.voxalta` in CAST.md (paths relative to
CAST.md's directory). This is the
command formerly known as `echada cast` before it was repurposed into the
pipeline orchestrator in v0.16.0.

```
echada generate vox [--project <path>] [--cast <filename>] [--force-regenerate]
                    [--dry-run] [--verbose] [--tts-model <variant>] [--character <name>]
                    [--language <bcp-47>]... [--accent <directive>]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md (read-only: `tts.model` default) |
| `--cast` | `CAST.md` | Filename of the cast roster; bare filename resolved beside `--project` |
| `--force-regenerate` | false | Regenerate even if .vox exists |
| `--dry-run` | false | Preview without writing files |
| `--verbose` | false | Verbose output |
| `--tts-model` | from PROJECT.md or `1.7b` | TTS model variant (`0.6b`, `1.7b`) |
| `--character` | all | Generate for single character by name |
| `--language` | `en` (repeatable) | BCP-47 code(s) for the reference sample; repeat to cast multiple languages into one `.vox` |
| `--accent` | none | Accent/delivery directive applied to every character's voice prompt |

### `echada verify cast`

Read-only migration gate. Compares the CAST.md roster against the legacy
`cast:` block still present in PROJECT.md and reports three divergence
classes: characters present in one file and not the other, differing field
values on a matched character (`actor`, `gender`, `language`, `voicePrompt`,
`voices`, or any undeclared key such as `bio:`), and `.vox` pointers in
CAST.md that do not resolve to an existing file (relative to CAST.md's
directory). Neither file is ever written. Exits 0 on agreement, non-zero on
any divergence — suitable for gating CI or a rollout loop.

```
echada verify cast [--project <path>] [--cast <filename>]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md file (never written) |
| `--cast` | `CAST.md` | Filename of the cast roster (never written); bare filename resolved beside `--project` |

### `echada prune cast`

Strips the migrated legacy `cast:` block from PROJECT.md — the **only**
command anywhere in `echada` that writes PROJECT.md's cast data. Two gates
guard the removal: CAST.md must exist beside PROJECT.md, and the
`verify cast` check must pass. Only the `cast:` line span is excised; every
other byte of the file is preserved verbatim. Idempotent (a `cast:`-less
PROJECT.md reports "nothing to prune" and exits 0) and explicit-only — no
other command ever invokes it.

```
echada prune cast [--project <path>] [--cast <filename>] [--dry-run]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md file |
| `--cast` | `CAST.md` | Filename of the cast roster (never written); bare filename resolved beside `--project` |
| `--dry-run` | false | Print the exact removal diff without writing PROJECT.md |

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
| SwiftReparto | 0.1.0+ | Library + CLI | `CastMember`, `Gender`, `CastDocument`, `CastMarkdownParser`, `CastMarkdownGenerator`, `ProjectCastImporter` |
| SwiftProyecto | 4.8.1+ | CLI | `ProjectMarkdownParser`, `ProjectFrontMatter`, `ProjectService` (project-level fields only) |
| SwiftVoxAlta | 0.14.1+ | CLI | `VoxAltaModelManager`, `VoiceLockManager`, `VoxExporter`, `Qwen3TTSModelRepo` |
| swift-argument-parser | 1.7.1+ | CLI | `AsyncParsableCommand`, `CommandConfiguration` |
| mlx-swift | 0.31.3+ | CLI | `MLXArray`, `Stream`, `Memory` |
| mlx-swift-lm | 3.31.3+ | CLI | `GenerateParameters` |
| mlx-audio-swift | 0.10.0+ | CLI | `Qwen3TTSModel`, `AudioConversion` |
| vox-format | 0.4.1+ | CLI | `VoxFile`, `VoxManifest`, `VoxManifest.Provenance` |
