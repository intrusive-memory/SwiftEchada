---
type: supervisor-state
state: completed
---

# SUPERVISOR_STATE.md — OPERATION GENERAL MUSTER

> **Terminology**: A *mission* is the definable scope of work. A *sortie* is an atomic agent task within it. A *work unit* groups sorties.

## Mission Metadata

- Operation: **OPERATION GENERAL MUSTER**
- Iteration: 1
- Starting point commit: `d514db085be549c554b7f2fa3597044cbbd92e42`
- Mission branch: `mission/general-muster/01`
- Max retries: 3
- Pre-build dependency purge: run
- Purge ran at: 2026-07-04 (session start)
- intrusive-memory floors bumped: 1 of 4 (SwiftProyecto 4.2.0→4.3.0; mlx-audio-swift held at 0.8.7 cap; SwiftVoxAlta & vox-format already latest)

## Plan Summary

- Work units: 5
- Total sorties: 11
- Dependency structure: 6 layers (S1–S3 + S10 parallel at Layer 1)
- Dispatch mode: dynamic (Approach B — no explicit template in plan)

## Work Units

| Name | Directory | Sorties | Dependencies |
|------|-----------|---------|-------------|
| WU1 — `generate` leaf commands | Sources/EchadaCLICore/ | S1, S2, S3 | none |
| WU2 — Container + repurpose `cast` | Sources/EchadaCLICore/ | S4, S5, S6 | WU1 |
| WU3 — Tests | Tests/SwiftEchadaTests/ | S7, S8, S9 | WU2 (S9 also WU4) |
| WU4 — CI model-enablement | .github/workflows/, Docs/ | S10 | none (gates S9) |
| WU5 — Documentation | repo root, Docs/ | S11 | WU2 |

## Dispatch Constraint (from plan Pass 4)

Build-gated sorties (S1–S9, S11) each run `make build`/`make test` in the shared working tree → **serialized, one at a time**. Only S10 (CI YAML + docs, no build, disjoint files) runs concurrently.

## Work Unit States

### WU1 — generate leaf commands
- Work unit state: COMPLETED
- Sorties: S3 ✓ (8b35bed), S1 ✓ (3a90b9c), S2 ✓ (5df9b05)
- Last verified: all three Generate*.swift present; build + 106 tests green.

### WU2 — container + repurpose cast
- Work unit state: COMPLETED
- Sorties: S4 ✓ (6ba272b), S5 ✓ (7975058), S6 ✓ (8085f06)
- Last verified: subcommands = {generate, voice, cast, test-voice}; PromptCommand.swift deleted; build + 106 tests green.
- Open finding for brief: R-HELP-6 breadcrumb gap — `echada prompt` gives generic "unexpected argument" (default subcommand swallows it), not a migration hint. Proper fix needs 5th hidden subcommand (violates exact-subcommands criterion) or executable-entry change (out of S6 scope). S11 docs must spell out the migration.

### WU3 — tests
- Work unit state: COMPLETED
- Sorties: S7 ✓ (65e6ad5, +12), S8 ✓ (4a882d8, +11 → 129), S9 ✓ (df368f1, +3 → 132)
- Last verified: 132 tests / 20 suites green; model-backed tests skip gracefully when models absent.

