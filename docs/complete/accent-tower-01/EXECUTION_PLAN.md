---
feature_name: OPERATION ACCENT TOWER
starting_point_commit: bd95a2dccae0a3c9abf2f6ad871c4c915e811235
mission_branch: mission/accent-tower/01
iteration: 1
state: completed
---

# EXECUTION_PLAN.md — SwiftEchada: Accent control for cast voice generation

**Repo:** SwiftEchada · **Source:** REQUIREMENTS.md · **Target:** our next minor release version (additive, from current v0.11.0)

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

---

## Mission Scope

Two **independently shippable, independently testable** pieces, both additive to `echada cast`:

1. **Piece 1 — `--accent` directive**: a global per-run accent/delivery directive composed onto each character's selected voice prompt before the VoiceDesign call. No external dependency — ships first.
2. **Piece 2 — per-language prompt selection**: cast each character into a language using that character's language-specific voice prompt (falling back to the base), and fix the castability guard so a member with only localized prompts is not skipped. Depends on SwiftProyecto v3.7.2 — **already pinned** at `Package.swift:65-68`; no bump required.

**Load-bearing constraints** (carry into every implementation sortie):
- VoiceDesign **ignores `instruct:`** and uses the `voice` string as its sole conditioning. Accent direction MUST be composed into the `voice` string, never passed as `instruct:`.
- Phase A prompt construction is the **only lever**; Phase B (`createLock`) is untouched.
- CLI files use **targeted imports** (`import struct SwiftEchada.SampleSentenceGenerator`), never `import SwiftEchada`.
- English default path MUST stay **byte-for-byte unchanged** when neither feature is engaged.
- Build/test via the **Makefile only** (`make build`, `make test`); never `swift build`/`swift test`. Test scheme is `SwiftEchada-Package`. Known pre-existing flaky test: `largeFileTriggersChunking`.

---

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| piece-1-accent | Sources/EchadaCLICore | 1 | 1 | none |
| piece-2-per-language | Sources/EchadaCLICore | 3 | 2 | piece-1-accent |

---

### Sortie 1: Implement `--accent` directive end-to-end (Piece 1)

**Work Unit**: piece-1-accent

**Priority**: 14.0 — highest. Blocks sorties 2, 3, 4 (dependency depth 3); establishes the reused `composeVoicePrompt` foundation (foundation 1); CLI/file-I/O risk 2. `(3×3)+(1×2)+(2×1)+(2×0.5)`.

**Entry criteria**:
- [ ] First sortie — no prerequisites. Working tree clean; `make build` succeeds on the starting commit.

**Tasks**:
1. Add a pure free function `composeVoicePrompt(base: String, accent: String?) -> String` beside `voxLanguageTag` in `Sources/EchadaCLICore/CastVoiceGenerator.swift` (anchor: `:18`). `nil`/empty accent → returns `base` unchanged; non-empty → appends a clearly-delimited accent clause to `base`.
2. Add `private let accent: String?` plus an `init` parameter (default `nil`) to `CastVoiceGenerator`.
3. In the Phase A loop (`CastVoiceGenerator.swift:~238/~247`), pass `composeVoicePrompt(base: selectedPrompt, accent: accent)` as the `voice` argument to the VoiceDesign call (never as `instruct:`).
4. In `CastCommand` (`Sources/EchadaCLICore/CastCommand.swift`): add `@Option var accent: String?` and `func resolvedAccent() -> String?` (trim whitespace; empty/whitespace → `nil`); pass the resolved accent into the `CastVoiceGenerator(...)` init (anchor: `:126`).
5. Print the active accent next to `Languages:` in the run header (`CastCommand.swift:106`) and in the `--dry-run` output block.
6. Add `Tests/SwiftEchadaTests/AccentOptionTests.swift` (swift-testing, mirroring `LanguageOptionTests`) covering acceptance criteria 1–5 below.

**Acceptance criteria covered**:
1. `composeVoicePrompt(base:"X", accent:nil) == "X"`.
2. `composeVoicePrompt(base:"X", accent:"") == "X"`.
3. `composeVoicePrompt(base:"X", accent:"slow drawl")` contains both `"X"` and `"slow drawl"`.
4. `resolvedAccent()`: no flag → `nil`; `"   "` → `nil`; `"  drawl "` → `"drawl"`.
5. `CastCommand.parse(["--accent","..."])` parses and the value reaches `resolvedAccent()`.

