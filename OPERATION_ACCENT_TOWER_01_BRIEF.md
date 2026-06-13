---
state: complete
---

# Iteration 01 Brief — OPERATION ACCENT TOWER

**Mission:** Add a global `--accent` delivery directive and per-language voice-prompt selection to `echada cast`, additive to v0.11.0.
**Branch:** `mission/accent-tower/01`
**Starting Point Commit:** `bd95a2d` (Add optional --language for voice casting)
**Sorties Planned:** 4
**Sorties Completed:** 4
**Sorties Failed/Blocked:** 0
**Duration:** Single session. All four sorties succeeded on first attempt (0 retries, 0 BACKOFF, 0 FATAL).
**Outcome:** Complete
**Verdict:** `KEEP` — clean execution: every work unit COMPLETED first-try, zero regressions, human listening sign-off PASS on both features.
**Tests pruned:** 0 (see TEST_CLEANUP_REPORT.md)
**Tests flagged for review:** 0

---

## Section 1: Hard Discoveries

The SwiftEchada code work itself produced **no hard discoveries** — the plan's anchors and the resolved spec held against reality. Every discovery below surfaced during the *post-mission application* of the feature to the `drill-supervisor` podcast, and concerns the surrounding ecosystem, not the mission code.

### 1. The "neutralize" gotcha is real, still required, and unscripted

**What happened:** A `echada cast --language es` `.vox` tags its embeddings `es` (keys `qwen3-tts-1.7b-es-…`, paths `…/1.7b/es/…`, plus a `language` field). Produciesta/diga import language-lessly and the matcher only resolves `language == nil`, so every MAESTRA element failed with `Voice 'MAESTRA' is not loaded`.
**What was built to handle it:** A manual neutralize: extract the `.vox` → strip `language` and the `-es-`/`/es/` segments from manifest keys + file paths → move the embedding files → re-zip. The Spanish clone bytes are unchanged; only the tagging is stripped. After that, episode_01 rendered fully (788 s, 0 failures, GLOSA pauses intact).
**Should we have known this?** Yes — PROJECT.md documented it. What we did *not* know: it is still unscripted (the `vox` CLI 0.1.0 has no retag/edit), and the **deployed** MAESTRA.vox is itself still `es`-tagged (so production must consume it via some other path — worth confirming).
**Carry forward:** Non-English voice regen is **not one-shot** today. The real fix is a `--language` flag on Produciesta/diga's `VoxImporter`, or failing that an `echada cast --neutralize`/`--no-language-tag` flag that emits `language == nil` for the lock embedding while keeping language only in candidate generation. The transform is mechanical and safe to script.

### 2. `echada cast --language` is per-invocation, not per-character

**What happened:** `--language` is repeatable but applies to the whole run, so a two-language cast (MAESTRA es + NARRADOR en) requires **two separate runs** with `--character`.
**Carry forward:** Document the per-character/per-language casting pattern for mixed-language projects; a single cast cannot give two characters different languages.

### 3. `--voices-dir` prepends to PROJECT.md's relative VoxPath

**What happened:** Passing `--voices-dir …/voices` against a PROJECT.md whose VoxPath is already `voices/X.vox` yields `voices/voices/X.vox` → `missing-voice-file`, failing all elements.
**Carry forward:** Pass `--voices-dir <project-root>` (or run from the project dir). Easy footgun for episode rendering.

### 4. Stale SourceKit index after a dependency purge

**What happened:** After the pre-build `/dependency-purge` wiped DerivedData, the editor reported `No such module 'MLXAudioTTS'` on CastVoiceGenerator.swift while `make build` passed cleanly.
**Carry forward:** Treat post-purge SourceKit module errors as index lag, not real failures; ground truth is `make build`.

## Section 2: Process Discoveries

#### What the Agents Did Right
- **4/4 sorties first attempt, zero rework.** Every sortie's commit survived verbatim into the final state. Exact source anchors + machine-verifiable exit criteria meant agents never had to guess.
- **Regression discipline held.** Sortie 3 carried a machine-checkable byte-for-byte en-default assertion; the eval (Sortie 4) re-confirmed it objectively before the human ever listened.

#### What the Agents Did Wrong
- **Nothing material.** The Sortie 4 generation agent's first turn truncated with a non-report ("proceeding well…") — a cosmetic reporting miss; it kept working and delivered a full report later. No wasted work, no bad files.

