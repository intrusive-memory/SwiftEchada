---
type: doc
---

# .vox File Creation Pipeline

This document details every step of creating a `.vox` voice file, from input to output.

---

## Overview

The pipeline converts a **text description of a voice** into a **portable voice bundle** (`.vox`) that can be used for TTS synthesis via SwiftVoxAlta/Qwen3-TTS.

```
"A warm female voice with a slight southern accent"
                    |
                    v
            ┌──────────────┐
            │  VoiceDesign  │  Phase A: Generate candidate audio
            │   1.7B Model  │
            └──────┬───────┘
                   │ candidateWAV (24kHz, 16-bit PCM)
                   v
            ┌──────────────┐
            │  Base Model   │  Phase B: Create speaker embedding
            │  (0.6b/1.7b) │
            └──────┬───────┘
                   │ VoiceLock (clone prompt data)
                   v
            ┌──────────────┐
            │   VoxFile     │  Bundle: embedding + sample audio
            │   (.vox)      │
            └──────────────┘
```

---

## Phase A: Candidate Generation

**Model**: VoiceDesign 1.7B (always, regardless of `--tts-model` flag)

**Input**:
- `voice` (String): The voice description prompt
- `text` (String): A sample sentence for the voice to speak

**Steps**:

1. **Load model**: `modelManager.loadModel(.voiceDesign1_7B)` → `Qwen3TTSModel`
2. **Generate audio**:
   ```swift
   qwenModel.generate(
       text: sampleSentence,
       voice: voicePrompt,
       language: "en",
       generationParameters: GenerateParameters(
           maxTokens: 16384,
           temperature: 0.6,
           topP: 0.6,
           repetitionPenalty: 1.5
       )
   )
   ```
   Note: `CastVoiceGenerator` uses default `GenerateParameters()` (no custom values). `VoiceDesigner.generateCandidate()` uses the explicit parameters above.
3. **Convert**: `AudioConversion.mlxArrayToWAVData(audioArray, sampleRate: 24000)` → `Data`
4. **Flush GPU**: `Stream.defaultStream(.gpu).synchronize()` + `Memory.clearCache()`
5. **Unload model**: `modelManager.unloadModel()` (frees VRAM before Phase B)

**Output**: `candidateWAV: Data` (WAV format, 24kHz, 16-bit PCM, mono)

---

## Phase B: Voice Locking

**Model**: Base model, determined by `--tts-model` flag (default `1.7b`)

**Input**:
- `candidateWAV`: The WAV data from Phase A
- `voicePrompt`: Original text description
- `characterName`: Name for the manifest
- `sampleSentence`: Text that was spoken in the candidate audio
- `modelRepo`: `Qwen3TTSModelRepo` (`.base0_6B` or `.base1_7B`)

**Steps**:

1. **Create voice lock**:
   ```swift
   VoiceLockManager.createLock(
       characterName: characterName,
       candidateAudio: candidateWAV,
       designInstruction: voicePrompt,
       modelManager: modelManager,
       sampleSentence: sampleSentence,
       modelRepo: modelRepo
   )
   ```
   Returns: `VoiceLock` with `clonePromptData` (the speaker embedding)

2. **Create or open VoxFile**:
   - If file exists: `VoxFile(contentsOf: url)` (appends new model embeddings)
   - If new: `VoxFile(name: characterName, description: voicePrompt)` with provenance:
     ```swift
     vox.manifest.provenance = VoxManifest.Provenance(
         method: "synthesized",
         engine: "qwen3-tts",
         license: "CC0-1.0",
         notes: "Voice generated from text prompt via echada."
     )
     ```

3. **Add clone prompt**: `VoxExporter.addClonePrompt(to: vox, data: voiceLock.clonePromptData, modelRepo: modelRepo)`
4. **Add sample audio**: `VoxExporter.addSampleAudio(to: vox, data: candidateWAV, modelRepo: modelRepo)`
5. **Write**: `vox.write(to: outputURL)`

**Output**: `.vox` file on disk

---

## Batch Mode (`echada cast`)

