---
type: execution-plan
feature_name: OPERATION GENERAL MUSTER
starting_point_commit: d514db085be549c554b7f2fa3597044cbbd92e42
mission_branch: mission/general-muster/01
iteration: 1
---

# EXECUTION_PLAN.md — `echada` CLI restructure: `generate` subcommands + `cast` meta-pipeline

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

---

## Mission Summary

Restructure the `echada` CLI so all generative steps live under a new `echada generate`
namespace (`generate cast` / `generate prompt` / `generate vox`) and repurpose the
top-level `cast` command into a meta-orchestrator that bootstraps `PROJECT.md` and runs
the whole pipeline. This is a **breaking change** (hard-cut, no back-compat alias — see
requirements D2). Deliverables span CLI code, first-class `--help` text, migrated + new
tests, CI model-enablement, and documentation.

**Source of truth:** [REQUIREMENTS.md](REQUIREMENTS.md).
**Build/test:** always via the Makefile (`make build`, `make test`) — never `swift build`/`swift test`.
Test scheme is `SwiftEchada-Package`. All new CLI logic lives in the **`EchadaCLICore`** target;
the `SwiftEchada` library still depends only on SwiftProyecto.

**Confirmed SwiftProyecto API** (verified present in `../SwiftProyecto`):
`CastExtractor().extractCast(from:) -> [String]`,
`ProjectService.analyzeForGeneration(at:) -> ProjectAnalysis?`
(fields: `inferredTitle`, `episodePattern`, `detectedLanguages`, `extractedCast`),
`ProjectService().mergeCastLists(discovered:existing:)`,
`ProjectFrontMatter.mergeCast(_:_:strategy:)`, `ProjectFrontMatter.withCast(_:)`,
`ProjectDiscovery().findProjectMd(from:)`,
`ProjectMarkdownParser().parse(fileURL:)` / `.generate(frontMatter:body:)` / `.write(frontMatter:body:to:)`,
plus the existing CLI-local `SourceMaterialLocator`, `DialogueExtractor`,
`VoicePromptSynthesizer`, `CastVoiceGenerator`.

---

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| WU1 — `generate` leaf commands | `Sources/EchadaCLICore/` | 3 (S1–S3) | 1 | none |
| WU2 — Container + repurpose `cast` | `Sources/EchadaCLICore/` | 3 (S4–S6) | 2–4 | WU1 |
| WU3 — Tests | `Tests/SwiftEchadaTests/` | 3 (S7–S9) | 5 | WU2 (S9 also WU4) |
| WU4 — CI model-enablement | `.github/workflows/`, `Docs/` | 1 (S10) | 1 | none (gates S9 execution) |
| WU5 — Documentation | repo root, `Docs/` | 1 (S11) | 6 | WU2 |

**Dependency layers (execution gating):**
- **Layer 1:** S1, S2, S3, S10 (parallelizable — S1/S2 are verbatim moves, S3 is new logic, S10 is CI/infra)
- **Layer 2:** S4
- **Layer 3:** S5
- **Layer 4:** S6
- **Layer 5:** S7, S8, S9
- **Layer 6:** S11

---

## Prioritization (Pass 3)

Composite priority = `(dep_depth × 3) + (foundation × 2) + (risk × 1) + (complexity × 0.5)`.
Higher = execute earlier. Numeric sortie order already honors dependency layers, so **no renumbering** was needed; priority governs **dispatch order within a layer** (all intra-layer sorties are otherwise parallelizable).

