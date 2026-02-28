# SwiftEchada API Reference

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

> **Note**: `SwiftEchada` is both the module name and an enum type. CLI files must use targeted imports (e.g., `import struct SwiftEchada.CharacterProfile`) to avoid name collision.

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

---

### `SampleSentenceGenerator` (struct)

Generates sample sentences for TTS voice design auditions. Contains 20 curated Dorothy Parker and Fran Lebowitz quotes (15-30 words each). The `queryFn` parameters on `generate()` methods are accepted for API compatibility but ignored — a random quote is always returned.

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
| `cast` | Yes | Generate on-device voices for cast members from voice prompts in PROJECT.md |
| `voice` | No | Generate a single .vox voice file from a text prompt |
| `test-voice` | Hidden | Generate a test .vox file for integration testing |

### `echada cast` (default subcommand)

Generate on-device voices for cast members. Reads voice description prompts from PROJECT.md, generates .vox bundles via a two-phase pipeline.

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

**Model resolution order**: `--tts-model` flag > `tts.model` in PROJECT.md > `1.7b`

**Two-phase pipeline**:
1. **Phase A**: Load VoiceDesign 1.7B model once, generate all candidate WAVs
2. **Phase B**: Load Base model once, create all voice locks and export .vox bundles

### `echada voice`

Generate a single .vox voice file from a text prompt (no PROJECT.md required).

```
echada voice <prompt> [--output <path>] [--name <name>]
             [--tts-model <variant>] [--verbose]
```

| Flag | Default | Description |
|------|---------|-------------|
| `<prompt>` | required | Voice description (e.g., "A warm female voice with a slight southern accent") |
| `--output` | `voice.vox` | Output .vox path |
| `--name` | `Voice` | Character name for manifest |
| `--tts-model` | `1.7b` | TTS model variant |
| `--verbose` | false | Verbose output |

Appends to existing .vox files (multi-model support).

### `echada test-voice` (hidden)

Generate a test .vox file with a predefined NARRATOR profile for integration testing.

```
echada test-voice --output <path> [--tts-model <variant>]
```

---

## CLI Support Types (internal)

### `VoiceDesigner` (enum)

Composes voice descriptions and generates candidate WAV audio using VoiceDesign Qwen3-TTS.

```swift
enum VoiceDesigner {
    static func composeVoiceDescription(from profile: CharacterProfile) -> String
    static func generateCandidate(profile:modelManager:sampleSentence:) async throws -> Data
    static func generateCandidates(profile:count:modelManager:sampleSentence:) async throws -> [Data]
}
```

Output: WAV format Data (24kHz, 16-bit PCM, mono).

### `CastVoiceGenerator` (struct)

Orchestrates batch voice generation with two-phase pipeline.

```swift
struct CastVoiceGenerator {
    static let defaultModelSlug: String       // "1.7b"
    static let supportedVariants: [String]    // ["0.6b", "1.7b"]

    init(projectDirectory:forceRegenerate:verbose:ttsModelVariant:)
    func generate(cast: [CastMember]) async throws -> GenerateResult
}
```

### `ReferenceAudioGenerator` (enum, macOS only)

Fallback audio generation using macOS `say` command. Produces 24kHz, 16-bit PCM mono WAV.

```swift
enum ReferenceAudioGenerator {
    static func generate(text:voice:outputURL:) async throws
    static func generateData(text:voice:) async throws -> Data
}
```

---

## Dependencies

| Package | Version | Target | Purpose |
|---------|---------|--------|---------|
| SwiftProyecto | branch: development | Library | `ProjectFrontMatter`, `CastMember`, `ProjectMarkdownParser`, `Gender` |
| SwiftVoxAlta | branch: development | CLI | On-device voice generation, `VoiceLockManager`, `VoxAltaModelManager`, `VoxExporter` |
| swift-argument-parser | 1.3.0+ | CLI | CLI argument parsing |
| mlx-swift | 0.21.0+ | CLI | MLX framework for ML inference |
| mlx-swift-lm | branch: main | CLI | `MLXLMCommon`, `GenerateParameters` |
| mlx-audio-swift | branch: development | CLI | `Qwen3TTSModel`, `AudioConversion` |
| vox-format | 0.3.0+ | CLI | `VoxFile`, `VoxManifest` for .vox archives |
