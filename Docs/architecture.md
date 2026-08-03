---
type: doc
---

# Architecture

**Version**: 1.0.0 | **Swift**: 6.2 | **Platforms**: macOS 26+, iOS 26+

---

## Module Graph

```
                    +-----------------+
                    |   SwiftEchada   |  (Library: pure data types)
                    +--------+--------+
                             |
                             | depends on (only)
                             v
                    +-----------------+
                    |  SwiftReparto   |  (CAST.md: CastMember, Gender,
                    |     (leaf)      |   CastDocument, CastMarkdownParser)
                    +-----------------+

                    +-----------------+
                    |     echada      |  (executable: thin @main shim)
                    +--------+--------+
                             |
                             v
                    +-----------------+
                    |  EchadaCLICore  |  (all CLI logic)
                    +--------+--------+
                             |
       +----------+----------+-----------+-------------+------------+
       |          |          |           |             |            |
       v          v          v           v             v            v
 SwiftEchada  SwiftReparto  SwiftProyecto  SwiftVoxAlta  mlx-swift  vox-format
 (profiles,   (CAST.md      (PROJECT.md:   (VoiceLock,   (GPU,      (VoxFile,
  merger)      roster)       title,         VoxExporter,  MLXArray)  VoxManifest)
                             episodesDir,   ModelManager)
                             filePattern,        |
                             tts.model)          v
                                           mlx-audio-swift
                                           (Qwen3TTSModel,
                                            AudioConversion)
```

**Key rules**:

- The library has zero ML dependencies and depends **only on SwiftReparto**. All
  voice generation logic lives in `EchadaCLICore`.
- **The `SwiftEchada → SwiftProyecto` edge is gone.** SwiftProyecto survives on
  `EchadaCLICore` only, and only for project-level `PROJECT.md` fields
  (`title`, `episodesDir`, `filePattern`, `tts.model`). Cast never flows
  through SwiftProyecto types.
- **SwiftReparto is a leaf**: it declares no `intrusive-memory` dependency,
  ever, so a package cycle around cast data is impossible by construction
  (SwiftPM evaluates cycles at package granularity — a `SwiftProyecto →
  SwiftEchada` edge could never have been added while SwiftEchada's manifest
  depended on SwiftProyecto).

---

## The CAST.md Layer (SwiftReparto)

Cast data lives in `CAST.md`, beside `PROJECT.md`. SwiftReparto owns the file
end to end:

- **`CastDocument`** — the parsed file: `type: cast` front matter, a
  `cast: [CastMember]` roster, and an opaque markdown body that is re-emitted
  byte-for-byte.
- **`CastMember`** — `character` (required), `actor?`, `gender?` (`Gender`),
  `language?`, `voicePrompt?` (legacy `voiceDescription:` wire key still
  decodes), `voices: [String: [String]]` (provider → relative paths), and
  `extraKeys` preserving every undeclared key (`bio:`, the reserved
  `appearance:`/`portrait` block) verbatim.
- **`CastMarkdownParser`** / **`CastMarkdownGenerator`** — parse and serialize.
  The generator is the **single writer**: `echada` mutates a `CastDocument`
  value and hands it back; no consumer builds YAML or splices text.

`EchadaCLICore` adds one legacy shim on top: `LegacyProjectCastReader`, which
reads a still-present `cast:` block out of a `PROJECT.md` (via SwiftReparto's
`ProjectCastImporter`) for seeding and verification. It is read-only; the only
code path that ever writes `PROJECT.md`'s cast data is `echada prune cast`,
whose excision splices out exactly the `cast:` line span
(`ProjectCastWriteBack` with an empty roster) and leaves every other byte
intact. Delete the shim at SwiftProyecto 5.0, when `cast:` leaves the
PROJECT.md schema.

---

## Source Layout

### Library (`Sources/SwiftEchada/` -- 4 files)

| File | Types | Role |
|------|-------|------|
| `SwiftEchada.swift` | `SwiftEchada` enum | Module marker + `version` constant |
| `CharacterProfile.swift` | `CharacterProfile`, `CharacterEvidence` | Voice design specification; `gender` is `SwiftReparto.Gender` |
| `CharacterInfo.swift` | `CharacterInfo` | Lightweight extracted character from `.fountain` |
| `CharacterMerger.swift` | `CharacterMerger` | Dedup extracted lists, delegate reconciliation to SwiftReparto's additive merge |

### Executable (`Sources/echada/` -- 1 file)

`EchadaCLI.swift` is a thin `@main` shim; everything else lives in
`EchadaCLICore` so it is testable as a library.

### CLI (`Sources/EchadaCLICore/`)