| Sortie | Dep depth | Foundation | Risk | Complexity | **Priority** | Layer | Within-layer rank |
|--------|-----------|-----------|------|-----------|--------------|-------|-------------------|
| S3 `generate cast` | 7 | 1 | 2 | 2.0 | **26.0** | 1 | 1st |
| S1 `generate vox` | 7 | 1 | 1 | 1.7 | **24.9** | 1 | 2nd |
| S2 `generate prompt` | 7 | 1 | 1 | 1.5 | **24.8** | 1 | 3rd |
| S4 `generate` container | 6 | 1 | 1 | 1.7 | **21.9** | 2 | — |
| S5 `cast` orchestrator | 5 | 1 | 2 | 2.0 | **20.0** | 3 | — |
| S6 hard-cut removal | 3 | 1 | 1 | 1.7 | **12.9** | 4 | — |
| S10 CI enablement | 1 | 0 | 3 | 2.0 | **7.0** | 1 | 4th (parallel, no build) |
| S9 model-backed tests | 0 | 0 | 3 | 2.0 | **4.0** | 5 | 1st |
| S7 offline cast tests | 0 | 0 | 2 | 1.3 | **2.7** | 5 | 2nd |
| S11 docs + version | 0 | 0 | 1 | 2.0 | **2.0** | 6 | — |
| S8 wiring/help tests | 0 | 0 | 1 | 1.7 | **1.9** | 5 | 3rd |

**Recommended within-layer dispatch order**: Layer 1 → S3, S1, S2 (S10 in parallel); Layer 5 → S9, S7, S8. Cross-layer order is fixed by the dependency gating above.

---

## Parallelism Structure (Pass 4)

**Critical Path**: S3 → S4 → S5 → S6 → S9 (length: **5 sorties**). S11 also hangs off S6 at the same depth.

**Load-bearing constraint**: this is a build-gated Swift CLI. Sorties S1–S6, S7, S8, S9, and S11 each carry a `make build`/`make test` exit gate, which per the parallelism rule makes them **SUPERVISING AGENT ONLY**. Only S10 (CI YAML — verified with `actionlint`, no `swift build`) is genuine sub-agent work. Real-world parallelism for this mission is therefore modest — the honest ceiling is ~2 concurrent agents, not 4.

**Parallel Execution Groups**:
- **Group 1** (Layer 1):
  - S3, S1, S2 (Agent 1 — **SUPERVISING AGENT ONLY**, each has `make build`/`make test`) — dispatched sequentially in priority order.
  - S10 (Agent 2 — **NO BUILD**, CI YAML + `actionlint` only) — runs concurrently with Group 1.
- **Group 2** (sequential, depends on Group 1): S4 → S5 → S6 (Agent 1 — **SUPERVISING AGENT ONLY**, chain of build gates; cannot be parallelized — each depends on the prior).
- **Group 3** (Layer 5, depends on S6; S9 also depends on S10):
  - S9, S7, S8 (Agent 1 — **SUPERVISING AGENT ONLY**, each has `make test`). Test *authoring* for S7/S8 may be drafted by a sub-agent, but the `make test` verification gate is supervisor-run.
- **Group 4** (Layer 6): S11 (Agent 1 — **SUPERVISING AGENT ONLY**, `make build`/`make test` gate).

**Agent Constraints**:
- **Supervising agent**: all sorties with build/compile/test steps (S1–S9, S11).
- **Sub-agents (≤4, only 1 usefully employed here)**: S10 (CI/infra, no Swift build). S7/S8 test drafting is delegable but gated by supervisor verification.

**Missed Opportunities**: none material — the build-gate chain S4→S5→S6 is inherently sequential (each mutates the root command surface the next depends on), and Layer-5 test sorties share the `make test` gate. The only true parallel win is running S10 alongside Layer 1.

---

## Sortie Definitions

### Sortie 1: Create `generate vox` command (`GenerateVoxCommand`)

**Entry criteria**:
- [ ] First sortie — no prerequisites. `make build` is green on the current branch.

**Tasks**:
1. Create `Sources/EchadaCLICore/GenerateVoxCommand.swift` defining `public struct GenerateVoxCommand: AsyncParsableCommand` with `commandName: "vox"`.
2. Copy the body of `CastCommand` **verbatim** into it — the `run()` logic, the `resolvedAccent()` and `resolvedLanguages()` helpers, and every flag/option (`--project`, `--force-regenerate`, `--dry-run`, `--verbose`, `--tts-model`, `--character`, `--language` (repeatable), `--accent`). Do NOT modify or delete the existing `CastCommand` yet (kept green as the current default).
3. Add a non-empty `discussion:` to the configuration (R-HELP-1) stating: consumes each member's `voicePrompt`, produces `.vox` under `voices.voxalta` in `PROJECT.md`, idempotency = skips members whose `.vox` already holds the requested variant unless `--force-regenerate`. End the `discussion` with the worked example `echada generate vox --language es --language en` (R-HELP-4).
4. Confirm every `@Flag`/`@Option` carries a `help:` string (R-HELP-5).

