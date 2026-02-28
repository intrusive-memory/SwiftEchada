# API Reference

**Version**: 0.10.0 | **Platforms**: iOS 26.0+, macOS 26.0+
**Swift**: 6.2 | **Language Mode**: v6 (strict concurrency)

---

## Library (`SwiftEchada`)

The library depends **only** on SwiftProyecto. It contains pure data types and utilities with no ML or LLM dependencies.

### `SwiftEchada` (enum)

Module version constant.

```swift
public enum SwiftEchada {
    public static let version: String  // "0.10.0"
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

### `SampleSentenceGenerator` (struct)

Generates sample sentences for TTS voice design auditions. Contains 20 curated Dorothy Parker and Fran Lebowitz quotes (15-30 words each). The `queryFn` parameters on `generate()` methods are accepted for API compatibility but ignored -- a random quote is always returned.

```swift
public struct SampleSentenceGenerator: Sendable {
    public static let quotes: [String]

    public static func randomQuote() -> String
    public static func defaultSentence(for characterName: String) -> String

    public init()

    public func generate(
        from profile: CharacterProfile,
        queryFn: @escaping @Sendable (String, String) async throws -> String
    ) async throws -> String

    public func generate(
        characterName: String,
        description: String,
        queryFn: @escaping @Sendable (String, String) async throws -> String
    ) async throws -> String
}
```

---

## CLI (`echada`)

The CLI executable depends on SwiftEchada, SwiftVoxAlta, MLX, MLXAudioTTS, MLXLMCommon, VoxFormat, and ArgumentParser.

### Commands

| Command | Default? | Description |
|---------|----------|-------------|
| `cast` | Yes | Generate on-device voices for cast members from PROJECT.md |
| `voice` | No | Generate a single .vox voice file from a text prompt |
| `test-voice` | Hidden | Generate a test .vox file for integration testing |

### `echada cast` (default subcommand)

```
echada cast [--project <path>] [--force-regenerate] [--dry-run] [--verbose]
            [--tts-model <variant>] [--character <name>]
```

| Flag | Default | Description |
|------|---------|-------------|
| `--project` | `PROJECT.md` | Path to PROJECT.md |
| `--force-regenerate` | false | Regenerate even if .vox exists |
| `--dry-run` | false | Preview without writing files |
| `--verbose` | false | Verbose output |
| `--tts-model` | from PROJECT.md or `1.7b` | TTS model variant (`0.6b`, `1.7b`) |
| `--character` | all | Generate for single character by name |

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