**Exit criteria**:
- [ ] `composeVoicePrompt` exists as a free function beside `voxLanguageTag` and is referenced in the Phase A `voice` argument (verify: `grep -n composeVoicePrompt Sources/EchadaCLICore/CastVoiceGenerator.swift` returns the definition and the call site).
- [ ] `CastCommand` declares `@Option var accent: String?` and `resolvedAccent()`, and passes it into the generator init (verify: `grep -n 'resolvedAccent\|accent:' Sources/EchadaCLICore/CastCommand.swift`).
- [ ] `Tests/SwiftEchadaTests/AccentOptionTests.swift` exists with at least 5 `@Test` cases matching criteria 1–5.
- [ ] `make build` succeeds.
- [ ] `make test` is green on scheme `SwiftEchada-Package` (excluding the known-flaky `largeFileTriggersChunking`); all `AccentOptionTests` pass.
- [ ] No `instruct:` is used to carry accent (verify: accent flows only through the `voice` argument).

---

### Sortie 2: Castability decision pure function + tests (Piece 2 foundation)

**Work Unit**: piece-2-per-language

**Priority**: 9.75 — blocks sortie 3 (and 4 transitively) (dependency depth 2); establishes the reused castability function (foundation 1); pure-logic risk 1. `(2×3)+(1×2)+(1×1)+(1.5×0.5)`.

**Entry criteria**:
- [ ] Sortie 1 exit criteria met (`make build`/`make test` green with `--accent` landed).

**Tasks**:
1. Factor the "is this member castable, and for which languages?" decision into a **pure function** sibling to `decideVoxGeneration` in `CastVoiceGenerator.swift`. Given a `CastMember` and the requested languages, it returns the castable languages: castable for language `L` if `member.voice(for: L) != nil` OR `member.voiceDescription` is non-empty. No model required.
2. Add tests to a Piece-2 test file (e.g. `Tests/SwiftEchadaTests/PerLanguagePromptTests.swift`, swift-testing) covering acceptance criteria 6 and 7.

**Acceptance criteria covered**:
6. Member with only `voices["es"]` (no `voiceDescription`), casting `["es"]` → castable for `es`. Member with neither → skipped (empty result).
7. Member with `voiceDescription` only, casting `["es","en"]` → castable for both (helper falls back to base).

**Exit criteria**:
- [ ] A pure castability function (sibling to `decideVoxGeneration`) exists in `CastVoiceGenerator.swift` and is unit-testable without a model.
- [ ] Test file exists with `@Test` cases for criteria 6 and 7; both pass.
- [ ] `make build` succeeds.
- [ ] `make test` is green on scheme `SwiftEchada-Package` (excluding `largeFileTriggersChunking`).

---

### Sortie 3: Wire per-language prompt selection into Phase A + accent composition + tests (Piece 2)

**Work Unit**: piece-2-per-language

**Priority**: 6.0 — blocks sortie 4 (dependency depth 1); integration sortie, no new foundation (foundation 0); Phase A wiring risk 2. `(1×3)+(0×2)+(2×1)+(2×0.5)`.

**Entry criteria**:
- [ ] Sortie 1 exit criteria met (`composeVoicePrompt` available).
- [ ] Sortie 2 exit criteria met (castability function available).

**Tasks**:
1. Replace the Phase A prompt source. Today: `item.member.voiceDescription!` (`CastVoiceGenerator.swift:238`), resolved **once outside** the per-language loop. New: `item.member.voice(for: candidate.language) ?? item.member.voiceDescription`, evaluated **per language inside** the per-language loop (anchor: `:247`/`:300`), so each language gets its own prompt and falls back to base when no localized entry exists.
2. Apply the castability function from Sortie 2 to replace/augment the skip guard at `CastVoiceGenerator.swift:171` so a member with a localized entry in `voices` (e.g. `voices["es"]`) but no `voiceDescription` is NOT skipped.
3. Compose `--accent` onto the **selected** (possibly localized) prompt via `composeVoicePrompt` (criterion 9).
4. Preserve existing per-language candidate failure isolation (anchor: `:278`).
5. Add tests covering acceptance criteria 8 and 9.

**Acceptance criteria covered**:
8. Prompt selection wiring: given a `CastMember` with `voices["es"]` set and a base `voiceDescription`, the prompt chosen for `"es"` is the `es` value and for `"fr"` (absent) is the base — asserted via the same `voice(for:) ?? voiceDescription` selection the generator uses, per language.
9. `--accent` composes onto the **selected** (possibly localized) prompt, not just the base.

**Exit criteria**:
- [ ] Phase A prompt source uses `member.voice(for: candidate.language) ?? member.voiceDescription` evaluated per language inside the per-language loop (verify: `grep -n 'voice(for:' Sources/EchadaCLICore/CastVoiceGenerator.swift` shows the call inside the loop).
- [ ] The skip guard no longer skips a member that has `voices["es"]` but empty/nil `voiceDescription` (uses the Sortie 2 castability function).
- [ ] `--accent` is composed onto the selected prompt (verify: `composeVoicePrompt` call wraps the per-language selection result).
- [ ] Per-language candidate failure isolation is preserved (the `:278` isolation behavior is intact).
- [ ] Test file has `@Test` cases for criteria 8 and 9; both pass.
- [ ] `make build` succeeds.
- [ ] `make test` is green on scheme `SwiftEchada-Package` (excluding `largeFileTriggersChunking`).
- [ ] English default path is byte-for-byte unchanged when no accent and no localized prompt are set (no regression of the default; `voxLanguageTag` "en → default path" equivalence preserved).