**Exit criteria**:
- [ ] File `Sources/EchadaCLICore/GenerateVoxCommand.swift` exists and defines `GenerateVoxCommand`.
- [ ] `GenerateVoxCommand.configuration.commandName == "vox"` and both `.abstract` and `.discussion` are non-empty.
- [ ] `make build` succeeds.
- [ ] `make test` still compiles and passes (existing `CastCommand` untouched).

### Sortie 2: Create `generate prompt` command (`GeneratePromptCommand`)

**Entry criteria**:
- [ ] First sortie — no prerequisites. `make build` is green.

**Tasks**:
1. Create `Sources/EchadaCLICore/GeneratePromptCommand.swift` defining `public struct GeneratePromptCommand: AsyncParsableCommand` with `commandName: "prompt"`.
2. Copy the body of `PromptCommand` **verbatim** (same `run()`, same flags: `--project`, `--character`, `--force`, `--dry-run`, `--verbose`). Leave the existing `PromptCommand` in place for now.
3. Add a non-empty `discussion:` (R-HELP-1): consumes the screenplay source + each member's dialogue, produces a `voicePrompt` per member via the on-device Foundation Model, idempotency = fills empty `voicePrompt` only; `--force` regenerates all. End with the worked example `echada generate prompt --character ALICE --force` (R-HELP-4).
4. Ensure every flag has a `help:` string (R-HELP-5).

**Exit criteria**:
- [ ] File `Sources/EchadaCLICore/GeneratePromptCommand.swift` exists and defines `GeneratePromptCommand`.
- [ ] `.commandName == "prompt"`, `.abstract` and `.discussion` both non-empty.
- [ ] `make build` succeeds and `make test` still passes.

### Sortie 3: Create `generate cast` command (`GenerateCastCommand`) — NEW logic

**Entry criteria**:
- [ ] First sortie — no prerequisites. `make build` is green.

**Tasks**:
1. Create `Sources/EchadaCLICore/GenerateCastCommand.swift` defining `public struct GenerateCastCommand: AsyncParsableCommand` with `commandName: "cast"`. Flags: `--project` (default `PROJECT.md`), `--force`, `--dry-run`, `--verbose` — each with a `help:` string.
2. Locate scripts with the existing `SourceMaterialLocator.episodeFiles(projectDirectory:frontMatter:)` (consistent with `generate prompt`); error cleanly when no scripts are found.
3. Extract character names heuristically (NO LLM/ML): read each script and call `CastExtractor().extractCast(from: fountainText)`, union across scripts, sort + de-duplicate.
4. Map `[String]` → `[CastMember]` (character only; `actor`/`gender`/`voices`/`voicePrompt`/`language` left unset).
5. Merge into any existing cast **without clobbering** downstream fields: use `ProjectService().mergeCastLists(discovered:existing:)` (or `ProjectFrontMatter.mergeCast(_:_:strategy:)`), then `ProjectFrontMatter.withCast(...)`. `--force` overwrites existing entries; default merges/adds only newly-appearing characters. `--dry-run` prints discovered characters and writes nothing.
6. Write the updated `cast:` block via `ProjectMarkdownParser().write(frontMatter:body:to:)`.
7. Add a non-empty `discussion:` (R-HELP-1): consumes episode/screenplay files, produces a merged `cast:` list in `PROJECT.md`, idempotency = adds only new characters unless `--force`. End with the worked example `echada generate cast --project PROJECT.md` (R-HELP-4). **Heuristic-only in v1** (resolved OQ-1): character names only; `gender`/`language`/`description` left empty. LLM enrichment is deferred behind a future `--enrich` flag — no LLM/ML dependency in this sortie.

**Exit criteria**:
- [ ] File `Sources/EchadaCLICore/GenerateCastCommand.swift` exists and defines `GenerateCastCommand` (`commandName == "cast"`).
- [ ] `.abstract` and `.discussion` are non-empty; every flag has a `help:` string.
- [ ] `make build` succeeds.
- [ ] `make test` still compiles and passes (new command not yet wired; existing suite unaffected).

