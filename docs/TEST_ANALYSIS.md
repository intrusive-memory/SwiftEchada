---
type: doc
---

# Test Analysis Report

**Repository**: SwiftEchada
**Branch**: development
**Commit**: 98eca5f
**Date**: 2026-10-22
**Test scheme**: SwiftEchada-Package
**Tests considered**: 30 suites · 213 test cases (30 test files)

## Executive summary

| Pass | Findings | Highest priority item |
|------|----------|------------------------|
| 1. High-repetition tests | 2 (+1 note) | One model-backed test loads two TTS models and accounts for 99.9% of CI test time |
| 2. Superfluous tests | 1 | `versionIsSet()` checks that a string literal is not empty |
| 3. Coverage gaps | 5 files | `VoiceCommand` and `TestVoiceCommand` are still at 0%; `CastVoiceGenerator` is at 32% |
| 4. Flaky-in-CI predictions | 1 | The model-backed `.vox` test depends on a multi-GB cache and runner speed |
| 5. Performance gating | 1 (CI cost) | CI takes 17m32s per run on `xcode-27`; local runs take 4 s |

This report updates the previous one (2026-06-14): 3 findings resolved, 4 new, 3 updated. `make lint` reformatted two lines (in `VoicePromptSynthesizer.swift` and `GenerateCastCommandTests.swift`). Those changes are uncommitted.

**Why CI is slow.** The suite itself is fast. Locally, all 213 tests pass in **4.0 s**. On the `xcode-27` runner, the Unit Tests job took **17m32s**, up from 9m47s on `macos-26` the day before. Three costs account for the job time:

| Phase | `macos-26` (2026-10-21) | `xcode-27` (2026-10-22) | Cause |
|---|---|---|---|
| Model weights | 1m38s CDN download + 1m14s cache save | **4m09s** `actions/cache` restore | Restoring the cache on the new image is about 2.5× slower than downloading the weights from our CDN |
| Build | 4m07s (1,188 compile steps) | **7m43s** (1,617 compile steps) | SwiftLlavero brings in Firebase AI Logic, FirebaseCore, and ClaudeForFoundationModels, all built from source. `tests.yml` has no DerivedData or SwiftPM cache |
| Tests | 2m25s | **4m53s** | **One test**, `generate vox produces a valid multi-model .vox`, takes 292.8 s. All other tests finish in under 6 s, running in parallel |
| Metal Toolchain | — | 0m21s | The `xcode-27` image does not include it |

The most effective change is to make the `.vox` test generate one model variant instead of two, and to test multi-model append on synthetic embeddings (Pass 1). That change saves about 2.5 minutes per run. Dropping `actions/cache` for the weights in favor of the CDN download saves another 2.5 minutes. Caching DerivedData for the Firebase build is the third option.

## Pass 1 — High-repetition tests

### Copy-paste patterns
- `Tests/SwiftEchadaTests/ModelBackedGenerationTests.swift:128`, `CastPipelineTests.swift:43`, `CastBodyPreservationTests.swift:103`: there are three copies of `makeIsolatedProject(scripts:)`. They differ only in the temp-dir prefix (`model-backed-`, `cast-pipeline-`, `cast-body-`). `oneCharacterScript` is also defined twice, at `ModelBackedGenerationTests.swift:97` and `CastBodyPreservationTests.swift:52`.
  - **Action**: refactor. Move one `makeIsolatedProject(prefix:scripts:)` and the fixture script into `Fixtures`.

> note (carried over): `NonEnglishPassthroughTests` partly overlaps `PerLanguagePromptTests` on castability. The overlap is defensible. Low priority; no action needed now.

### Repeated model work
- `Tests/SwiftEchadaTests/ModelBackedGenerationTests.swift:158-221`: `generateVoxProducesMultiModelVox` runs the whole `generate vox` command twice, once with `--tts-model 0.6b` and once with `1.7b`. Each run loads Qwen3-TTS VoiceDesign 1.7B plus a Base model and synthesizes audio. The test took **292.8 s on `xcode-27`** and 144.9 s on `macos-26`, which is 99.9% of the CI test phase. The extra value of the second run is that the embedding is *appended* to an existing bundle. That behavior belongs to `.vox` merging, not to TTS.
  - **Action**: refactor. Keep one real model-backed run (0.6b only). Cover the append and multi-model path with a test that writes two synthetic embeddings, as `VoxFileIntegrationTests` already does for other bundle shapes. Expected saving: about half of the test phase, roughly 2.5 min per CI run.

## Pass 2 — Superfluous tests

- `Tests/SwiftEchadaTests/SwiftEchadaTests.swift:5`: `versionIsSet()` asserts `!SwiftEchada.version.isEmpty` on a compile-time literal. It passes after every version bump. `DependencyVersionsTests.versionReportLeadsWithVersion` is a stronger test of the same thing.
  - **Action**: delete, or keep (low priority, costs nothing).

### Resolved since last run
- The `FoundationModelSentence.swift` gap and its `FoundationModelSentenceTests` note are gone. Audition sentences are now curated data (`AuditionSentence.swift`, 98% coverage).

## Pass 3 — Coverage gaps

Coverage was measured with `xcodebuild test -scheme SwiftEchada-Package -destination 'platform=macOS,arch=arm64' -only-testing:SwiftEchadaTests -enableCodeCoverage YES` and the results were parsed with `xccov --json`. The run was local, on a Mac with Apple Intelligence and without TTS weights. As a result, `generate prompt` was covered and the three TTS-gated tests skipped. In CI the reverse is true: the `.vox` test runs and `generate prompt` skips. Generated files are excluded.

The library (`SwiftEchada`) has **100%** coverage (62/62 lines). `EchadaCLICore` has **67%** (1570/2344 lines).

