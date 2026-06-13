# TODO — Accent tuning for cast voice generation

**SCOPE EXPANDED (combined effort, mission-supervisor-driven).** Originally a single
`--accent` flag in SwiftEchada. Now combined with per-language voice prompts, which
crosses into SwiftProyecto (schema). That makes it 2 repos, sequenced, with an
empirical unknown → supervisor territory. This file is the seed for the mission's
`EXECUTION_PLAN.md`.

## Sortie 0 — SPIKE FIRST (no code, do before anything else)

Validate the load-bearing hypothesis: *does a Spanish voice prompt actually make
VoiceDesign sound more natively Spanish?* If no, the whole per-language-prompt plan
is wrong and we pivot to reference-audio cloning (lever 3).
- [ ] Hand-edit a character's `voiceDescription` in `Fixtures/PROJECT.md` to Spanish.
- [ ] Run signed `echada cast --language es --character <name>` (cast-voices skill).
- [ ] Listen to `voices/<name>.vox` sample vs the English-prompt baseline. Record verdict.
- [ ] GATE: only proceed to the SwiftProyecto schema work if the spike is positive.

## Blocking design question for refine pass

Per-language prompt schema shape on `CastMember` (SwiftProyecto). Recommendation:
keep `voiceDescription` as the base/fallback (back-compat) and add
`voicePrompts: [String: String]?` keyed by BCP-47 base lang. Selection order:
`voicePrompts[lang] ?? voicePrompts[base(lang)] ?? voiceDescription`. `--accent`
then composes onto whichever prompt was selected.

## Cross-repo sequencing

Use the **sibling-libraries** pattern (`toggle-sibling-libraries` skill) for parallel
local dev of SwiftProyecto + SwiftEchada, then release SwiftProyecto, bump the
SwiftEchada dep, flip back to remote-only before tagging.

## Key finding (read first)

Phase A generates the audible `.vox` sample with the **VoiceDesign** model
(`.voiceDesign1_7B`). VoiceDesign **ignores the model's `instruct` parameter** — it
uses the `voice` string as the instruct (`mlx-audio-swift` `Qwen3TTS.swift:524-529`,
doc at `:418-419`/`:434`). Therefore accent control must be **composed into the
`voice` description string**, not passed as `instruct:`. Passing `instruct:` to the
VoiceDesign call would be a no-op.

Mechanism: `effectiveVoice = voiceDescription + accent directive`, passed as `voice`
to `generateCandidateWithPrompt` (`CastVoiceGenerator.swift:390`).

## Scope decision

- **In:** SwiftEchada only. New `--accent` CLI flag on `cast`. One accent directive
  per run, applied to every targeted character's voice prompt.
- **Deferred (Phase 2, NOT this list):** per-character accent + a PROJECT.md
  `tts.instruct`/`tts.accent` default. Both require a **SwiftProyecto** change
  (`TTSConfig` has no such field today, `TTSConfig.swift:32`) + version bump + dep
  coordination. Keep it out of the single-repo increment.
- **Not pursued:** IPA / phoneme injection — Qwen3-TTS has no phoneme front-end
  (BPE tokenizer only, `Qwen3TTS.swift:255-262`). Reference-audio cloning (lever 3)
  is the future high-leverage path and is a separate, supervisor-worthy effort.

## Implementation

- [ ] `CastVoiceGenerator.swift`: add free function
      `func composeVoicePrompt(base: String, accent: String?) -> String`
      (nil/empty accent → returns `base` unchanged). Mirror the `voxLanguageTag`
      free-function style so it's unit-testable without the model.
- [ ] `CastVoiceGenerator`: add `private let accent: String?` + `init` param
      (default `nil`). Thread from `CastCommand`.
- [ ] Phase A loop (`CastVoiceGenerator.swift:~247`): compute
      `let effectiveVoice = composeVoicePrompt(base: voicePrompt, accent: accent)`
      and pass it as `voicePrompt:` into `generateCandidateWithPrompt`.
- [ ] Leave Phase B (`createLock`) untouched — the stored sample audio is the
      Phase A candidate WAV (`:347`), so accent is already baked in. Add a code
      comment noting this so it isn't "fixed" later.
- [ ] `CastCommand.swift`: add `@Option var accent: String?` with help text; add
      `func resolvedAccent() -> String?` (trim whitespace, empty → nil); pass into
      the `CastVoiceGenerator(...)` init (`:126`).
- [ ] Print the active accent in the run header (next to `Languages:`, `:106`) and
      in `--dry-run` output so users can confirm it took.

## Testing

### Automatable (unit — `make test`, scheme `SwiftEchada-Package`)
New `AccentOptionTests` suite, mirroring `LanguageOptionTests`:
- [ ] `composeVoicePrompt(base:"X", accent: nil) == "X"`
- [ ] `composeVoicePrompt(base:"X", accent: "")  == "X"`
- [ ] `composeVoicePrompt(base:"X", accent:"slow drawl")` contains both `"X"` and `"slow drawl"`
- [ ] `resolvedAccent()`: no flag → nil; `"   "` → nil; `"  drawl "` → `"drawl"`
- [ ] `CastCommand.parse(["--accent", "..."])` parses; value reaches `resolvedAccent()`

### NOT automatable — mandatory manual listening eval
The whole point (does the accent actually improve) is a **listening test**, not an
assertion. CI cannot run it (needs MLX models, Metal, multi-GB download). This step
is REQUIRED before the PR is "done", and the A/B result goes in the PR body:
- [ ] English Southern: `echada cast --character <name> --accent "slow Deep South Georgia drawl"`
      on `Fixtures/PROJECT.md`; listen to `voices/<name>.vox` sample vs a no-accent run.
- [ ] Spanish: `echada cast --language es --character <name> --accent "native Mexican Spanish phonology"`;
      confirm it reads less "gringo" than baseline.
- [ ] Record verdict: did composing accent into `voice` move the needle, or does the
      directive get drowned by a long `voiceDescription`? (Known risk — same channel.)

### Build gate
- [ ] `make build` clean.
- [ ] `make test` green (note: `largeFileTriggersChunking` is a pre-existing flaky).

## Risks / known limits
- Accent directive shares the `voice` channel with the speaker identity prompt; a
  long `voiceDescription` may dilute it. Manual eval decides if prompt phrasing
  (prefix vs suffix, explicit "Accent:" label) needs tuning.
- If prompt-only control proves too weak, that's the signal to schedule lever 3
  (reference-audio cloning) — a multi-repo, supervisor-worthy effort, not this list.
</content>
</invoke>