### Sortie 4: `generate` container command + root wiring

**Entry criteria**:
- [ ] S1, S2, S3 complete: `GenerateVoxCommand`, `GeneratePromptCommand`, `GenerateCastCommand` all exist and `make build` is green.

**Tasks**:
1. Create `Sources/EchadaCLICore/GenerateCommand.swift` defining `public struct GenerateCommand: AsyncParsableCommand` with `commandName: "generate"`, `subcommands: [GenerateCastCommand.self, GeneratePromptCommand.self, GenerateVoxCommand.self]`, and **no `defaultSubcommand`** (running `echada generate` prints help — R-HELP-3).
2. Give `GenerateCommand` a non-empty `abstract` and `discussion` (R-HELP-1); the abstract must make it discoverable as a container of the three generative stages.
3. Wire `GenerateCommand.self` into `EchadaCLI.configuration.subcommands` (add alongside the existing `VoiceCommand`, `CastCommand`, `PromptCommand`, `TestVoiceCommand`). Do NOT change `defaultSubcommand` yet; leave old `cast`/`prompt` reachable (transient duplicate state is acceptable and keeps the build green).

**Exit criteria**:
- [ ] `EchadaCLI.configuration.subcommands` contains `GenerateCommand.self`.
- [ ] `GenerateCommand.configuration.defaultSubcommand == nil` and its subcommands are exactly `{cast, prompt, vox}`.
- [ ] `make build` succeeds; a `GenerateCommand.parseAsRoot(["--help"])` render (or `echada generate --help`) lists `cast`, `prompt`, and `vox`.

### Sortie 5: Repurpose `cast` into the meta-orchestrator + root pipeline `discussion`

**Entry criteria**:
- [ ] S4 complete: `generate` container wired into root; `make build` green.

**Tasks**:
1. Rewrite `Sources/EchadaCLICore/CastCommand.swift` so `CastCommand` becomes the pipeline orchestrator (keep the type name `CastCommand` so it can remain the default subcommand). Its `run()`:
   a. **Ensure `PROJECT.md`.** If `--project` (default `PROJECT.md`) is missing, infer scaffolding without an LLM via `ProjectService.analyzeForGeneration(at:)` (`inferredTitle`, `episodePattern`, `detectedLanguages`, `extractedCast`), build a `ProjectFrontMatter` (`type`, `title`, `author = NSFullUserName()`, `created = now`, `episodesDir`, `filePattern`), and write it with `ProjectMarkdownParser().write(frontMatter:body:to:)`. Detect an existing project with `ProjectDiscovery().findProjectMd(from:)` and leave it in place (resolved OQ-3: infer automatically, no flags/prompt; inferred fields are freely editable afterward).
   b. Run the three stages in order by invoking the same logic as `generate cast` → `generate prompt` → `generate vox`, each skipping already-completed work so re-running only fills gaps.
2. Flag surface (superset that fans out to stages): at minimum `--project`, `--character`, `--tts-model`, `--language` (repeatable), `--accent`, `--dry-run`, `--verbose`, plus a single cascading `--force` mapped to each stage's force flag (resolved OQ-2: single cascading `--force`; per-stage control remains available via the standalone `generate <stage>` subcommands). Every flag has a `help:` string; cross-stage flags state which stage they forward to (R-HELP-5, e.g. `--accent` → the vox stage).
3. Add a non-empty `discussion:` to `CastCommand` and a non-empty root `discussion:` on `EchadaCLI` documenting the `PROJECT.md → cast → prompt → vox` flow and that bare `echada` (default `cast`) runs the whole pipeline (R-HELP-2). End `CastCommand.discussion` with the worked example `echada cast` (R-HELP-4).
4. Keep `defaultSubcommand: CastCommand.self` on the root (now the meta command).
5. **Build-integrity: retarget the tests broken by this rewrite.** In `Tests/SwiftEchadaTests/`, retarget `CastCommandTests.swift` → `GenerateVoxCommandTests` (rename file/suite, `CastCommand.parse` → `GenerateVoxCommand.parse`), and retarget `LanguageOptionTests.swift` / `AccentOptionTests.swift` `CastCommand.parse(...)` / `resolvedLanguages()` / `resolvedAccent()` calls to `GenerateVoxCommand`. Keep the same assertions (flag surface unchanged). This keeps `make test` compiling.

