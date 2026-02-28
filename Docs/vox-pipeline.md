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
- No `voiceDescription` on CastMember → skip
- `.vox` file already exists AND `--force-regenerate` not set → skip
- Error during generation → log, skip, continue batch

**File locations**: `<project-dir>/voices/<SANITIZED_NAME>.vox`
- Spaces in character names → underscores
- Path stored in `CastMember.voices["voxalta"]`

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
| `echada cast` | `--tts-model` flag > `tts.model` in PROJECT.md frontmatter > `"1.7b"` |
| `echada voice` | `--tts-model` flag > `"1.7b"` |
| `echada test-voice` | `--tts-model` flag > `"1.7b"` |

Supported slugs come from `Qwen3TTSModelRepo.supportedSlugs`: currently `["0.6b", "1.7b"]`.

---

## Sample Sentence Sources

| Command | Source |
|---------|--------|
| `echada cast` | `SampleSentenceGenerator.defaultSentence(for: characterName)` |
| `echada voice` | `SampleSentenceGenerator.randomQuote()` |
| `echada test-voice` | `SampleSentenceGenerator.randomQuote()` |
| `VoiceDesigner.generateCandidate()` | `SampleSentenceGenerator.defaultSentence(for: profile.name)` (fallback) |

The pool contains 20 curated quotes (Dorothy Parker + Fran Lebowitz), 15-30 words each.