| Area | Files | Role |
|------|-------|------|
| Entry | `EchadaCLI.swift` | Root command: `cast`, `generate`, `verify`, `prune`, `voice`, `test-voice` (hidden) |
| Pipeline orchestrator | `CastCommand.swift` | Bootstrap PROJECT.md + CAST.md, then cascade the three generate stages |
| Generate stages | `GenerateCommand.swift`, `GenerateCastCommand.swift`, `GeneratePromptCommand.swift`, `GenerateVoxCommand.swift` | Discover roster → write voice prompts → synthesize `.vox`; all read/write CAST.md |
| Migration gates | `VerifyCommand.swift`, `VerifyCastCommand.swift`, `PruneCommand.swift`, `PruneCastCommand.swift` | `verify cast` (read-only divergence report), `prune cast` (gated legacy `cast:` excision) |
| Legacy shim | `LegacyProjectCastReader.swift`, `ProjectCastWriteBack.swift` | Read-only legacy `cast:` decode; surgical `cast:` line-span splice (prune only) |
| Voice generation | `CastVoiceGenerator.swift`, `VoiceDesigner.swift`, `VoiceCommand.swift`, `TestVoiceCommand.swift`, `ReferenceAudioGenerator.swift` | Two-phase Qwen3-TTS pipeline and single-voice commands |
| Prompt synthesis | `VoicePromptSynthesizer.swift`, `DialogueExtractor.swift`, `FoundationModelRetry.swift`, `SourceMaterialLocator.swift` | Foundation-Model voice briefs from screenplay dialogue |
| Data | `AuditionSentence.swift`, `Generated/` | Curated in-language audition sentences; build-time dependency-version table |

### Tests (`Tests/SwiftEchadaTests/` -- 30 files)

Library types, CLI wiring, every generate stage against CAST.md fixtures, the
`verify cast`/`prune cast` gates, migration losslessness (byte-level
PROJECT.md preservation), body preservation, and model-backed integration
tests (gated on TTS-weight presence).

---

## Data Flow

### Cast Pipeline (full flow)

```
PROJECT.md ──[SwiftProyecto: ProjectMarkdownParser]──> episodesDir, filePattern, tts.model
      |                                                          (read-only project config)
      v
.fountain files ──[heuristic CHARACTER-cue scan]──> discovered names
      |
      v
CAST.md ──[SwiftReparto: CastMarkdownParser]──> CastDocument
      |        (seeded from PROJECT.md's legacy cast: block via
      |         LegacyProjectCastReader if CAST.md is absent)
      |
      |── generate cast:    merge discovered names into document.cast
      |── generate prompt:  Foundation Model writes voicePrompt per member
      |── generate vox:     CastVoiceGenerator.generate(cast:)
      |     |
      |     |── Phase A: Candidate Generation ────────────────────
      |     |   Load VoiceDesign 1.7B model (once for all characters)
      |     |   For each CastMember with voicePrompt:
      |     |     1. AuditionSentence.auditionSentence(language:)  [curated, deterministic]
      |     |     2. Qwen3TTSModel.generate(text: sample, voice: prompt)
      |     |     3. AudioConversion.mlxArrayToWAVData() → candidateWAV
      |     |     4. GPU flush (Stream.synchronize + Memory.clearCache)
      |     |   Unload VoiceDesign model
      |     |
      |     |── Phase B: Voice Locking ───────────────────────────
      |     |   Load Base model (0.6b or 1.7b, once for all characters)
      |     |   For each candidate:
      |     |     1. VoiceLockManager.createLock() → VoiceLock
      |     |     2. Open existing VoxFile or create new one
      |     |     3. VoxExporter.addClonePrompt(to:data:modelRepo:)
      |     |     4. VoxExporter.addSampleAudio(to:data:modelRepo:)
      |     |     5. vox.write(to: outputURL)
      |     |   Record path under member.voices["voxalta"]
      |
      v
Updated CAST.md ──[SwiftReparto: CastMarkdownGenerator]──> written to disk
                   (single writer; body re-emitted byte-for-byte;
                    PROJECT.md is never touched)
```

### Migration Flow (legacy `cast:` → CAST.md)

```
generate cast ──> CAST.md exists (seeded verbatim from legacy cast:)
      |
      v
verify cast ────> read-only: membership, field, and .vox-pointer divergences
      |               exit 0 = rosters agree
      v
prune cast ─────> excise the cast: line span from PROJECT.md (only write,
                  gated on CAST.md existing + verify passing, idempotent)
```

### Single Voice Pipeline (`echada voice`)

Same two-phase structure but for one voice, no CAST.md required:

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

---

## Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Library depends only on SwiftReparto | Cast schema without ML/Metal weight; SwiftReparto's leaf status makes cycles impossible |
| SwiftProyecto is CLI-only | The CLI still needs project-level config; the library never did |
| One writer for CAST.md | Only `CastMarkdownGenerator` serializes — prevents the field-by-field re-emission data loss class (#44/#55) |
| Two-phase migration (`verify` → `prune`) | Non-destructive rollout with a human gate; no one-shot "move the data" command |
| Library has no ML deps | Keeps library usable as a pure SPM dependency without Metal/MLX |
| Two-phase vox pipeline | Avoids GPU OOM from loading VoiceDesign + Base simultaneously |
| `SwiftEchada` is an enum | Prevents accidental instantiation; creates module/type name collision (see [gotchas](gotchas.md)) |
| Prompt-based voice gen | Voice descriptions are text strings in CAST.md; `.vox` synthesis needs no LLM |
| `VoxFile` is a class | Mutable container pattern: create/open → add data → write |