**Exit criteria**:
- [ ] `CastCommand.run()` bootstraps `PROJECT.md` when absent and invokes cast→prompt→vox in order.
- [ ] `EchadaCLI.configuration.defaultSubcommand == CastCommand.self` and `EchadaCLI.discussion` mentions the pipeline (`prompt` and `vox` both named).
- [ ] `CastCommand.configuration.discussion` is non-empty and includes a cascading `--force`.
- [ ] `make build` succeeds and `make test` compiles and passes (migrated vox tests green; model-gated tests may skip locally).

### Sortie 6: Hard-cut removal of standalone `prompt` + deprecation breadcrumbs

**Entry criteria**:
- [ ] S5 complete: `cast` is the meta orchestrator; `make build`/`make test` green.

**Tasks**:
1. Remove the standalone `PromptCommand` from `EchadaCLI.configuration.subcommands` (hard-cut per D2). Delete `Sources/EchadaCLICore/PromptCommand.swift` (its logic now lives in `GeneratePromptCommand`), or unwire it if any type is still referenced.
2. Ensure the removed usages fail with a clear breadcrumb naming the replacement (R-HELP-6): invoking the old `echada prompt` path points to `echada generate prompt`; the old `.vox`-only `echada cast` flag combination points to `echada generate vox`. Because ArgumentParser rejects unknown subcommands automatically, add an explicit stderr breadcrumb only where the message would otherwise be unhelpful.
3. Confirm `voice` and `test-voice` remain wired and unchanged (`test-voice` stays `shouldDisplay: false`).

**Exit criteria**:
- [ ] `EchadaCLI.configuration.subcommands` = `{generate, voice, cast, test-voice}` (no standalone `prompt`).
- [ ] `Sources/EchadaCLICore/PromptCommand.swift` no longer referenced by the root; `make build` succeeds.
- [ ] `echada generate prompt`, `echada generate cast`, `echada generate vox`, `echada voice`, and `echada cast` all resolve; `make test` passes.

### Sortie 7: Offline unit tests — `generate cast` (R-TEST-1) + `PROJECT.md` bootstrap (R-TEST-2)

**Entry criteria**:
- [ ] S3 and S5 complete (`GenerateCastCommand` + `cast` bootstrap logic exist); `make test` green.

**Tasks**:
1. Add `Tests/SwiftEchadaTests/GenerateCastCommandTests.swift` (swift-testing, `@testable import EchadaCLICore`) covering, against fixture Fountain text: names discovered + sorted/unique; merge into an existing cast **without clobbering** `actor`/`voicePrompt`/`voices`/`language`; `--force` overwrites; `--dry-run` writes nothing; empty/no-scripts path errors cleanly.
2. Add bootstrap tests (R-TEST-2): given a temp dir with episode files and **no** `PROJECT.md`, running the `cast` bootstrap creates a `PROJECT.md` with inferred `title`, `episodesDir`, `filePattern`; given an existing one, it is detected (`ProjectDiscovery.findProjectMd`) and left in place.
3. All tests must run fully offline (no model calls).

**Exit criteria**:
- [ ] `GenerateCastCommandTests` exists and asserts discovery, non-clobbering merge, `--force`, `--dry-run`, and empty-path error.
- [ ] Bootstrap tests assert `PROJECT.md` creation fields and detection-of-existing.
- [ ] `make test` passes with these tests running (not skipped) on a stock machine.

### Sortie 8: Wiring/help tests (R-TEST-3) + orchestrator dry-run tests (`CastPipelineTests`)

**Entry criteria**:
- [ ] S6 complete: final command surface locked; `make test` green.

