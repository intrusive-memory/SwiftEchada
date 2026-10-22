---
type: doc
---

# API Reference

**Version**: 1.0.0 | **Platforms**: iOS 27.0+, macOS 27.0+
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

## Voice library (`EchadaVoice`)

What an app links to build and play character voices (Personaje Part B). No
ArgumentParser and no PROJECT.md reader in its dependency closure. It writes
`.vox` and `.m4a` files only; CAST.md goes through SwiftReparto and
`manifest.json` through SwiftDossier.

### `VoiceBuilder` (struct)

```swift
public struct VoiceBuilder: Sendable {
    public init(castDirectory: URL, charactersDir: String = "characters")

    public func location(for member: CastMember) throws -> VoiceLocation

    // EC-P6: one design, locked with each size, one .vox.
    public func buildVoice(for member: CastMember, language: String = "en", accent: String? = nil,
                           models: [VoiceModelSize] = [.large, .small],
                           progress: @Sendable (VoiceBuildProgress) -> Void = { _ in })
        async throws -> VoiceBuildResult

    // EC-P7: candidates to play, then lock the chosen one.
    public func audition(for member: CastMember, language: String = "en", accent: String? = nil,
                         count: Int = 3, progress: …) async throws -> [VoiceAudition]
    public func lock(_ audition: VoiceAudition, for member: CastMember,
                     models: [VoiceModelSize] = [.large, .small], progress: …)
        async throws -> VoiceBuildResult

    // EC-P8 / EC-28: voice/sample-<variant>[-<model>].m4a.
    public func renderSample(for member: CastMember, variant: String = "neutral", text: String? = nil,
                             model: VoiceModelSize = .large, language: String? = nil,
                             sampleLine: String? = nil, instruct: String? = nil, progress: …)
        async throws -> VoiceSample

    public static func modelSizes(inVoxAt url: URL) throws -> [VoiceModelSize]
    public static func sampleFileName(variant: String, model: VoiceModelSize) -> String
}
```

- `VoiceModelSize`: `.large` (`"1.7b"`, the default) and `.small` (`"0.6b"`).
- `VoiceBuildProgress`: `.designing(index:count:)`, `.locking(size)`, `.writing(relativePath:)`, `.renderingSample(variant:model:)`.
- `VoiceBuildResult`: `location`, `models`, `sampleText`, and `updating(_ member:)` to set `voices.voxalta`.
- `VoiceSample` (Codable): `variant`, `model`, `language`, `sampleText`, `relativePath`.
- Every call loads the models it needs and unloads them before returning,
  including on error, and checks `Task.checkCancellation()` between steps.
  Models come from the shared SwiftAcervo directory, so the host needs the
  `group.intrusive-memory.models` App Group (EC-P10).

### `VoiceLocation` (struct) — EC-23, EC-24

```swift
public struct VoiceLocation: Equatable, Sendable {
    public enum Rule { case manifest, existingPointer, newDossier }
    public let relativePath: String   // relative to CAST.md's directory
    public let url: URL
    public let rule: Rule

    public static func resolve(for member: CastMember, castDirectory: URL,
                               charactersDir: String = "characters",
                               fileManager: FileManager = .default) throws -> VoiceLocation
    public static func fileName(for character: String) throws -> String
}
```

Rules, first match wins: the member's `manifest:` → `<bundle>/voice/<NAME>.vox`;
an existing `voices.voxalta` path → that path, in place; otherwise
`<charactersDir>/<NAME>.dossier/voice/<NAME>.vox`. `<NAME>` is
`CastMember.canonicalName(character)` exactly. `VoiceLocationError`:
`.invalidName`, `.nonCanonicalName` (run `reparto canonicalize`),
`.outsideCastDirectory`, `.caseCollision`.

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
`echada` never invents it (migration emits no `portrait:` key a member did not
already carry).

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