---

### Sortie 4: Manual eval matrix gate (HUMAN-IN-THE-LOOP — not fully agent-completable)

**Work Unit**: piece-2-per-language

**Priority**: 2.5 — terminal sortie, blocks nothing (dependency depth 0); no foundation; MLX/Metal + human-judgment risk 2. `(0×3)+(0×2)+(2×1)+(1×0.5)`. Runs last by construction.

> **NOTE**: The payoff ("does it sound right") is a listening test. CI cannot run MLX/Metal, and the quality judgment requires human ears. The agent's automatable portion is generating the matrix clips locally (the dev machine has Metal) and scaffolding the results table in the PR; the **listening verdict is a human sign-off**. This sortie will reach a `PARTIAL`/manual-gate state pending human confirmation — do not mark COMPLETED on agent output alone.

**Entry criteria**:
- [ ] Sortie 3 exit criteria met (per-language selection + accent landed, `make build`/`make test` green).

**Tasks**:
1. Generate the eval matrix audio clips locally: {en, es} × {base prompt, localized prompt} × {no accent, +accent}, for the same character concept used in the spike.
2. Scaffold the results matrix table in the PR description for the human to fill in.
3. Record in the PR: confirmation that (a) localized-es beats base-es (validates Piece 2), (b) +accent shifts within-language delivery (validates Piece 1), (c) the en path is byte-unchanged when no accent/localization set (no regression).

**Exit criteria**:
- [ ] Matrix clips for all {en,es}×{base,localized}×{no-accent,+accent} combinations generated.
- [ ] PR contains the eval matrix table.
- [ ] **Human sign-off recorded in the PR** confirming the three listening outcomes above. (Manual gate — supervisor must not auto-complete.)

---

## Parallelism Structure

**Critical Path**: Sortie 1 → Sortie 2 → Sortie 3 → Sortie 4 (length: 4 sorties — the entire mission)

This mission is an **inherently serial chain**. Sortie 2 depends on Sortie 1; Sortie 3 depends on both 1 and 2; Sortie 4 depends on 3. There are no independent same-layer work units to parallelize — `piece-2-per-language` cannot start until `piece-1-accent` lands, and within piece-2 each sortie consumes the previous one's artifact (`composeVoicePrompt`, then the castability function, then the wired Phase A loop).

**Parallel Execution Groups**:
- **Group 1**: Sortie 1 (supervising agent) — **SUPERVISING AGENT ONLY** (has `make build`/`make test`)
- **Group 2** (depends on Group 1): Sortie 2 (supervising agent) — **SUPERVISING AGENT ONLY** (has build/test)
- **Group 3** (depends on Group 2): Sortie 3 (supervising agent) — **SUPERVISING AGENT ONLY** (has build/test)
- **Group 4** (depends on Group 3): Sortie 4 (supervising agent + human gate) — **SUPERVISING AGENT ONLY** (generates clips, scaffolds PR table; final listening verdict is human sign-off)

**Agent Constraints**:
- **Supervising agent**: Handles all four sorties — every sortie carries a `make build`/`make test` gate, so none is delegable to a no-build sub-agent.
- **Sub-agents (up to 4)**: Not allocated. The only non-build slices (writing the swift-testing files) are too tightly coupled to each sortie's source edits to split off profitably; the round-trip cost of a separate test-authoring sub-agent exceeds the savings on a 4-sortie chain.

**Missed Opportunities**: None actionable. The dependency chain is genuine, not an artifact of conservative layering.

---

## Open Questions

<!-- Consumed by Pass 1 of refine (`refine-blockers`). Each entry MUST be resolved before refinement can proceed past Pass 1. -->

_No blocking open questions identified during breakdown._

<!-- The requirements doc is exceptionally complete: the Piece 2 gate has PASSED (2026-06-12), the SwiftProyecto v3.7.2 dependency is ALREADY PINNED, the real API surface (`voices`, `voice(for:)`, `voiceDescription`) is given explicitly, and exact source anchors are provided. The accent-clause delimiter/wording is intentionally left to the agent — acceptance criterion 3 only requires substring containment, so exit criteria are writable without a decision. Not a blocker. -->

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 2 |
| Total sorties | 4 |
| Open questions | 0 |
| Dependency structure | 2 layers (piece-2 depends on piece-1) |