**Tasks**:
1. Add wiring/help tests (R-TEST-3, all offline): `EchadaCLI.configuration.defaultSubcommand` is `CastCommand`; `.subcommands` contains `generate` and `voice`; `GenerateCommand`'s subcommands are exactly `cast`/`prompt`/`vox` with no default; each command's `.abstract` and `.discussion` are non-empty and mention their inputs/outputs; rendering `--help` for `generate` and each leaf contains the command name + non-empty discussion (guards doc drift).
2. Add a thin wiring test that `GeneratePromptCommand` parses (`GeneratePromptCommand.parse([...])`).
3. Add `Tests/SwiftEchadaTests/CastPipelineTests.swift`: a dry-run of the full `cast` runs bootstrap + `generate cast` and stops before the model stages (assert `PROJECT.md` now has a cast list and nothing under `voices/`); a `--force` cascade test asserting each stage receives the force flag.

**Exit criteria**:
- [ ] Wiring/help assertions cover default subcommand, root subcommands, `generate` subcommands + no-default, and non-empty abstract/discussion per command.
- [ ] `CastPipelineTests` asserts bootstrap-then-cast dry-run and the `--force` cascade.
- [ ] `make test` passes.

### Sortie 9: Model-backed tests (gated; run in CI, skip locally when absent)

**Entry criteria**:
- [ ] S6 complete (final commands) and S10 complete (CI model-enablement). Per resolved OQ-4 (hosted-only assumption): the TTS-weights `.vox` tests **execute in CI** (S10 caches the weights); the Foundation-Model assertions **skip on hosted `macos-26`** and are exercised locally / on a self-hosted Apple-Intelligence runner.

**Tasks**:
1. Retarget the existing `generate vox` end-to-end `.vox` test to produce a valid multi-model `.vox`, gated on TTS-weights presence. (This is the model-backed test that DOES run in CI once S10 caches the weights.)
2. Add a full-pipeline test: `echada cast` on a fixture episodes dir with **no** `PROJECT.md` → asserts `PROJECT.md` created, cast populated (heuristic — always runs), `voicePrompt`s written (Foundation Model), and `.vox` files produced (MLX). Gate the model-dependent assertions with `.enabled(if: SystemLanguageModel.default.isAvailable)` + a TTS-weights presence check. Per resolved OQ-4, the `voicePrompt` (Foundation Model) assertions skip on hosted CI; the heuristic-cast and `.vox` assertions still run.
3. Add/confirm a `generate prompt` test against a fixture gated on `SystemLanguageModel.default.isAvailable` (consistent with `FoundationModelSentenceTests`). Per resolved OQ-4, this test is expected to **skip on hosted CI** — that is the accepted coverage gap, not a failure.
4. Leave the `make integration-test` shell smoke pipeline as-is.

**Exit criteria**:
- [ ] Model-backed tests use graceful `.enabled(if:)` / presence gates and are located in `SwiftEchadaTests` (no new target).
- [ ] `make test` passes on a machine WITHOUT models (they skip, never fail).
- [ ] The full-pipeline test asserts the four outputs (PROJECT.md, cast, voicePrompts, .vox) with model steps gated; the `.vox` and heuristic-cast assertions are unconditional, the Foundation-Model assertions are `.enabled(if:)`-gated.

### Sortie 10: CI model-enablement (§6.5, R-CI-1..4)

**Entry criteria**:
- [ ] First sortie — no code prerequisites. May run in parallel with WU1. (Consider delegating to the `acervo-integration-ci` skill.)

**Tasks**:
1. R-CI-2: wire SwiftAcervo model caching into `.github/workflows/tests.yml` using the `acervo-integration-ci` pattern (`actions/cache` restore + prime-on-miss, forwarding `TEST_RUNNER_ACERVO_*` into the xctest runner) so the Qwen3-TTS 0.6b/1.7b weights are present when `generate vox` tests run. **This is the part of OQ-4 that works on hosted CI and must be delivered.**
2. R-CI-1 (per resolved OQ-4 — hosted-only assumption; R-CI-1 treated as UNMET): document in `tests.yml` and `Docs/build-and-test.md` that GitHub-hosted `macos-26` reports `SystemLanguageModel.default.isAvailable == false`, so the Foundation-Model tests (`generate prompt`, full-pipeline `voicePrompt` assertions) **skip on hosted CI** and are exercised only locally / on a self-hosted Apple-Intelligence runner. Do NOT claim CI exercises the Foundation-Model paths. Record that full model-path CI coverage is a future item contingent on provisioning such a runner.
3. R-CI-3: correct the stale gate comment in `FoundationModelSentenceTests` to accurately state that AI is unavailable on hosted CI runners (tests skip there and run locally / on self-hosted runners); keep the `.enabled(if:)` guard. **Do not** rewrite it to claim CI now provisions AI — that would be false under the accepted OQ-4 decision.
4. R-CI-4: if any job/status-check name changes, update branch protection `required_status_checks.contexts` via `gh api --method PUT` (per repo convention).