**File ownership**: all cast reads and writes go to `CAST.md` (SwiftReparto). `PROJECT.md` (SwiftProyecto) supplies project-level fields — `title`, `episodesDir`, `filePattern`, `tts.model` — and is written only by automatic migration: when it still holds a legacy `cast:` block, the first generate stage to open it moves the roster into `CAST.md`, saves `PROJECT.md.bak`, removes the block, and stamps `schemaVersion: 5`.

### Commands

There is **no** default subcommand: running bare `echada` prints help. Invoke
a command explicitly.

| Command | Description |
|---------|-------------|
| `cast` | Meta / orchestrator: bootstrap PROJECT.md + CAST.md, then run `generate prompt` → `generate vox` |
| `generate` | Container for the two pipeline stages (`prompt`, `vox`); no default subcommand |
| `sample` | Export playable `.m4a` samples beside a character's `.vox` (EC-28) |
| `migrate voices` | Move existing `.vox` files into the character record (EC-26) |
| `auth` | LLM credentials (SwiftLlavero) |
| `voice` | Generate a single .vox voice file from a text prompt |
| `test-voice` | Hidden — generate a test .vox file for integration testing |

**The `--cast` flag**: every roster-touching command (`cast`, `generate prompt`,
`generate vox`, `sample`, `migrate voices`) accepts
`--cast <filename>` (default `CAST.md`). It is a **bare filename only** — the
roster always lives in `--project`'s directory, and path separators are
rejected.

### `echada cast` — voice pipeline

Bootstraps `PROJECT.md` when absent (no LLM — inferred
title/author/`episodesDir`/`filePattern` from the surrounding directory via
`ProjectService.analyzeForGeneration(at:)`), ensures the `--cast` roster file
beside it (seeded from a legacy `cast:` block when present, created empty
otherwise; an existing roster is left untouched), then runs `generate prompt` →
`generate vox` in order. Every stage is idempotent, so re-running only fills
the gaps. echada does not discover cast members (3.0.0): an empty roster stops
the pipeline with advice to run `personaje cast-discover`.

```
echada cast [--project <path>] [--cast <filename>] [--character <name>]
            [--tts-model <variant>] [--language <bcp-47>]... [--accent <directive>]
            [--llm <model>] [--force] [--dry-run] [--verbose]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md file (created if absent) |
| `--cast` | `CAST.md` | Filename of the cast roster (created if absent); bare filename resolved beside `--project`. Forwarded to every stage |
| `--character` | all | Limit the prompt and vox stages to a single character |
| `--tts-model` | from PROJECT.md or `1.7b` | TTS model variant for the vox stage (`0.6b`, `1.7b`); forwarded to `generate vox` |
| `--language` | `en` (repeatable) | BCP-47 code(s) for the vox stage's reference sample; forwarded to `generate vox` |
| `--accent` | none | Accent/delivery directive applied to every character's voice in the vox stage; forwarded to `generate vox` |
| `--llm` | `on-device` | Model for the prompt stage: `on-device`, `pcc`, or `account:model`; forwarded to `generate prompt` |
| `--force` | false | Cascading force: overwrites existing voice prompts and regenerates existing `.vox` files (fans out to each stage's own force flag) |
| `--dry-run` | false | Run the offline bootstrap and migration steps, but stop before the model-backed prompt and vox stages |
| `--verbose` | false | Verbose output for every stage |

### `echada generate` (container, no default subcommand)

Container for the two generative pipeline stages, each runnable standalone
for per-stage control. Running `echada generate` with no subcommand prints
help rather than defaulting to a stage.

```
echada generate <prompt|vox>
```

#### `echada generate prompt`

Examines each cast member's dialogue in the screenplay source and writes a
`voicePrompt` into CAST.md with the model chosen by `--llm` (on-device by default). This is the
command formerly known as the standalone `echada prompt` (removed in v0.16.0).

```
echada generate prompt [--project <path>] [--cast <filename>] [--character <name>] [--llm <model>] [--force] [--dry-run] [--verbose]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md file (read-only: episode discovery config) |
| `--cast` | `CAST.md` | Filename of the cast roster; bare filename resolved beside `--project` |
| `--character` | all | Generate a voice prompt for a single character |
| `--llm` | `on-device` | `on-device`, `pcc`, or any `account:model` from `echada auth` |
| `--force` | false | Overwrite voice prompts for members that already have one (default: fill empty only) |
| `--dry-run` | false | Preview gathered source material without calling the model or writing |
| `--verbose` | false | Verbose output |

