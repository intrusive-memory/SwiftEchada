---
type: mission-brief
state: completed
---

# Iteration 01 Brief — OPERATION GENERAL MUSTER

**Mission:** Move all generative `echada` steps under a `generate` namespace and repurpose `cast` into the meta-orchestrator that bootstraps `PROJECT.md` and runs the whole pipeline.
**Branch:** `mission/general-muster/01`
**Starting Point Commit:** `d514db0`
**Sorties Planned:** 11
**Sorties Completed:** 11
**Sorties Failed/Blocked:** 0
**Duration:** ~64 min of agent work (11 sorties, 1 parallel pair); 150× relative cost (sonnet ×9, opus ×2)
**Outcome:** Complete
**Verdict:** `KEEP` — all 11 sorties landed first-try with a coherent green final state (132 tests); every hard discovery is a documented follow-up, none broke the foundation.
**Tests pruned:** 0
**Tests flagged for review:** 1 (`ModelBackedGenerationTests` — verified CI-safe, no action)

---

## Section 1: Hard Discoveries

### 1. `generate vox` is transitively Apple-Intelligence-gated

**What happened:** S9 discovered that `CastVoiceGenerator.generate()` sources its audition sentences from the Foundation Model (`FoundationModelSentence.requireAvailable()`). So `generate vox` throws `.appleIntelligenceUnavailable` on any machine without Apple Intelligence — including hosted `macos-26`.
**What was built to handle it:** S9's model-backed vox/full-pipeline tests gate on `SystemLanguageModel.default.isAvailable && TTSWeights.present` (the conjunction), so they skip rather than fail where either model is missing. S11 corrected the CI docs and the `tests.yml` header comment to stop implying the vox path runs on hosted CI.
**Should we have known this?** Yes. Reading `CastVoiceGenerator` before writing OQ-4 would have revealed the vox path's transitive AI dependency. The plan assumed TTS-weight caching alone (R-CI-2) would enable vox tests on hosted CI.
**Carry forward:** The `.vox` generation path cannot be exercised on hosted CI. Full model-path CI coverage (prompt AND vox) requires a self-hosted Apple-Intelligence runner with TTS weights. R-CI-2's practical benefit is limited to keeping the cache warm for that future runner.

### 2. Orchestrator does not thread a discovered ancestor `PROJECT.md` into its stages

**What happened:** S7 found that `CastCommand`'s bootstrap detects an existing project via `ProjectDiscovery().findProjectMd(from:)` (which walks *up* the tree), but each stage (`GenerateCastCommand` et al.) checks `FileManager.fileExists` on the *literal* `--project` path. Running `echada cast` in a subdirectory whose `PROJECT.md` lives in an ancestor → bootstrap correctly leaves the ancestor file, then the cast stage throws `ValidationError` because nothing exists at the literal path.
**What was built to handle it:** Nothing — it's out of scope for every planned sortie. S7/S8/S9 tested *around* it by keeping fixtures in fully isolated temp dirs and asserting the throw-plus-invariants.
**Should we have known this?** Partially. OQ-3 specified ancestor detection but never specified that the discovered path must flow into the stages. The gap is a spec omission, not a surprise from reality.
**Carry forward:** Real bug. Common cases (project at cwd, or none → bootstrap creates it locally) work. Fix by threading the discovered path into the stage commands, or explicitly document that `echada cast` must run from the project directory. **Open decision #1.**

### 3. The SwiftAcervo model CDN's `r2.dev` endpoint is retired

**What happened:** S10 found the vendored `acervo-integration-ci` scripts default to `pub-…​.r2.dev`, which returns HTTP 401 — decommissioned 2026-06-30.
**What was built to handle it:** Left the vendored scripts byte-identical (per skill guidance) and overrode via `ACERVO_CDN_BASE: https://cdn.intrusive-memory.productions/models` at job level. Verified all three model manifests resolve there.
**Should we have known this?** No — the `acervo-cdn-setup` skill's deprecation notice records the retirement, but the vendored default was never updated. This is a stale default in shared tooling.
**Carry forward:** Any repo using the `acervo-integration-ci` vendored scripts must override `ACERVO_CDN_BASE`. Worth fixing the skill's default upstream.