**Exit criteria**:
- [ ] `tests.yml` restores/primes the SwiftAcervo model cache and forwards `TEST_RUNNER_ACERVO_*` into the test runner (verifiable: `grep -q 'TEST_RUNNER_ACERVO' .github/workflows/tests.yml`).
- [ ] `tests.yml` + `Docs/build-and-test.md` document that hosted `macos-26` lacks Apple Intelligence and that Foundation-Model tests skip on hosted CI (no claim that CI exercises them).
- [ ] `FoundationModelSentenceTests` header comment accurately states AI is unavailable on hosted CI (not that CI now provisions it).
- [ ] If job names changed, branch-protection contexts match; the Tests workflow parses/lints clean (`actionlint .github/workflows/tests.yml`).

### Sortie 11: Documentation + CHANGELOG + version bump

**Entry criteria**:
- [ ] S6 complete: final `--help` text (the source of truth) is stable.

**Tasks**:
1. Update prose docs to mirror `--help` (do not diverge): `AGENTS.md` (CLI table), `README.md` (CLI usage — currently says "three commands"), `Docs/api.md` (`## CLI (echada)` section), `Docs/gotchas.md` (the rule "default subcommand is `cast`" now means the pipeline), and `CLAUDE.md`.
2. Add a CHANGELOG entry announcing the breaking change (`echada cast` repurposed; `echada prompt` → `echada generate prompt`; old `.vox`-only `cast` → `echada generate vox`).
3. Bump the version by one **minor release version** (breaking CLI surface, per requirements §2.1 — use relative version language; the exact number is set at release time by incrementing the highest existing semver tag).

**Exit criteria**:
- [ ] `README.md` no longer says "three commands" and documents the `generate` namespace + `cast` pipeline.
- [ ] `AGENTS.md`, `Docs/api.md`, `Docs/gotchas.md`, `CLAUDE.md` reflect the new command tree.
- [ ] CHANGELOG has a breaking-change entry and the version is bumped to the next minor release version.
- [ ] `make build` and `make test` still pass after doc/version edits.

---

## Resolved Decisions (Pass 1 — refine-blockers)

<!-- All blocking open questions resolved on 2026-07-04. Decisions baked into the sorties above. -->

| # | Affects | Decision | Source |
|---|---------|----------|--------|
| OQ-1 | Sortie 3 | **Heuristic-only in v1** — character names only; `gender`/`language`/`description` left empty; LLM enrichment deferred behind a future `--enrich` flag. | recommendation accepted |
| OQ-2 | Sortie 5 | **Single cascading `--force`** mapped to each stage's force flag; per-stage control via standalone `generate <stage>` subcommands. | recommendation accepted |
| OQ-3 | Sortie 5 | **Infer `PROJECT.md` fields automatically** — `title` from `analyzeForGeneration().inferredTitle` (fallback: folder name), `author = NSFullUserName()`, `created = now`, `episodesDir`/`filePattern` from analysis; no flags/prompt. | recommendation accepted |
| OQ-4 | Sortie 9, 10 | **Hosted-only assumption; R-CI-1 treated as UNMET.** Deliver R-CI-2 (TTS-weights caching, which works on hosted `macos-26`). Foundation-Model tests skip on hosted CI and are exercised locally / on a self-hosted Apple-Intelligence runner; docs must NOT claim CI exercises the model paths. Full model-path CI coverage is a future item. | recommendation accepted |

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 5 |
| Total sorties | 11 |
| Open questions | 0 (4 resolved in Pass 1) |
| Dependency structure | 6 layers (S1–S3 + S10 parallel at Layer 1) |