When processing multiple cast members, `CastVoiceGenerator` optimizes model loading:

```
Phase A (VoiceDesign 1.7B loaded once)
  ├── Generate candidate for CHARACTER_1
  ├── Generate candidate for CHARACTER_2
  └── Generate candidate for CHARACTER_N
  Unload VoiceDesign

Phase B (Base model loaded once)
  ├── Lock + export CHARACTER_1.vox
  ├── Lock + export CHARACTER_2.vox
  └── Lock + export CHARACTER_N.vox
```

**Skip conditions**:
- No `voicePrompt` on CastMember → skip
- `.vox` file already exists AND `--force-regenerate` not set → skip
- Error during generation → log, skip, continue batch

**File locations**: `voices/<SANITIZED_NAME>.vox`, beside `CAST.md`
- Spaces in character names → underscores
- Path recorded under `voices.voxalta` in **CAST.md** (`CastMember.voices["voxalta"]`),
  relative to CAST.md's directory. The roster write-back goes through
  SwiftReparto's `CastMarkdownGenerator` — PROJECT.md is never touched

---

## Multi-Model Appending

A single `.vox` can hold embeddings for multiple model sizes. Running `echada` twice with different `--tts-model` values appends:

```bash
# First run: generates .vox with 0.6b embedding
echada test-voice --output narrator.vox --tts-model 0.6b

# Second run: opens existing .vox, appends 1.7b embedding
echada test-voice --output narrator.vox --tts-model 1.7b
```

The resulting `.vox` contains:
```
embeddings/qwen3-tts-0.6b-clone-prompt.bin
embeddings/qwen3-tts-1.7b-clone-prompt.bin
audio/qwen3-tts-0.6b-sample.wav
audio/qwen3-tts-1.7b-sample.wav
```

---

## TTS Model Resolution

| Context | Resolution Order |
|---------|-----------------|
| `echada cast` / `echada generate vox` | `--tts-model` flag > `tts.model` in PROJECT.md frontmatter (project-level config — read-only) > `"1.7b"` |
| `echada voice` | `--tts-model` flag > `"1.7b"` |
| `echada test-voice` | `--tts-model` flag > `"1.7b"` |

Supported slugs come from `Qwen3TTSModelRepo.supportedSlugs`: currently `["0.6b", "1.7b"]`.

---

## Sample Sentence Sources

Every audition sentence comes from a curated, in-language pool via
`AuditionSentence.auditionSentence(language:)`.

| Command | Source |
|---------|--------|
| `echada cast` | `AuditionSentence.auditionSentence(language:)` |
| `echada voice` | `AuditionSentence.auditionSentence(language:)` |
| `echada test-voice` | `AuditionSentence.auditionSentence(language: "en")` |

**No Apple Intelligence required.** These sentences were previously generated by
the on-device Foundation Model. That was replaced because generation is the wrong
tool for this job:

- **Reliability** — the model failed requests transiently and sometimes returned a
  fluent sentence in the *wrong* language, aborting real cast runs.
- **Reproducibility** — the audition audio *is* the voice-lock reference, so
  non-deterministic reference text meant the same `voicePrompt` produced a
  different `.vox` embedding on every run.
- **Portability** — it made `generate vox` unusable on CI and on any Mac without
  Apple Intelligence, despite the TTS pipeline having no such requirement.

Selection is deterministic: a given language always yields the same sentence, so
`.vox` generation is reproducible.

**Coverage is total.** Every language the TTS model supports (`TTSLanguage`: zh,
en, de, it, pt, es, ja, ko, fr, ru) has curated sentences, so nothing that can be
synthesized lacks an audition. Regional tags (`es-MX`, `pt-BR`) resolve to their
base language. A language outside that set throws `AuditionSentenceError`, which
names the supported set — adding one is a data edit in `AuditionSentence.pools`.

Voice *prompts* (`generate prompt`) still use the on-device Foundation Model —
writing a voice-design brief from a character's dialogue is genuine generative
work, unlike a fixed reference sentence.
