# REQUIREMENTS — Accent control for cast voice generation

**Repo:** SwiftEchada · **Status:** Draft · **Target:** v0.12.0 (additive, from v0.11.0)

Self-contained, single-repo requirement. Two **independently shippable, independently
testable** pieces. Piece 1 has no external dependency and can ship immediately. Piece 2
consumes a SwiftProyecto feature **already present in the currently-pinned v3.7.2** — no
dependency bump or cross-repo work is required.

## Background (the load-bearing facts)

- Phase A generates the audible `.vox` sample with the **VoiceDesign** model
  (`.voiceDesign1_7B`). VoiceDesign **ignores the model's `instruct` parameter** and uses
  the `voice` string as its sole conditioning (`mlx-audio-swift`
  `Qwen3TTS.swift:524-529`, doc at `:418-419`/`:434`). Therefore accent direction must be
  **composed into the `voice` string**, never passed as `instruct:`.
- Accent is baked into the candidate WAV in Phase A; Phase B (`createLock`) extracts the
  clone prompt from it and stores that same WAV as the sample
  (`CastVoiceGenerator.swift:347`). So **Phase A prompt construction is the only lever**;
  Phase B is untouched.
- The accent spike (`/tmp/accent-spike/`) gates Piece 2 only. Piece 1 is useful regardless.

---

## Piece 1 — `--accent` directive (no external dependency, ship first)

### Goal
Add a global per-run accent/delivery directive to `echada cast`, composed onto each
character's selected voice prompt before the VoiceDesign call.

### Scope
- In: `--accent` option on `CastCommand`; a pure `composeVoicePrompt(base:accent:)` free
  function; threading into `CastVoiceGenerator` Phase A; surfacing the active accent in run
  header + `--dry-run` output.
- Out: per-language prompts (Piece 2); the `voice` subcommand (the user already writes its
  full prompt by hand); any model/SwiftVoxAlta change; IPA; reference audio.

### Design
- `composeVoicePrompt(base: String, accent: String?) -> String` — free function beside
  `voxLanguageTag` in `CastVoiceGenerator.swift`. nil/empty accent → returns `base`
  unchanged. Non-empty → appends a clearly-delimited accent clause to `base`.
- `CastVoiceGenerator` gains `private let accent: String?` + `init` param (default `nil`).
- Phase A loop (`CastVoiceGenerator.swift:~247`): pass
  `composeVoicePrompt(base: selectedPrompt, accent: accent)` as the `voice` argument.
- `CastCommand`: `@Option var accent: String?` + `func resolvedAccent() -> String?`
  (trim whitespace; empty/whitespace → nil); pass into the generator init (`:126`).
- Print the active accent next to `Languages:` (`:106`) and in the `--dry-run` block.

### Acceptance criteria (unit, swift-testing — mirror `LanguageOptionTests`)
New `AccentOptionTests`:
1. `composeVoicePrompt(base:"X", accent:nil) == "X"`.
2. `composeVoicePrompt(base:"X", accent:"") == "X"`.
3. `composeVoicePrompt(base:"X", accent:"slow drawl")` contains both `"X"` and `"slow drawl"`.
4. `resolvedAccent()`: no flag → nil; `"   "` → nil; `"  drawl "` → `"drawl"`.
5. `CastCommand.parse(["--accent","..."])` parses and the value reaches `resolvedAccent()`.

---

## Piece 2 — per-language prompt selection (depends on SwiftProyecto v3.7.2 — already pinned)

### Precondition (gate) — ✅ PASSED (2026-06-12)
Spike confirmed: Spanish prompt "MUCH, MUCH better" than English prompt for Spanish
output (A/B clips, same character concept). Greenlit; reference-audio fallback not needed.

### Dependency — ✅ ALREADY SATISFIED
The per-language voice prompt feature is present in **SwiftProyecto v3.7.2**, which is the
floor already pinned at `Package.swift:65-68` (`SwiftProyecto from: "3.7.2"`). No bump,
no waiting on a future release.

