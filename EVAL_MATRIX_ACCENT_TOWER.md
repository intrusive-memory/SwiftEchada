# EVAL MATRIX — OPERATION ACCENT TOWER

**Status: ✓ SIGNED OFF — human listening verdict recorded 2026-06-12 (Tom Stovall): "yes, this sounds good." Both Piece 1 and Piece 2 PASS.**

Generated: 2026-06-12 by sortie agent on branch `mission/accent-tower/01`
Binary used: `./bin/echada` (mission-branch Debug build, ad-hoc App-Group signed)
TTS model: Qwen3-TTS 1.7B VoiceDesign + Base

---

## What This Eval Tests

Two independently-shippable features landed in Sorties 1–3:

1. **Piece 1 — `--accent` directive**: a global per-run delivery directive composed onto each character's selected voice prompt before the VoiceDesign call. Acceptance criterion: `+accent` cells must audibly sound different from `no accent` cells for the same language/prompt-source combination.

2. **Piece 2 — per-language prompt selection**: when a cast member's `voices` dict contains an entry for the requested language (e.g. `voices["es"]`), the generator selects that localized prompt instead of falling back to the base `voiceDescription`. Acceptance criterion: `localized-es` delivery must sound more natural for Mexican Spanish than `base-es` (which is a deliberately neutral, non-regional prompt).

3. **Regression guard**: the `en / base / no accent` default path must be byte-for-byte unchanged — no feature leakage when neither `--accent` nor any localized prompt is engaged.

---

## Fixtures

**Fixture A** (`/.eval-accent-tower/fixture-a/PROJECT.md`): character EVALUADO with only a base `voicePrompt` ("Neutral adult male narrator, clear and even, no strong regional accent.") and no localized `voices["es"]` entry. Casting `es` exercises the **base-es fallback path** (Piece 2 fallback); casting `en` exercises the **byte-unchanged default path** (regression baseline).

**Fixture B** (`/.eval-accent-tower/fixture-b/PROJECT.md`): same base prompt as Fixture A, PLUS `voices["es"]` set to MAESTRA's full español-neutro-mexicano descriptor (from `drill-supervisor/PROJECT.md`). Casting `es` exercises the **localized-es path** (Piece 2 happy path).

**Accent directive used for all `+accent` cells**: `"slow, deliberate, exaggerated enunciation"`

**Composition format** (from `composeVoicePrompt`): `"<base or localized prompt> — accent/delivery: <accent directive>"`

**Localized prompt mechanism**: The `voices["es"]` key in the PROJECT.md `cast:` block is the per-language prompt field. The generator uses `member.voice(for: language) ?? member.voiceDescription` per-language in Phase A — confirmed working via `[verbose] Language: es — prompt:` output during generation.

---

## Matrix Clips

All clips are `.vox` bundles (VoxFormat) under `.eval-accent-tower/`. Each contains the VoiceDesign candidate WAV (used as sample audio) and the Base-model speaker embedding (clone prompt). Use `diga` or the vox-format inspector to extract the sample audio for listening.

