# TODO: Optional `--language` for voice casting

**Status:** ✅ **IMPLEMENTED (2026-06-08).** A–F all landed in echada in one pass; `make build` + `make test` green (52 tests, 13 new for the language surface). Remaining work is the manual Spanish smoke test (requires models + an inference host) and the separate Produciesta render-side consumer. See "Implementation notes" at the bottom for what shipped and the one accepted limitation.

**Status (original):** ✅ **FULLY UNBLOCKED — upstream released, do A–E in one pass.** Blocking design decisions resolved by the user 2026-06-08. As of 2026-06-08 the cross-repo dependencies are **released, not just landed**: **vox-format `v0.4.0`** (`EmbeddingEntry.language` + `sampleAudioData(for:language:)` / `clonePromptData(for:language:)` matchers) and **SwiftVoxAlta `v0.13.0`** (`VoiceLockManager.createLock(language:)`, `VoxExporter.addSampleAudio/addClonePrompt(... language:)` writers, language-aware `VoxImporter`). echada's `Package.swift` floors are bumped to match (`SwiftVoxAlta from: "0.13.0"`, `vox-format from: "0.4.0"`). The original "A–D now, E after upstream" split is **obsolete** — the writers Section E consumes already exist in the pinned releases, so all of A–E are implementable now against the bumped pins and should be done in one pass (splitting just touches the same call sites twice).

### Decisions Locked (user, 2026-06-08)
- **Path scheme:** `embeddings/<engine>/<slug>/<lang>/...` (append under existing `embeddings/`). **No `samples/` tree.** Matches vox-format TODO §2.
- **Per-language clone prompts:** YES — each (model, language) gets its OWN clone prompt extracted from same-language reference audio, stored at a `<lang>`-segmented path. Not just preview samples. So the clone-prompt path also gains the `<lang>` segment (revises §E and Decision-log/Open-Q below).
- **SwiftVoxAlta was in scope (now DONE & RELEASED)** (3-repo coordinated effort): its `VoiceLockManager.createLock(language:)`, `VoxExporter` language-aware paths, and `VoxImporter` language-aware read all shipped in **`v0.13.0`**. The cross-repo Section C edit is no longer a blocker — the parameter is in the released API; echada just passes it. See the SwiftVoxAlta `TODO.md`.
- **Produciesta render-side selection** (target `es` + pick the `es` sample/prompt) is handled **separately by the user** — this effort knowingly ships casting data ahead of that consumer.

## Problem statement

`echada` casts `.vox` voice files by running Qwen3-TTS voice-design + clone-prompt
extraction (via SwiftVoxAlta). Every voice-creation inference call **hardcodes
`language: "en"`**, and the reference sample sentence used for clone-prompt
extraction is **English-only**. A clean Spanish (or other non-English) clone
prompt needs a same-language reference sentence; an English reference sentence
spoken by an `es` voice degrades extraction quality.

## Goal

Add an **optional** `--language` parameter to the casting commands and thread it
through to:

- the candidate-audio generation call `qwenModel.generate(... language:)`, and
- the clone-prompt extraction call `createVoiceClonePrompt(... language:)` (today
  pinned to `"en"` inside SwiftVoxAlta's `VoiceLockManager.createLock`),

plus make `SampleSentenceGenerator` language-aware so the reference sentence is in
the requested language. Then write a **language-tagged sample** into the `.vox`.

**Backward compatibility is mandatory:** default stays `en`. With no `--language`
flag, output `.vox` files and PROJECT.md must be byte-for-byte equivalent to today
(English sentence, language-less default sample path).

---

## The hardcoded `"en"` audit (verified)

Three voice-creation sites hardcode `"en"` — all confirmed by grep across the whole
`Sources/` tree (no others found):

| # | File:line | Call | Role |
|---|-----------|------|------|
| 1 | `Sources/EchadaCLICore/CastVoiceGenerator.swift:350` | `qwenModel.generate(... language: "en")` | candidate-audio generation (`cast` path) |
| 2 | `Sources/EchadaCLICore/VoiceCommand.swift:65` | `qwenModel.generate(... language: "en")` | candidate-audio generation (`voice` path) |
| 3 | `Sources/EchadaCLICore/VoiceDesigner.swift:74` | `qwenModel.generate(... language: "en")` | candidate-audio generation (`VoiceDesigner` helper, currently unused by `cast`/`voice` — see note) |

Plus a **fourth, cross-repo** site that is the actual clone-prompt extraction
language and is NOT in this repo:

| # | File:line | Call | Role |
|---|-----------|------|------|
| 4 | `SwiftVoxAlta/Sources/SwiftVoxAlta/VoiceLockManager.swift:92` | `createVoiceClonePrompt(... language: "en")` | clone-prompt extraction (used by BOTH `cast` and `voice` via `VoiceLockManager.createLock`) |

English-only reference sentences (the implicit English assumption):

- `Sources/SwiftEchada/SampleSentenceGenerator.swift:9-32` — all 20 quotes (Dorothy
  Parker / Fran Lebowitz) are English. `randomQuote()` (`:35`) and
  `defaultSentence(for:)` (`:70`) have no language parameter.

Note on site #3: `VoiceDesigner.generateCandidate` is a helper that is **not on the
live `cast`/`voice` code path** today (both commands inline their own
`qwenModel.generate` call — sites #1 and #2). Fix it anyway for consistency, but it
is not load-bearing for the smoke test.

---

## Call chain (CLI → inference), with injection points

```
EchadaCLI (Sources/EchadaCLICore/EchadaCLI.swift:7-17)
  defaultSubcommand: CastCommand
  subcommands: VoiceCommand, CastCommand, TestVoiceCommand

── cast ──────────────────────────────────────────────────────────────────
CastCommand.run() (CastCommand.swift:35)
  → builds CastVoiceGenerator(projectDirectory:forceRegenerate:verbose:ttsModelVariant:)  (:100)
  → generator.generate(cast:)  (:107)
      CastVoiceGenerator.generate(cast:) (CastVoiceGenerator.swift:138)
        Phase A — per member:
          sampleSentence = SampleSentenceGenerator.defaultSentence(for:)   (:227)  ← language-aware here
          generateCandidateWithPrompt(voicePrompt:modelManager:sampleSentence:) (:232)
            → qwenModel.generate(text:voice:language:"en"...)  (:350)  ← INJECT lang #1
        Phase B — per candidate:
          VoiceLockManager.createLock(... sampleSentence:modelRepo:)  (:274)
            → createVoiceClonePrompt(... language:"en")  (VoiceLockManager.swift:92)  ← INJECT lang #4 (cross-repo)
          VoxExporter.addClonePrompt(to:data:modelRepo:)  (:306)
          VoxExporter.addSampleAudio(to:data:modelRepo:)  (:308)  ← language-tagged sample write
          vox.write(to:)  (:309)

── voice ─────────────────────────────────────────────────────────────────
VoiceCommand.run() (VoiceCommand.swift:43)
  sampleSentence = SampleSentenceGenerator.randomQuote()  (:47)  ← language-aware here
  qwenModel.generate(text:voice:language:"en"...)  (:62-67)  ← INJECT lang #2
  VoiceLockManager.createLock(... sampleSentence:modelRepo:)  (:84)
    → createVoiceClonePrompt(... language:"en")  ← INJECT lang #4 (cross-repo)
  VoxExporter.addClonePrompt / addSampleAudio  (:109-110)  ← language-tagged sample write
  vox.write(to:)  (:111)
```

Both `cast` and `voice` create the 0.6b and 1.7b embeddings **across separate runs**,
not in one pass: `ttsModelVariant` selects ONE model per invocation; running again
with the other `--tts-model` opens the existing `.vox` (`VoxFile(contentsOf:)`) and
appends the second model's clone-prompt + sample at its model-specific path
(`CastVoiceGenerator.swift:290-308`, `VoiceCommand.swift:94-110`). So a multi-model
`.vox` is the result of two invocations. **Language is orthogonal to model size** —
a `--language` flag multiplies with `--tts-model`, not within it.

---

## SwiftVoxAlta / mlx plumbing already supports language (good news)

- `Qwen3TTSModel.createVoiceClonePrompt(refAudio:refText:language:)` already takes a
  `language` parameter (default `"auto"`): `mlx-audio-swift/Sources/MLXAudioTTS/Models/Qwen3TTS/Qwen3TTSVoiceClonePrompt.swift:177-181`.
- `qwenModel.generate(... language:)` already takes a language string.
- `VoiceLockManager.generateAudio(... language: String = "en")` already plumbs
  language through generation (`VoiceLockManager.swift:144,197`).

**The only SwiftVoxAlta change needed** was `VoiceLockManager.createLock` — it
previously hardcoded `language: "en"` and had no `language` parameter. ✅ **DONE in
`v0.13.0`**: `createLock(... language: String = "en")` now exists
(`VoiceLockManager.swift:69`) and forwards to `createVoiceClonePrompt(... language:)`
(`:97`). The cross-repo dependency is satisfied by the released pin; echada only needs
to pass `language:` at its two call sites (Section C below).

---

## Checklist of concrete edits

### A. CLI surface — add `--language`

- [ ] **CastCommand** (`Sources/EchadaCLICore/CastCommand.swift`): add
  `@Option(name: .long, help: "BCP-47 language code(s) for the reference sample (default: en). Repeat to cast multiple languages into one .vox.") public var language: [String] = []`
  near the other options (`:30`). Empty array → treat as `["en"]` (preserves default).
  Validate each code is non-empty/lowercased; do NOT hard-restrict the set (Qwen3
  accepts `"auto"` and several languages).
- [ ] Thread `language` into `CastVoiceGenerator(... languages:)` (`:100`). Add a
  `languages: [String]` stored property + init param to `CastVoiceGenerator`
  (`CastVoiceGenerator.swift:103-116`), default `["en"]`.
- [ ] **VoiceCommand** (`Sources/EchadaCLICore/VoiceCommand.swift`): add the same
  `@Option ... language` (single value is fine here — see decision log; or repeatable
  for symmetry). Default `en`.

### B. Thread language to candidate generation

- [ ] `CastVoiceGenerator.generateCandidateWithPrompt` (`:336`): add `language: String`
  param; pass to `qwenModel.generate(... language: language)` replacing `"en"` at `:350`.
  Call site at `:232` passes the loop's current language.
- [ ] `VoiceCommand.run` (`:62-67`): pass `language` (first/only value) replacing `"en"` at `:65`.
- [ ] `VoiceDesigner.generateCandidate` (`:55-88`): add `language: String = "en"` param;
  replace `"en"` at `:74`. (Consistency; not on live path.)

### C. Thread language to clone-prompt extraction

- [x] **SwiftVoxAlta** `VoiceLockManager.createLock`: `language: String = "en"` added and
  forwarded to `createVoiceClonePrompt(... language:)` — ✅ **shipped in `v0.13.0`**.
- [x] echada pin bumped: `Package.swift` `SwiftVoxAlta from: "0.13.0"`.
- [ ] echada call sites: `CastVoiceGenerator.swift:274` and `VoiceCommand.swift:84`
  pass `language:` into `createLock`.

### D. Language-aware sample sentences (LIBRARY target)

- [ ] `Sources/SwiftEchada/SampleSentenceGenerator.swift`: add language-keyed static
  quote sets, e.g. `static let quotesByLanguage: [String: [String]]` with at least
  `"en"` (existing 20) and `"es"` (new Spanish quotes, 15-30 words each).
- [ ] Add `randomQuote(language: String = "en") -> String` and
  `defaultSentence(for:language:) -> String` overloads. Fall back to `en` when the
  requested language is absent (so an unknown `--language fr` still produces audio).
- [ ] Keep existing zero-arg `randomQuote()` / `defaultSentence(for:)` unchanged for
  source compatibility (they delegate to the `en` set).
- [ ] **Library purity check: SAFE.** This is pure data + Foundation. `SwiftEchada`
  imports only `Foundation` (`SampleSentenceGenerator.swift:1`) and the library target
  depends only on SwiftProyecto. Static language-keyed strings add **no** ML/voice
  dependency. Rule preserved.
- [ ] Update call sites to pass language: `CastVoiceGenerator.swift:227`
  (`defaultSentence(for:language:)`) and `VoiceCommand.swift:47`
  (`randomQuote(language:)`).

### E. Write a language-tagged sample into the `.vox` (✅ UNBLOCKED — writers shipped)

- [ ] Replace `VoxExporter.addSampleAudio(to:data:modelRepo:)` calls
  (`CastVoiceGenerator.swift:308`, `VoiceCommand.swift:110`) with the language-aware
  `addSampleAudio(to:data:modelRepo:language:)` — ✅ **available in SwiftVoxAlta
  `v0.13.0`**. The language-less path remains the DEFAULT sample (for `en` / no-flag),
  with per-language samples written at the language-tagged path and lookup falling back
  to the default (`nil`/`"default"` language → language-less path).
- [ ] **DECIDED: per-language clone prompts.** `addClonePrompt` is language-aware too —
  each (model, language) gets its own clone prompt at
  `embeddings/<engine>/<slug>/<lang>/clone-prompt.bin` (default/`en` stays at the
  language-less path). Consume `VoxExporter.addClonePrompt(... language:)` — ✅ **shipped
  in `v0.13.0`**; do NOT poke raw `vox.add(at:)` paths from echada.

### F. Targeted-import rule (compile correctness)

- [ ] Any new CLI code that references library types must use targeted imports:
  `import struct SwiftEchada.SampleSentenceGenerator` (already present at
  `CastVoiceGenerator.swift:9`, `VoiceCommand.swift:9`, `VoiceDesigner.swift:8`).
  Do NOT add `import SwiftEchada` — module/type name collision. New helpers follow suit.

---

## Upstream dependency status (✅ RESOLVED — both released)

The per-language sample/clone-prompt API echada consumes is **shipped and pinned**:

- **vox-format `v0.4.0`** (released 2026-06-08): `EmbeddingEntry.language` (BCP-47,
  optional; `nil` = language-neutral default) + language-aware read matchers
  `sampleAudioData(for:language:)` / `clonePromptData(for:language:)` with
  exact → base-language → default fallback. Floor bumped: `Package.swift` `vox-format from: "0.4.0"`.
- **SwiftVoxAlta `v0.13.0`** (released 2026-06-08): `VoiceLockManager.createLock(... language:)`,
  the language-aware writers `VoxExporter.addSampleAudio(... language:)` /
  `addClonePrompt(... language:)`, and language-aware `VoxImporter` read. Floor bumped:
  `Package.swift` `SwiftVoxAlta from: "0.13.0"`.

**Path scheme (locked & implemented upstream):** the language segment is appended to the
EXISTING path — `embeddings/qwen3-tts/<slug>/sample-audio.wav` (default, == `en`) and
`embeddings/qwen3-tts/<slug>/<lang>/sample-audio.wav` (per-language); the clone prompt
mirrors this (`.../clone-prompt.bin` default, `.../<lang>/clone-prompt.bin` per-language).
No `samples/` tree. `language == nil` or `"default"` resolves to the language-less path.
echada consumes `VoxExporter.addSampleAudio(... language:)` / `addClonePrompt(... language:)`
— it does NOT construct paths itself.

The vox-format manifest already modeled language at the metadata level
(`reference_audio[].language`, `voice.language`) and the docs anticipated the CLI
(`echada cast --project PROJECT.md --provider qwen3-tts --language es`) — that anticipated
feature is now fully backed upstream.

---

## Decision log

1. **Single vs repeatable `--language` flag → REPEATABLE for `cast`, single OK for `voice`.**
   Reasoning: casting N languages into one `.vox` in one run amortizes the expensive
   model load (Phase A loads VoiceDesign once, Phase B loads Base once). With a
   repeatable flag, Phase A can loop languages per member (one `generate` + one sample
   per language) and Phase B can extract one clone-prompt per language — all under a
   single pair of model loads. A single flag would force re-running echada per language,
   reloading multi-GB models each time. `[String]` with empty-default → `["en"]`.
   `voice` is a one-off single-prompt command; a single value is fine, but accept
   repeatable for API symmetry if cheap.

2. **PROJECT.md per-character language vs CLI-only → CLI-only for now.** Reasoning:
   `CastMember` (`SwiftProyecto/.../CastMember.swift:93-140`) has NO language field, and
   `SwiftProyecto/.../TTSConfig.swift:39-40` already carries a project-level
   `languageCode` (BCP-47). A `--language` CLI flag is sufficient for v1 and avoids a
   SwiftProyecto schema change + migration. Keep PROJECT.md changes to ZERO. If a
   project-default is wanted later, fall the flag back to `frontMatter.tts?.languageCode`
   (mirrors how `--tts-model` falls back to `tts.model` at `CastCommand.swift:45-46`) —
   note this as a cheap, optional follow-up, NOT part of v1.

3. **Library purity for sample sentences → SAFE.** Adding `quotesByLanguage` static
   data keeps `SwiftEchada` Foundation-only; no SwiftProyecto/ML dep added. Confirmed.

4. **Clone-prompt language vs generation language.** Both should use the same
   `--language` value. The generation-side `language` shapes the candidate audio; the
   extraction-side `language` (`createVoiceClonePrompt`) tells the tokenizer how to
   align `refText`. Mismatched values would defeat the purpose.

---

## Test / validation plan

Build/test via **Makefile only** (never `swift build`/`swift test`):

- `make build` — compiles library + CLI (`Makefile:23`, runs `resolve` first).
- `make test` — runs the `SwiftEchada-Package` scheme (`Makefile:68`).
- `make lint` (`Makefile:72`), `make integration-test` (`Makefile:86`) as needed.
- Do NOT run them as part of this planning task.

Unit tests to add:

- [ ] `SampleSentenceGenerator.randomQuote(language: "es")` returns a Spanish quote;
  `randomQuote(language: "xx")` falls back to an English quote; zero-arg overloads
  unchanged.
- [ ] CLI parsing: `--language es --language en` yields `["es","en"]`; no flag yields
  `[]` → normalized to `["en"]`.
- [ ] Backward-compat: a `cast`/`voice` run with no `--language` produces the same
  `.vox` archive paths as today (default sample path unchanged).

Manual Spanish smoke test (requires models + a host that can run inference):

1. Make a tiny `PROJECT.md` with one cast member, Spanish `voicePrompt`.
2. `echada cast --project PROJECT.md --tts-model 1.7b --language es --verbose`
   → verbose log shows a Spanish sample sentence and `language: es` going into both
   `generate` and `createVoiceClonePrompt`.
3. Inspect the `.vox` (`vox inspect`): confirm a language-tagged `es` sample exists
   and `reference_audio[].language == "es"`; confirm the default/`en` sample path
   still resolves.
4. Re-run with `--tts-model 0.6b --language es` → second embedding appended to the
   same `.vox` without clobbering the 1.7b data.
5. Control: run with NO `--language` → identical to current `main` output.

---

## Open questions — ALL RESOLVED (2026-06-08)

1. ~~vox-format sample-path contract~~ — **RESOLVED: `embeddings/<engine>/<slug>/<lang>/...`
   append, no `samples/` tree.** Both upstreams now **released** (vox-format `v0.4.0`,
   SwiftVoxAlta `v0.13.0`) and pinned — A–E all proceed now; E is no longer gated.
2. ~~Per-language clone prompt?~~ — **RESOLVED: YES, one clone prompt per (model, language)**,
   stored at a `<lang>`-segmented path. Each language is treated as its own extracted identity.
3. ~~Worth it before Produciesta can render + SELECT it?~~ — **RESOLVED: yes, proceed.** The
   user owns the Produciesta render-side work separately and accepts that casting data is
   produced ahead of that consumer.

---

## Candor: sequencing & accepted risks (decisions made 2026-06-08)

- **Accepted: building ahead of the render-side consumer.** echada produces `.vox` files;
  **Produciesta** renders episode audio and is what SELECTS a per-language
  sample/clone-prompt at render time. Produciesta cannot yet (a) target `es` generation
  or (b) pick the `es` prompt out of the `.vox`. The user owns that work **separately** and
  has accepted that this effort ships casting data ahead of that consumer. Until
  Produciesta catches up, the per-language clone prompts sit in the `.vox` unused — known
  and accepted.
- **Sequencing (three coordinated repos, in dependency order) — steps 1 & 2 DONE:**
  1. ✅ **vox-format `v0.4.0` (released)** — `EmbeddingEntry.language` + language-aware
     `sampleAudioData(for:language:)` / `clonePromptData(for:language:)` matchers.
  2. ✅ **SwiftVoxAlta `v0.13.0` (released)** — `createLock(language:)` (the load-bearing
     quality fix), `VoxExporter.addSampleAudio/addClonePrompt(... language:)` writers, and
     language-aware `VoxImporter` read. echada pins bumped to match.
  3. ⏳ **echada (this) — the only remaining work.** With both upstreams released and the
     `Package.swift` floors bumped (`SwiftVoxAlta 0.13.0`, `vox-format 0.4.0`), all of A–E
     is implementable now in a single pass.
- **The pronunciation win is the whole feature, and it's no longer gated:** language-aware
  sample sentence + threading `language` into `generate` and `createVoiceClonePrompt` (so the
  clone prompt is extracted from same-language audio) + writing the language-tagged sample.
  The earlier "do A–D first, gate E behind upstream" split is obsolete — do A–E together to
  avoid touching the same call sites twice.

---

## Implementation notes (landed 2026-06-08)

**What shipped (A–F):**

- **A — CLI surface.** `CastCommand` gained repeatable `--language [String] = []`
  (`CastCommand.swift`), normalized by `resolvedLanguages()` → empty maps to `["en"]`,
  lowercased, de-duplicated preserving order, empty codes rejected. `VoiceCommand` gained
  single `--language String = "en"`, normalized inline. A `Languages: …` line prints in the
  cast summary.
- **B — generation language.** `CastVoiceGenerator.generateCandidateWithPrompt(... language:)`,
  `VoiceCommand`, and `VoiceDesigner.generateCandidate/generateCandidates(... language:)` all
  forward the code to `qwenModel.generate(... language:)`. No more hardcoded `"en"` in
  `Sources/` (verified by grep).
- **C — clone-prompt extraction language.** Both echada call sites pass `language:` into the
  released `VoiceLockManager.createLock(... language:)`.
- **D — language-aware sentences (library).** `SampleSentenceGenerator` gained `quotesES` (16
  public-domain Spanish quotes: Cervantes + refranes), `quotesByLanguage`, and
  `randomQuote(language:)` / `defaultSentence(for:language:)` with base-language resolution
  (`es-MX` → `es`) and English fallback for unknown codes. Zero-arg overloads unchanged.
  Library stays Foundation-only — purity preserved.
- **E — language-tagged writes.** Cast Phase A now loops languages per member (one candidate +
  sample sentence per language, all under one VoiceDesign load); Phase B extracts one clone
  prompt per (member, language) under one Base load and writes via the released
  `VoxExporter.addClonePrompt/addSampleAudio(... language:)`. `voxLanguageTag(for:)` maps
  `"en"` → `nil` (language-less DEFAULT path, byte-for-byte with pre-language output) and any
  other code → its `<lang>` segment.
- **F — targeted imports.** No new `import SwiftEchada`; existing
  `import struct SwiftEchada.SampleSentenceGenerator` covers the new APIs.

**Multi-language correctness fix:** Phase B now tracks a `writtenThisRun` set of `.vox` paths.
The 2nd+ language for a member (and, under `--force-regenerate`, every language after the
first) opens and appends to the freshly-written bundle instead of recreating it — without this,
`--force-regenerate --language es --language en` would have clobbered `es` when `en` ran.

**Tests:** 13 added (`SampleSentenceGeneratorTests` language cases; `LanguageOptionTests` for
`voxLanguageTag` + `CastCommand.resolvedLanguages()` parsing/normalization). `make test` green,
52 total.

**Accepted limitation (be aware):** the skip decision (`decideVoxGeneration`) is per-(file,
model-variant), NOT per-language. If a `.vox` already contains a given model variant (e.g.
`1.7b` for `en`) and you re-run later with the *same* variant plus a *new* language, the member
is skipped — the new language is NOT appended. This was deliberately left unchanged (the TODO
checklist did not call for a decision-function change, and `VoxFile` has no per-language
support query). **Workaround:** request all desired languages in ONE run, or use
`--force-regenerate` (which re-generates every language for the variant). Within a single run,
all requested languages are generated correctly.