#### What the Planner Did Wrong
- **Over-conservative model budget hint, in the right direction.** The plan's complexity scoring implied opus for the foundational Sortie 1; sonnet handled all three code sorties first-try. Cost discipline was correct — but note it for calibration: exhaustively-specified sorties run a tier cheaper than the raw score suggests.
- **(Supervisor self-critique, not the planner)** During the post-mission drill-supervisor application I assumed `produciesta cast` renders audio (AGENTS.md's wording implied it). It only *resolves* the cast; `produciesta export` is the renderer. Cost one wasted 323-byte render. **Carry forward:** confirm a CLI subcommand's semantics (`--help`) before committing to a long-running invocation.

## Section 3: Open Decisions

### 1. How to retire the manual neutralize step for non-English voices
**Why it matters:** Until resolved, every non-English voice re-cast needs a hand-edited manifest before Produciesta/diga can import it — fragile and unscripted.
**Options:** (A) `--language` flag on Produciesta/diga `VoxImporter` to resolve language-tagged entries (the documented "proper fix"); (B) `echada cast --neutralize` flag emitting `language == nil` for the lock embedding; (C) a `vox neutralize` subcommand.
**Recommendation:** (A) is the durable fix; (B) makes echada regeneration one-shot in the meantime. User deferred filing this iteration — surfaced here so it isn't lost.

### 2. Confirm how the deployed MAESTRA.vox is consumed in production
**Why it matters:** The deployed voice is `es`-tagged yet drives shipped episodes — so either production uses a different consumption path, or it would hit the same wall under current Produciesta.
**Recommendation:** Spot-check the production episode-gen path before the next drill-supervisor re-cast.

## Section 4: Sortie Accuracy

| Sortie | Task | Model | Attempts | Accurate? | Notes |
|--------|------|-------|----------|-----------|-------|
| 1 | `--accent` directive + `composeVoicePrompt` | sonnet | 1 | ✅ | Foundation; reused verbatim by Sortie 3. 8 tests. |
| 2 | `castableLanguages` pure function | sonnet | 1 | ✅ | Sibling to `decideVoxGeneration`; consumed by Sortie 3. 6→14 cumulative tests. |
| 3 | Per-language selection wired into Phase A | sonnet | 1 | ✅ | Highest regression risk; en-default byte-equivalence preserved + isolation intact. |
| 4 | Eval matrix (manual gate) | sonnet (gen) | 1 | ✅ | Generation automatable; verdict correctly held for human. Both features PASS on listen. |

All four sorties accurate — no commit reverted, no file deleted by a later sortie.

## Section 5: Harvest Summary

The SwiftEchada feature was a clean, correctly-scoped serial chain: exhaustive anchors + machine-verifiable criteria produced 4/4 first-attempt sorties with zero regressions, and the human gate confirmed both features sound. The single most important thing learned changes the *ecosystem*, not this code: a non-English voice produced via `--language` is not yet end-to-end usable because Produciesta/diga still import language-lessly — the manual neutralize step remains the load-bearing, unscripted bottleneck for any downstream consumption. Test cleanup pruned 0 of 2 mission tests (both pure-logic, CI-safe); no systemic test-hygiene issues.

## Section 6: Files

**Preserve (read-only reference for next iteration):**

| File | Branch | Why |
|------|--------|-----|
| `EVAL_MATRIX_ACCENT_TOWER.md` | mission/accent-tower/01 | Records the human listening sign-off + composed voice strings per cell. |
| `EXECUTION_PLAN.md` | mission/accent-tower/01 | The plan; reference for scope and acceptance criteria. |
| `TEST_CLEANUP_REPORT.md` | mission/accent-tower/01 | 0-prune record. |

**Discard (will not exist after rollback):**

| File | Why it's safe to lose |
|------|----------------------|
| `/tmp/drill-regen/` (scratch) | Out-of-repo feasibility scratch (voices, episode_01.m4a, neutralize workspace). Not part of the mission deliverable. |
| `.eval-accent-tower/` (untracked, gitignored) | Eval clips + 118 MB local binary; regenerable. |

## Iteration Metadata

**Starting point commit:** `bd95a2d` (Add optional --language for voice casting)
**Mission branch:** `mission/accent-tower/01`
**Final commit on mission branch:** `ba5ce07` (test-cleanup) — brief commit follows.
**Rollback target:** `bd95a2d`
**Next iteration branch:** `mission/accent-tower/02` (only if a follow-up iteration is needed)

## Rollback Verdict

**Verdict:** `KEEP`

**Reasoning:** All four work units COMPLETED on first attempt with zero retries (Section 4), no regression on the English default path (machine-verified byte-for-byte in Sortie 3 and re-confirmed in Sortie 4), and human listening sign-off PASS on both Piece 1 and Piece 2. Test cleanup removed 0% of mission tests (Section 5). There are no hard discoveries in the mission code itself — every discovery (Section 1) is about the surrounding voice-pipeline ecosystem and is additive follow-up work, not a defect in this branch.

**Recommended action:**
- **KEEP — merge the mission branch.** Open `mission/accent-tower/01` → `development` (per project branching convention).
- Follow-up tickets (non-blocking, deferred by user this iteration): Open Decision #1 (retire the manual neutralize step via Produciesta/diga `--language` or `echada --neutralize`) and Open Decision #2 (confirm production MAESTRA.vox consumption path).