#### `echada generate vox`

Synthesizes an on-device `.vox` voice for each cast member from their
`voicePrompt`, recorded under `voices.voxalta` in CAST.md (paths relative to
CAST.md's directory). The file goes where `VoiceLocation` says (EC-23): beside
the member's `manifest:`, else at its existing `voices.voxalta` path, else
`<charactersDir>/<NAME>.dossier/voice/<NAME>.vox`, where `charactersDir` is
PROJECT.md `personaje.charactersDir` (default `characters`). `--dry-run` prints
each destination. A member whose name isn't canonical fails alone.

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

### `echada sample` (EC-28)

```
echada sample <CHARACTER> [--variant neutral|<name>] [--text "…"] [--model 1.7b|0.6b]
                          [--all-variants] [--json] [--project <path>] [--cast <filename>]
```

Writes `<character dir>/voice/sample-<variant>.m4a`, adding `-0.6b` for the
small model. `neutral` exports the `.vox`'s embedded sample (no synthesis);
other variants, or `--text`, synthesize with the variant as the delivery
instruction, speaking `--text`, CHARACTER.md `sampleLine`, or a fixed line.
`--all-variants` renders `voice/samples.yaml` (dossier-format §10) when
present, else `neutral` on each size. `--json` prints `[VoiceSample]`.

### `echada migrate voices` (EC-26)

```
echada migrate voices [--project <path>] [--cast <filename>] [--apply]
```

Dry run by default: prints each member's old path → new path, skipped paths
outside the project, and `voices/*.vox` files no member points at. `--apply`
copies and SHA-256-verifies each file, rewrites all pointers in one CAST.md
write, re-reads CAST.md to check them, then removes the old files; any failure
restores CAST.md and removes the copies. Refuses non-canonical names, two
members sharing a destination, and a destination that exists with different
contents. Never touches `manifest.json`.

### Automatic migration (no command)

`verify cast` and `prune cast` were removed in v2.0.0. Any generate stage that
opens a `PROJECT.md` still holding a `cast:` block migrates it first, via
`ProjectMigration.migrateIfNeeded(projectURL:castName:dryRun:)`:

1. Merge the legacy roster into `CAST.md` (`[CastMember].merging(_:)`: adds
   missing members and fills empty fields, never overwrites). Field conflicts
   are printed, and `CAST.md`'s value wins.
2. Re-read `CAST.md`; throw `ProjectMigrationError.charactersMissingAfterTransfer`
   if a legacy character is absent. `PROJECT.md` is untouched in that case.
3. Copy `PROJECT.md` to `PROJECT.md.bak` (`.bak.1`, … if taken).
4. Rewrite `PROJECT.md` with `removingCastBlock(in:)` then
   `stampingSchemaVersion(in:)`.

Under `generate … --dry-run` the migration is described but nothing is written.

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

### `CastVoiceGenerator` (struct, `EchadaVoice`, package access)

The batch generator `generate vox` uses: Phase A designs every member's
candidate with VoiceDesign loaded once, Phase B locks them with the Base model.

```swift
package struct CastVoiceGenerator {
    package static let defaultModelSlug: String       // "1.7b"
    package static let supportedVariants: [String]    // ["0.6b", "1.7b"]

    package init(castDirectory:charactersDir:forceRegenerate:verbose:ttsModelVariant:
                 languages:accent:auditionVariant:log:)
    package func generate(cast: [CastMember]) async throws -> GenerateResult
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