| Cell | Language | Prompt source | Accent | Clip path | Composed voice string (from verbose) | Human verdict |
|------|----------|---------------|--------|-----------|--------------------------------------|---------------|
| 1 | es | base (Fixture A) | none | `.eval-accent-tower/es_base_noaccent.vox` | `Neutral adult male narrator, clear and even, no strong regional accent.` | ✓ approved (2026-06-12) |
| 2 | es | base (Fixture A) | slow, deliberate, exaggerated enunciation | `.eval-accent-tower/es_base_accent.vox` | `Neutral adult male narrator, clear and even, no strong regional accent. — accent/delivery: slow, deliberate, exaggerated enunciation` | ✓ approved (2026-06-12) |
| 3 | es | localized (Fixture B) | none | `.eval-accent-tower/es_localized_noaccent.vox` | `Deep, authoritative native Mexican Spanish male voice — a resonant baritone professor from Mexico City (español neutro mexicano). Pure Mexican pronunciation with absolutely no English or American influence: seseo (no Castilian 'th' — 'c' before e/i and 'z' are a clean Spanish 's'), and yeísmo (the digraph 'll' and the letter 'y' are a soft Spanish 'y' /ʝ/, never an English 'j'). Crisp, pure Spanish vowels, lightly rolled 'r'. Commanding but patient; slightly slow, very clear enunciation for a learner to imitate. Speaks only Spanish.` | ✓ approved (2026-06-12) |
| 4 | es | localized (Fixture B) | slow, deliberate, exaggerated enunciation | `.eval-accent-tower/es_localized_accent.vox` | `Deep, authoritative native Mexican Spanish male voice — a resonant baritone professor from Mexico City (español neutro mexicano). Pure Mexican pronunciation with absolutely no English or American influence: seseo (no Castilian 'th' — 'c' before e/i and 'z' are a clean Spanish 's'), and yeísmo (the digraph 'll' and the letter 'y' are a soft Spanish 'y' /ʝ/, never an English 'j'). Crisp, pure Spanish vowels, lightly rolled 'r'. Commanding but patient; slightly slow, very clear enunciation for a learner to imitate. Speaks only Spanish. — accent/delivery: slow, deliberate, exaggerated enunciation` | ✓ approved (2026-06-12) |
| 5 | en | base (Fixture A) | none | `.eval-accent-tower/en_base_noaccent.vox` | `Neutral adult male narrator, clear and even, no strong regional accent.` | ✓ approved (2026-06-12) |
| 6 | en | base (Fixture A) | slow, deliberate, exaggerated enunciation | `.eval-accent-tower/en_base_accent.vox` | `Neutral adult male narrator, clear and even, no strong regional accent. — accent/delivery: slow, deliberate, exaggerated enunciation` | ✓ approved (2026-06-12) |

---

## Sign-off Questions (HUMAN GATE)

Complete all three before closing Sortie 4. Mark each `[x]` when satisfied.

### Piece 2 — localized-es vs base-es
- [x] **(Piece 2)** Listening to clips 3 vs 1 (same language, same accent, different prompt source): the **localized-es** delivery (clip 3) sounds noticeably more natural for Mexican Spanish than the **base-es** delivery (clip 1). The localized prompt's phonetic guidance (seseo, yeísmo, rolled 'r', measured pacing) is audible in the result. Verdict written in Human verdict column of cells 1 and 3 above.

### Piece 1 — +accent shifts delivery
- [x] **(Piece 1)** Listening to clips 1 vs 2 (es/base) and/or clips 5 vs 6 (en/base): the **+accent** clips sound audibly different from the **no accent** clips in the same row — the "slow, deliberate, exaggerated enunciation" directive is perceptible. Verdict written in Human verdict column of cells 2 and/or 6 above.

### Regression — en/base/no-accent default path unchanged
- [x] **(Regression — MACHINE-CHECKED PASS)** The composed voice string for cell 5 (en / base / no accent) is byte-identical to the raw `voiceDescription`: both equal `"Neutral adult male narrator, clear and even, no strong regional accent."` — no feature leakage on the default path. This was verified programmatically during sortie execution (shell string comparison, exit 0).

---

## How to Listen to the Clips

The `.vox` files are VoxFormat bundles. To extract the sample audio WAV:

```bash
# Using the vox-format CLI (if available):
../vox-format/bin/vox extract --sample .eval-accent-tower/es_localized_noaccent.vox -o /tmp/cell3.wav
open /tmp/cell3.wav

# Or use diga to synthesize a test phrase with the embedded speaker:
../SwiftVoxAlta/bin/diga -v .eval-accent-tower/es_localized_noaccent.vox --model 1.7b "En la ciudad de México, el profesor habla con claridad."
```

Alternatively, the sample audio WAV is embedded at the path `qwen3-tts-1.7b/sample-audio` (language tag `es`) inside each `.vox` zip archive — rename to `.zip` and inspect directly.

---

## Sortie Status

**PARTIAL — HUMAN VERDICT REQUIRED**

The machine-automatable portion of Sortie 4 is complete:
- Binary built and signed (mission-branch, ad-hoc App-Group entitlement)
- All 6 matrix clips generated successfully (no signing/entitlement errors)
- Regression check PASSED (machine-verified)

**What remains**: The human must listen to the 6 clips, fill in the Human verdict column, and check off the two listening sign-off boxes above (Piece 2 and Piece 1). Sortie 4 is NOT complete until those boxes are checked.