### 4. Strict `ACERVO_OFFLINE=1` breaks SwiftVoxAlta component hydration

**What happened:** SwiftVoxAlta registers its Qwen3-TTS components as bare descriptors (no `files:`), so `ComponentDescriptor.needsHydration` re-triggers a `manifest.json` network fetch every fresh CI process — *before* the cache is checked. Under `ACERVO_OFFLINE=1` that fetch throws `AcervoError.offlineModeActive`, breaking any model-backed test regardless of a warm cache.
**What was built to handle it:** S10 forwards `TEST_RUNNER_ACERVO_OFFLINE=0` so the cheap manifest GET succeeds while multi-GB weights serve from the `actions/cache`-restored directory. S9's `TTSWeights.present` check is a pure filesystem probe that never triggers hydration.
**Should we have known this?** No — this is an interaction between SwiftVoxAlta's descriptor registration and Acervo's offline mode that isn't documented anywhere.
**Carry forward:** Never use strict offline mode with SwiftVoxAlta TTS in CI. Durable fix is upstream: pre-hydrate SwiftVoxAlta's descriptors with explicit `files:` metadata.

### 5. (Preflight) Purge's SwiftProyecto floor-bump conflicts with SwiftAcervo

**What happened:** The pre-build dependency purge bumped the SwiftProyecto floor 4.2.0→4.3.0. That broke `xcodebuild -resolvePackageDependencies` with an unstable-version conflict against SwiftAcervo's transitive SwiftProyecto constraint. S3 reverted it to the committed 4.2.0 to restore a green build.
**What was built to handle it:** Reversion of one line; `.upToNextMajor(from: "4.2.0")` still resolves to the newest SwiftProyecto SwiftAcervo permits (resolved at 4.2.0).
**Should we have known this?** The mechanical floor-bump is a known-risky heuristic; the supervisor flagged the mlx-audio-swift cap up front but did not anticipate the SwiftProyecto/SwiftAcervo conflict.
**Carry forward:** The preflight purge's floor-bump should verify the bumped floor still resolves against transitive constraints before committing, or skip deps that participate in cross-repo version pins.

## Section 2: Process Discoveries

### What the Agents Did Right
- **Explicit per-file git staging** (from S1 onward) kept every commit scoped to exactly its sortie's deliverable — no cross-contamination between concurrent/serial agents.
- **Isolated temp-dir fixtures** (`FileManager.temporaryDirectory` + `defer` cleanup) across S7/S8/S9 — zero hardcoded paths, which is why test-cleanup removed nothing.
- **S9 chose correctness over the plan's premise** — when the plan said ".vox assertions unconditional" but reality made vox AI-gated, S9 gated on both models and documented why, rather than shipping a test that fails on every bare machine.
- **Honest deviation reporting** — every agent surfaced its deviations and any Sources bug it found-but-didn't-fix, which is how discoveries 1–4 reached this brief instead of rotting silently.

### What the Agents Did Wrong
- **S3's initial `git add -A`** swept `EXECUTION_PLAN.md` + `SUPERVISOR_STATE.md` into its feature commit (`8b35bed`). Harmless (they needed tracking; `clean` archives them) but sloppy. Corrected by mandating explicit staging for all subsequent sorties.