| File | Line coverage | Why it matters | Top uncovered |
|------|---------------|----------------|---------------|
| `VoiceCommand.swift` | 0% (0/109) | The `echada voice` command, public CLI surface | `run()` |
| `VoiceDesigner.swift` | 0% (0/77) | Candidate generation for `voice` and `cast` | `composeVoiceDescription(from:)` (pure, needs no model), `generateCandidate(s)` |
| `TestVoiceCommand.swift` | 0% (0/74) | Hidden integration command | `run()` |
| `ReferenceAudioGenerator.swift` | 0% (0/58) | Reference audio generated with `say` | `generate`, `generateData` |
| `CastVoiceGenerator.swift` | 32% locally (122/386), up from 12% | Core `cast` vox orchestration | `logLanguageAudit`, `resolvedModelRepo()`, error descriptions |

- **Cheap win, no model needed:** `VoiceDesigner.composeVoiceDescription(from:)` is a pure function at 0%.
- **Still open from last run:** the model-dependent paths (`VoiceCommand`, `TestVoiceCommand`, `VoiceDesigner.generateCandidate`) run only under `make integration-test`, which no workflow calls. Decide whether that is acceptable and document the decision.
- **New, SwiftLlavero wiring:** `LanguageModelResolver.swift` is at 100%. `GeneratePromptCommand.swift` is at 82% only because this Mac has Apple Intelligence. Hosted CI skips the model-backed `generate prompt` test, so the `--llm` resolution path is covered there only by `LanguageModelOptionTests` (parse plus the unconfigured-account error).

## Pass 4 — Flaky-in-CI predictions

- `Tests/SwiftEchadaTests/ModelBackedGenerationTests.swift:158`: `generateVoxProducesMultiModelVox`.
  - **Smell**: heavy external state and runner speed. The test needs a multi-GB weight cache restored, then runs two full MLX TTS passes. Its duration doubled (145 s → 293 s) when the runner image changed, without any code change. There is no `.timeLimit`. On a slower or busier runner it moves toward the job timeout, and a partial cache restore silently changes which tests run, because `TTSWeights.present` only checks that the directory exists.
  - **Action**: the Pass 1 split removes most of the risk. Also add `.timeLimit(.minutes(10))` so a hung run fails with a clear message instead of using the whole job timeout.

Checked and found clean: no `sleep`, no wall-clock assertions, no network in correctness tests, and no shared `UserDefaults` or singletons. Every temp directory is per-test (`UUID()`) and is removed with `defer`, including the new `/private/tmp/echada-private-<UUID>` fixture at `GenerateCastCommandTests.swift:358`. `Date()` at `VoxFileIntegrationTests.swift:58`, `GenerateVoxCommandTests.swift:172` and `CastVoiceGeneratorDecisionTests.swift:54` only fills a `created` field that no assertion reads.

> note (stale docs, not flaky): the doc comments in `ModelBackedGenerationTests.swift:19-37` and `:213-219` still say "macos-26", `VoicePromptSynthesizer.requireAvailable()` (removed in 2.1.0), and "the vox stage sources its audition sentence from the Foundation Model" (no longer true). Update them so nobody gates on the wrong condition.

## Pass 5 — Performance test gating

There are no `measure {}`, `.timeLimit` benchmarks, or `*Perf*` suites. The CI cost problem is the model-backed lane described above, together with build and cache overhead.

- `.github/workflows/tests.yml`: Unit Tests takes **17m32s** per run, and it runs on every PR update and again on every push to `main`. Each `development → main` release therefore costs at least 35 runner-minutes on macOS.
  - **Action 1**: remove the `actions/cache` restore and save for `ACERVO_MODELS_DIR`, and always prime from `cdn.intrusive-memory.productions`. On 2026-10-21 that took 1m38s, compared with the 4m09s restore today, and it also removes the 1m14s save after a cache miss. Re-measure after one or two runs, since this rests on one sample of each.
  - **Action 2**: cache DerivedData and SwiftPM checkouts in `tests.yml`, keyed on `Package.resolved`, as `release.yml` already does. Firebase and the Claude SDK account for most of the +3.5 min of build time.
  - **Action 3** (optional): skip CI on draft PRs (see `/draft-pr-ci-gate`), so pushes to the long-lived `Development → Main` draft don't each cost 17 minutes.
- `make integration-test` exists but no workflow runs it (carried over).

## Consolidated action items

### Delete
- (optional, low priority) `Tests/SwiftEchadaTests/SwiftEchadaTests.swift:5`: `versionIsSet()`.

### Refactor
- `Tests/SwiftEchadaTests/ModelBackedGenerationTests.swift:158`: one real 0.6b run plus a synthetic-embedding multi-model append test. **Largest saving in test time.**
- `ModelBackedGenerationTests.swift:128`, `CastPipelineTests.swift:43`, `CastBodyPreservationTests.swift:103`: one shared `makeIsolatedProject` and `oneCharacterScript` in `Fixtures`.
- `ModelBackedGenerationTests.swift:19-37, 213-219`: correct the stale gate documentation.

### Gate / move out of CI
- `.github/workflows/tests.yml`: drop the model `actions/cache` in favor of the CDN download, add a DerivedData/SwiftPM cache, and optionally skip draft PRs.
- `ModelBackedGenerationTests.swift:158`: add `.timeLimit(.minutes(10))`.
- Decision needed: should `make integration-test` get a CI lane, or stay local-only?

### Add tests for
- `Sources/EchadaCLICore/VoiceDesigner.swift`: `composeVoiceDescription(from:)` is pure and at 0%.
- `Sources/EchadaCLICore/VoiceCommand.swift`: the model-free branches of `run()` (validation, missing inputs), following the `CastCommandTests` pattern that raised `CastCommand` from 18% to 78%.