### WU5 — documentation
- Work unit state: COMPLETED
- Sorties: S11 ✓ (d7e378e)
- Last verified: version 0.15.0-dev → 0.16.0-dev; README no longer says "three commands"; CI-coverage overclaims corrected in docs + workflow comment; migration documented in CHANGELOG + README.
- Minor open item for brief: GEMINI.md still says 0.15.0-dev (out of S11's allowed-edit list) — trivial staleness.



### WU4 — CI model-enablement
- Work unit state: COMPLETED
- Current sortie: S10 of {S10}
- Sortie state: COMPLETED
- Sortie type: command
- Model: sonnet
- Complexity score: ~7
- Attempt: 1 of 3
- Last verified: commit 01ec583; grep TEST_RUNNER_ACERVO=4; actionlint exit 0; 5 in-scope files; hosted-CI AI gap documented.
- Notes: Two hard discoveries harvested for the brief (see Decisions Log) — carry finding #2 into S9 dispatch.


## Active Agents

| Work Unit | Sortie | Sortie State | Attempt | Model | Complexity | Task ID | Output File | Dispatched At |
|-----------|--------|-------------|---------|-------|-----------|---------|-------------|---------------|
| ~~WU1~~ | ~~S3~~ | COMPLETED | 1/3 | sonnet | 9 | a0c4dc35 | commit 8b35bed | done |
| ~~WU4~~ | ~~S10~~ | COMPLETED | 1/3 | sonnet | 7 | a4e8788a | commit 01ec583 | done |
| ~~WU1~~ | ~~S1~~ | COMPLETED | 1/3 | sonnet | 6 | a2b4211a | commit 3a90b9c | done |
| ~~WU1~~ | ~~S2~~ | COMPLETED | 1/3 | sonnet | 5 | ae457689 | commit 5df9b05 | done |
| ~~WU2~~ | ~~S4~~ | COMPLETED | 1/3 | sonnet | 9 | a183d54b | commit 6ba272b | done |
| ~~WU2~~ | ~~S5~~ | COMPLETED | 1/3 | opus | 20 | a2fce74c | commit 7975058 | done |
| ~~WU2~~ | ~~S6~~ | COMPLETED | 1/3 | sonnet | 6 | a804446d | commit 8085f06 | done |
| ~~WU3~~ | ~~S7~~ | COMPLETED | 1/3 | sonnet | 7 | a8fb5c7b | commit 65e6ad5 | done (+12 tests) |
| ~~WU3~~ | ~~S8~~ | COMPLETED | 1/3 | sonnet | 6 | a4479e65 | commit 4a882d8 | done (129 tests) |
| ~~WU3~~ | ~~S9~~ | COMPLETED | 1/3 | opus | 15 | a49bb0e4 | commit df368f1 | done (132 tests) |
| WU5 | S11 | RUNNING | 1/3 | sonnet | 8 | a1d49f2d | tasks/a1d49f2d9e3e47d85.output | after WU3 |

## Decisions Log

| Timestamp | Work Unit | Sortie | Decision | Rationale |
|-----------|-----------|--------|----------|-----------|
| session start | — | — | Held mlx-audio-swift floor at 0.8.7 | Latest release 0.10.0 violates SwiftVoxAlta 0.14.0's `<0.9.0` pin; bumping would break resolution. |
| session start | — | — | Bumped SwiftProyecto floor 4.2.0→4.3.0 | Latest published release; same major, plan APIs present. |
| session start | WU1 | S3 | Model: sonnet | New logic but fully specified APIs + machine-verifiable gates; standard complexity. |
| session start | WU4 | S10 | Model: sonnet | CI YAML + acervo cache wiring + branch-protection reasoning; too nuanced for haiku, no build. |
| session start | — | — | Serialize build-gated sorties | Shared working tree + shared DerivedData; concurrent `make build` would race. S10 exempt (disjoint files, no build). |
| S10 done | WU4 | S10 | HARD DISCOVERY: retired r2.dev CDN endpoint (401) | Vendored acervo scripts default to decommissioned host; overrode to cdn.intrusive-memory.productions/models. For brief. |
| S10 done | WU4 | S10 | HARD DISCOVERY: strict ACERVO_OFFLINE breaks hydration | SwiftVoxAlta TTS descriptors lack `files:`; every CI process re-fetches manifest.json before cache check → offline throws. Use OFFLINE=0. Carry to S9. Durable fix upstream in SwiftVoxAlta. |
| S3 done | — | — | Reverted purge's SwiftProyecto 4.3.0 floor-bump | 4.3.0 conflicts with SwiftAcervo's transitive SwiftProyecto constraint → resolve failure. Back to committed 4.2.0; build green. Preflight purge bump was harmful here. |
| S3 done | WU1 | S3 | Used ProjectFrontMatter.mergeCast static fallback | ProjectService has no no-arg init (SwiftData ModelContext required); plan offered this fallback. Non-clobbering preserved via .preserveExisting. |
| S3 done | — | — | Switch remaining agents to explicit git staging | S3's `git add -A` swept mission-control docs into feature commit; risky with concurrent agents. |
| S6 done | WU2 | S6 | FINDING: R-HELP-6 breadcrumb gap | `echada prompt` → generic "unexpected argument" (default `cast` swallows it), no migration hint. Fix needs hidden 5th subcommand (breaks exact-subcommands criterion) or executable-entry change. Deferred; S11 docs to cover migration. For brief. |
| S7 done | WU3→WU2 | S7/S5 | FINDING (real bug): orchestrator doesn't thread discovered ancestor PROJECT.md to stages | `GenerateCastCommand` checks literal `--project` path via FileManager; bootstrap detects ancestor via ProjectDiscovery. Running `echada cast` in a subdir with an ancestor PROJECT.md → bootstrap leaves ancestor, then cast stage throws ValidationError. Out of scope for remaining sorties. Recommend follow-up: thread discovered path into stages. For brief. |
| S9 done | WU3 | S9/S10 | MAJOR FINDING: `generate vox` is transitively Apple-Intelligence-gated → R-CI-2 premise (OQ-4) undercut | CastVoiceGenerator sources audition sentences from Foundation Model, so vox generation throws .appleIntelligenceUnavailable on hosted macos-26. TTS-weights cache (S10) is correct infra but the vox tests it was meant to enable STILL can't run on hosted CI. Vox tests join Foundation-Model tests in skip-on-hosted-CI bucket. Full model-path coverage needs self-hosted AI runner + weights. S9 gate requires BOTH models (correct). S10 CI docs now slightly overclaim → S11 corrects. For brief (KEEP-with-followup). |

## Overall Status

Layer 1 dispatched: S3 (sonnet, build-gated) + S10 (sonnet, CI, concurrent). Awaiting completion.