### What the Planner Did Wrong
- **S9 exit criteria were internally contradictory** — ".vox assertions unconditional" vs. "make test passes on a machine WITHOUT models (they skip)". The supervisor had to author an authoritative reconciliation in the dispatch. A plan should not ship contradictory acceptance criteria.
- **OQ-4/R-CI-2 rested on an unverified assumption** — that TTS-weight caching would enable vox tests on hosted CI. One read of `CastVoiceGenerator` would have shown the vox path is transitively AI-gated (Discovery #1). Research gap.
- **S5's test-retarget list was incomplete** — it named `CastCommandTests`/`LanguageOptionTests`/`AccentOptionTests` but missed `NonEnglishPassthroughTests`, which also referenced the moved helper. S5 caught and fixed it, but the plan should have grepped for all references.
- **R-HELP-6 was unsatisfiable as written** — it asked for a runtime breadcrumb on old `echada prompt`, but S6's exact-subcommands exit criterion forbids the hidden-subcommand shim that would deliver it, and the default subcommand swallows the token. The two requirements collide. **Open decision #2.**

## Section 3: Open Decisions

### 1. Fix or document the ancestor-`PROJECT.md` orchestrator bug (Discovery #2)?
**Why it matters:** `echada cast` from a subdir with an ancestor project throws instead of running the pipeline. A plausible real-world invocation fails.
**Options:** (A) Thread the discovered path from bootstrap into each stage's `--project`. (B) Document that `echada cast` must run from the project directory. (C) Have stages fall back to `ProjectDiscovery` when the literal path is absent.
**Recommendation:** (A) or (C) — the orchestrator already pays for discovery; it should honor it end-to-end. Small, high-value follow-up.

### 2. Deliver the R-HELP-6 migration breadcrumb (Discovery/§2)?
**Why it matters:** Old `echada prompt` now yields a generic "unexpected argument" error, not a migration hint. Users of the removed command get no guidance at runtime.
**Options:** (A) Accept the generic error; rely on CHANGELOG/README (already documented by S11). (B) Intercept `prompt`/known-old-tokens in the executable entry point and print guidance before ArgumentParser runs. (C) Add a hidden `prompt` shim subcommand (conflicts with the exact-subcommands invariant unless that invariant is relaxed).
**Recommendation:** (B) — cleanest; delivers the breadcrumb without polluting the subcommand set.

### 3. Provision a self-hosted Apple-Intelligence CI runner (Discovery #1)?
**Why it matters:** Neither the Foundation-Model (`prompt`) nor the MLX-TTS (`vox`) paths are exercised on hosted CI. The full pipeline has zero end-to-end CI coverage.
**Options:** (A) Provision a self-hosted `macos-26` runner with Apple Intelligence + cached TTS weights. (B) Accept the gap (status quo per OQ-4) and rely on local/dev-machine runs.
**Recommendation:** (A) eventually, but not urgent — the heuristic-cast and wiring/format paths are fully CI-covered, and the model paths are deterministic given the models.

### 4. Address the pre-existing `FoundationModelSentenceTests.generatesInLanguageSentence` flake?
**Why it matters:** This *pre-mission* test fails cold (on-device model context-length overflow on the "de" case) then passes on rerun. It cost the mission one final-acceptance rerun and will flake in any local/self-hosted run. `test-cleanup` did not touch it (out of mission scope).
**Options:** (A) Shorten/trim the German audition prompt to stay under the context window. (B) Add retry-on-overflow. (C) Accept (it skips on hosted CI anyway).
**Recommendation:** (A) — it's a real, cheap fix and the only source of red in the whole mission.

### 5. GEMINI.md version staleness (trivial)
`GEMINI.md` still says `0.15.0-dev` (outside S11's allowed-edit list). One-line follow-up to sync to `0.16.0-dev`.

## Section 4: Sortie Accuracy

| Sortie | Task | Model | Attempts | Accurate? | Notes |
|--------|------|-------|----------|-----------|-------|
| S3 | `generate cast` | sonnet | 1 | ✓ | Survived intact; sound API fallback. |
| S1 | `generate vox` | sonnet | 1 | ✓ | Verbatim copy, clean. |
| S2 | `generate prompt` | sonnet | 1 | ✓ | Verbatim copy, clean. |
| S4 | `generate` container | sonnet | 1 | ✓ | Wiring verified via built binary. |
| S5 | `cast` orchestrator | opus | 1 | ✓ | Keystone; also caught the missing test retarget. |
| S6 | hard-cut `prompt` | sonnet | 1 | ✓ | Clean cut; defensible breadcrumb call. |
| S10 | CI model-enablement | sonnet | 1 | ✓ | Surfaced 2 infra defects; correct workarounds. |
| S7 | offline cast/bootstrap tests | sonnet | 1 | ✓ | Found the ancestor bug. |
| S8 | wiring/pipeline tests | sonnet | 1 | ✓ | Honest about the un-observable force-cascade seam. |
| S9 | model-backed gated tests | opus | 1 | ✓ | Chose correctness over plan premise; found Discovery #1. |
| S11 | docs + version | sonnet | 1 | ✓ | Absorbed 2 mission-mandated corrections. |

**100% accuracy** — every sortie's output survived into the final state. No commit reverted, no file deleted by a later sortie (the S5 test rename was planned, not a correction).

## Section 5: Harvest Summary

The mission delivered a clean, hard-cut CLI restructure exactly as specified — the `generate` namespace, the `cast` pipeline orchestrator, migrated tests, CI wiring, and docs, all green in one first-try pass per sortie. The single most important thing learned: **the model-backed paths (`prompt` and `vox`) are both Apple-Intelligence-gated and therefore invisible to hosted CI** — the TTS-weight caching effort (R-CI-2), while correct, does not buy vox coverage on hosted runners. The next iteration's plan must treat "does this path transitively require Apple Intelligence?" as a first-class research question before promising CI coverage. Test-cleanup pruned 0 of 26 mission tests and flagged 1 as verified-safe — no systemic test-hygiene issues; the agents wrote hermetic, well-gated tests throughout.

## Section 6: Files

**Preserve (reference for next iteration):**
| File | Branch | Why |
|------|--------|-----|
| `OPERATION_GENERAL_MUSTER_01_BRIEF.md` | mission/general-muster/01 | This brief — carries the 5 open decisions forward. |
| `TEST_CLEANUP_REPORT.md` | mission/general-muster/01 | Confirms 0 removals; CI-hygiene baseline. |

**Discard (safe to lose on any rollback — but verdict is KEEP, so nothing is discarded):**
| File | Why it's safe to lose |
|------|----------------------|
| `SUPERVISOR_STATE.md`, `COMPLETE_SwiftEchada.md` | Supervisor bookkeeping; superseded by this brief. |

## Section 7: Iteration Metadata

**Starting point commit:** `d514db0` (`requirements for command restructure`)
**Mission branch:** `mission/general-muster/01`
**Final commit on mission branch:** `a13d756` (`test-cleanup: 0 removals; report`)
**Rollback target:** `d514db0` (unused — verdict is KEEP)
**Next iteration branch:** `mission/general-muster/02` (only if follow-up work is bundled as a new mission)

## Section 8: Rollback Verdict

**Verdict:** `KEEP`

**Reasoning:** All 5 work units and all 11 sorties reached COMPLETED on the first attempt with zero retries, zero BLOCKED/FATAL states, and a coherent green final state (132 tests, `make build`+`make test` clean). Test-cleanup removed 0% of mission tests (Section 5) — far below the 10% KEEP threshold. The four hard discoveries (Section 1) are real but were each handled correctly in-mission and reduce to documented follow-up tickets, not foundation defects; none required reworking a prior sortie. Even under the "err toward ROLLBACK for early iterations" default, there is no doubt here — the foundation is sound and the delivered surface matches the spec.

**Recommended action:**
- **Merge the mission branch** (`mission/general-muster/01` → `development`), per the project's tiered branch convention.
- Open follow-up tickets for the open decisions: (1) ancestor-`PROJECT.md` orchestrator threading [bug], (2) R-HELP-6 migration breadcrumb via executable entry point, (3) self-hosted AI CI runner [deferred], (4) trim the pre-existing German audition-prompt flake, (5) sync `GEMINI.md` version [trivial].
- No rollback ritual — proceeding to `clean`/archival.