The real API is **not** `voicePrompts` / `voicePrompt(forLanguage:)` (those symbols never
shipped — an earlier draft of this doc guessed at names). The actual surface on
`CastMember` is:
- `voices: [String: String]` — keyed by **language abbreviation** (e.g. `"en"`, `"es"`),
  value is the voice prompt for that language.
- `func voice(for: String) -> String?` — case-insensitive lookup into `voices`.
- `var voiceDescription: String?` — the **base / fallback** prompt.

So the per-language selection is simply **`member.voice(for: language) ?? member.voiceDescription`**.

(Earlier this doc claimed the pin was a stale `from: "0.13.0"` at `Package.swift:71` — that
line is actually **SwiftVoxAlta**, not SwiftProyecto. SwiftProyecto is correctly on 3.x.)
Continue to develop locally via the existing `sibling()` pattern; flip to remote-only before
tagging.

### Goal
When casting a character into a language, use that character's language-specific voice
prompt (falling back to the base prompt) instead of the single English prompt.

### Design
- Replace the Phase A prompt source. Today: `item.member.voiceDescription!`
  (`CastVoiceGenerator.swift:238`), resolved **once outside** the per-language loop. New:
  `item.member.voice(for: candidate.language) ?? item.member.voiceDescription` — evaluated
  **per language** inside the per-language loop (`:247`), so each language gets its own
  prompt and falls back to the base when no localized entry exists. Compose `--accent` onto
  the result (Piece 1).
- **Castability guard fix.** The skip guard checks `voiceDescription` non-empty
  (`CastVoiceGenerator.swift:171`). A member with a localized entry in `voices` (e.g.
  `voices["es"]`) but no `voiceDescription` must NOT be skipped. Factor the "is this member
  castable, and for which languages?" decision into a **pure function** (sibling to
  `decideVoxGeneration`) that returns the castable languages for a member given the
  requested languages — castable for language L if `voice(for: L) != nil` OR
  `voiceDescription` is non-empty — testable without a model.
- Per-language candidate failures already isolate (`:278`); preserve that.

### Acceptance criteria (unit, swift-testing)
6. Castability decision: member with only `voices["es"]` (no `voiceDescription`),
   casting `["es"]` → castable for `es`. Member with neither → skipped.
7. Castability decision: member with `voiceDescription` only, casting `["es","en"]` →
   castable for both (helper falls back to base).
8. Prompt selection wiring: given a `CastMember` with `voices["es"]` set and a base
   `voiceDescription`, the prompt chosen for `"es"` is the `es` value and for `"fr"`
   (absent) is the base — asserted by calling the same `voice(for:) ?? voiceDescription`
   selection the generator uses, per language.
9. `--accent` composes onto the **selected** (possibly localized) prompt, not just the base.

### NOT automatable — mandatory manual eval matrix
The payoff (does it sound right) is a listening test; CI cannot run MLX/Metal. Required
before "done", results recorded in the PR:
- Matrix: {en, es} × {base prompt, localized prompt} × {no accent, +accent}.
- Confirm: localized-es beats base-es (validates Piece 2); +accent shifts within-language
  delivery (validates Piece 1); en path is byte-unchanged when no accent/localization set
  (no regression of the default).

---

## Cross-cutting gates & notes

- `make build` clean; `make test` green on scheme **`SwiftEchada-Package`** (never
  `swift build`/`swift test`). Known pre-existing flaky: `largeFileTriggersChunking`.
- Library/CLI import discipline holds: CLI files use targeted imports
  (`import struct SwiftEchada.SampleSentenceGenerator`), never `import SwiftEchada`.
- `--accent` and per-language selection are orthogonal; Piece 1 must not regress when
  Piece 2 is absent, and the English default path must stay byte-for-byte unchanged when
  neither feature is engaged (preserves `voxLanguageTag` "en → default path" equivalence).

## Sequencing

1. Ship **Piece 1** (`--accent`) — no dependency, immediate value, fully unit-tested.
2. Ship **Piece 2** against the already-pinned **v3.7.2** — no dependency bump needed.
   Wire the `voice(for:) ?? voiceDescription` selection, fix the castability guard, run the
   eval matrix.
</content>
