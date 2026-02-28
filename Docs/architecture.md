# Architecture

**Version**: 0.10.0 | **Swift**: 6.2 | **Platforms**: macOS 26+, iOS 26+

---

## Module Graph

```
                    +-----------------+
                    |   SwiftEchada   |  (Library: pure data types)
                    |  5 files, 234L  |
                    +--------+--------+
                             |
                             | depends on
                             v
                    +-----------------+
                    |  SwiftProyecto  |  (PROJECT.md parsing, CastMember, Gender)
                    +-----------------+

                    +-----------------+
                    |     echada      |  (CLI executable)
                    |  7 files, ~500L |
                    +--------+--------+
                             |
              +--------------+--------------+------------------+
              |              |              |                  |
              v              v              v                  v
       SwiftEchada    SwiftVoxAlta     mlx-swift         vox-format
       (profiles,     (VoiceLock,    (GPU compute,       (VoxFile,
        merger,        VoxExporter,   MLXArray)           VoxManifest)
        samples)       ModelManager)
                             |
                             v
                       mlx-audio-swift
                       (Qwen3TTSModel,
                        AudioConversion)
```

**Key rule**: The library has zero ML dependencies. All voice generation logic lives in the CLI.

---

## Source Layout

### Library (`Sources/SwiftEchada/` -- 5 files)

| File | Lines | Types | Role |
|------|------:|-------|------|
| `SwiftEchada.swift` | 5 | `SwiftEchada` enum | Module marker + `version` constant |
| `CharacterProfile.swift` | 74 | `CharacterProfile`, `CharacterEvidence` | Voice design specification with gender/age/traits |
| `CharacterInfo.swift` | 12 | `CharacterInfo` | Lightweight extracted character from `.fountain` |
| `CharacterMerger.swift` | 69 | `CharacterMerger` | Dedup + merge character lists, preserve voice data |
| `SampleSentenceGenerator.swift` | 74 | `SampleSentenceGenerator` | 20 curated quotes for TTS auditions |

### CLI (`Sources/echada/` -- 7 files)

| File | Lines | Types | Role |
|------|------:|-------|------|
| `EchadaCLI.swift` | ~15 | `EchadaCLI` | `@main` entry, subcommand registration |
| `CastCommand.swift` | ~90 | `CastCommand` | Default: batch voice gen from PROJECT.md |
| `VoiceCommand.swift` | ~110 | `VoiceCommand` | Single voice gen from prompt |
| `TestVoiceCommand.swift` | ~60 | `TestVoiceCommand` | Hidden: hardcoded NARRATOR for integration tests |
| `CastVoiceGenerator.swift` | ~267 | `CastVoiceGenerator` | Two-phase pipeline orchestrator |
| `VoiceDesigner.swift` | ~125 | `VoiceDesigner` | Compose voice descriptions, generate candidate WAVs |
| `ReferenceAudioGenerator.swift` | ~50 | `ReferenceAudioGenerator` | macOS `say` fallback (not in main pipeline) |

### Tests (`Tests/SwiftEchadaTests/` -- 6 files, 31 tests)

| File | Tests | Coverage |
|------|------:|----------|
| `SwiftEchadaTests.swift` | 1 | Version constant |
| `CharacterProfileTests.swift` | 6 | Profile struct, gender mapping, codability |
| `CharacterInfoTests.swift` | 9 | Extraction struct, JSON round-trip |
| `CharacterMergerTests.swift` | 8 | Dedup, voice preservation, sorting |
| `SampleSentenceGeneratorTests.swift` | 4 | Random quotes, async generation |
| `VoicePromptRoundTripTests.swift` | 3 | YAML parse/serialize round-trips |

---

## Data Flow

### Cast Pipeline (full flow)

```
.fountain files
      |
      v
[SwiftProyecto: ProjectMarkdownParser]
      |
      v
PROJECT.md frontmatter ──> CastMember[]
      |                     (character, actor?, gender?,
      |                      voiceDescription?, voices{})
      v
CastVoiceGenerator.generate(cast:)
      |
      |── Phase A: Candidate Generation ──────────────────────────
      |   Load VoiceDesign 1.7B model (once for all characters)
      |   For each CastMember with voiceDescription:
      |     1. SampleSentenceGenerator.defaultSentence(characterName)
      |     2. Qwen3TTSModel.generate(text: sample, voice: prompt)
      |     3. AudioConversion.mlxArrayToWAVData() → candidateWAV
      |     4. GPU flush (Stream.synchronize + Memory.clearCache)
      |   Unload VoiceDesign model
      |
      |── Phase B: Voice Locking ─────────────────────────────────
      |   Load Base model (0.6b or 1.7b, once for all characters)
      |   For each candidate:
      |     1. VoiceLockManager.createLock() → VoiceLock
      |     2. Open existing VoxFile or create new one
      |     3. VoxExporter.addClonePrompt(to:data:modelRepo:)
      |     4. VoxExporter.addSampleAudio(to:data:modelRepo:)
      |     5. vox.write(to: outputURL)
      |   Update CastMember.voices["voxalta"] = path
      |
      v
Updated PROJECT.md with voice paths
```

### Single Voice Pipeline (`echada voice`)

Same two-phase structure but for one voice:

```
Text prompt ──> VoiceDesign 1.7B ──> candidateWAV
                                          |
candidateWAV ──> Base model ──> VoiceLock |
                                    |     |
                              VoxFile <───┘
                                |
                           .vox file
```

---

## .vox Bundle Structure

A `.vox` file is a zip archive managed by the `vox-format` package:

```
narrator.vox (zip archive)
├── manifest.json
│   ├── name: "NARRATOR"
│   ├── description: "Deep authoritative baritone..."
│   ├── provenance:
│   │   ├── method: "synthesized"
│   │   ├── engine: "qwen3-tts"
│   │   └── license: "CC0-1.0"
│   ├── referenceAudio: [...]
│   └── embeddings: [...]
├── embeddings/
│   ├── qwen3-tts-0.6b-clone-prompt.bin
│   └── qwen3-tts-1.7b-clone-prompt.bin
└── audio/
    ├── qwen3-tts-0.6b-sample.wav
    └── qwen3-tts-1.7b-sample.wav
```

**Multi-model support**: Running `echada voice` or `echada test-voice` against an existing `.vox` file appends the new model's embeddings without overwriting.

---

## Concurrency Model

- **Swift 6 language mode** with `StrictConcurrency` upcoming feature
- All library types are `Sendable` (immutable structs)
- CLI uses `AsyncParsableCommand` for async entry points
- `@preconcurrency import` on VoxFormat, MLX, MLXAudioTTS, MLXLMCommon (thread-safety boundary)
- `queryFn` closures marked `@Sendable` in `SampleSentenceGenerator`

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Library has no ML deps | Keeps library usable as a pure SPM dependency without Metal/MLX |
| Two-phase pipeline | Avoids GPU OOM from loading VoiceDesign + Base simultaneously |
| `SwiftEchada` is an enum | Prevents accidental instantiation; creates module/type name collision (see [gotchas](gotchas.md)) |
| Prompt-based voice gen | No LLM needed; voice descriptions are human-written text in PROJECT.md |
| Random quotes for samples | Deterministic, no ML dependency; placeholder for future LLM-based generation |
| `VoxFile` is a class | Mutable container pattern: create/open → add data → write |
