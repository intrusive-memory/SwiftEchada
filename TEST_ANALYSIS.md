# Test Analysis Report

**Repository**: SwiftEchada
**Branch**: development
**Commit**: 5f7fda3
**Date**: 2026-06-14
**Test scheme**: SwiftEchada-Package
**Tests considered**: 11 suites + 1 free test function · 81 test cases (12 test files)

## Executive summary

| Pass | Findings | Highest priority item |
|------|----------|------------------------|
| 1. High-repetition tests | 0 (resolved) (+1 note) | ✅ Merged the two near-duplicate base-description castability tests in `PerLanguagePromptTests` |
| 2. Superfluous tests | 1 | `versionIsSet()` asserts only non-emptiness of a string literal |
| 3. Coverage gaps | 4 files | Model-dependent CLI paths (`VoiceCommand`, `CastVoiceGenerator.generate`) run in neither unit nor CI lanes |
| 4. Flaky-in-CI predictions | 0 (1 note) | None — temp dirs and cleanup are correct; FM tests depend on the on-device model |
| 5. Performance gating | 0 | No findings |

The suite is healthy: the pure library (`SwiftEchada`) is at 100% line coverage, Pass 4 found no real flake smells (per-test temp dirs with `defer` cleanup, no sleeps/network/wall-clock), and there are no performance tests leaking into CI. `make lint` ran clean with no diff. The single most impactful gap is **Pass 3**: the model-dependent CLI orchestration (`VoiceCommand` 0%, `CastVoiceGenerator.generate` 12%, `CastCommand.run` 18%) is exercised only by the `make integration-test` target, which is **not wired into CI** — so those paths regress silently. The cheap win — unit-testing `CastCommand.run()`'s model-free branches (dry-run, validation, `--character` filter) — has since been implemented (`CastCommandTests`), raising `CastCommand.swift` from 18% → 58%. The remaining low-coverage CLI files are genuinely model-dependent (`VoiceCommand`, `CastVoiceGenerator.generate`) and need an integration lane, not unit tests.

## Pass 1 — High-repetition tests

### Copy-paste patterns
- ✅ **DONE** — `Tests/SwiftEchadaTests/PerLanguagePromptTests.swift` — the two near-duplicate base-description castability tests were merged into one parameterized `@Test(arguments: [["es","en"], ["es","en","fr"]]) memberWithBaseDescriptionIsCastableForAllRequestedLanguages(_:)`. Both language-list cases still run; the duplicated body is gone.

> note (cross-file overlap, introduced this cycle): `NonEnglishPassthroughTests` parameterizes castability/prompt-selection over es/pt/it/de and partially overlaps the logical cases in `PerLanguagePromptTests` (e.g. `localizedVoiceCastableForItsLanguage` ↔ `memberWithLocalizedVoiceOnlyIsCastableForThatLanguage`; `baseDescriptionCastableForAllNonEnglish` ↔ the two tests above). The overlap is defensible — `PerLanguagePromptTests` covers logical edge cases (regional subtags, accent composition, empty input) while `NonEnglishPassthroughTests` pins the four target-language matrix — but if duplication grows, consolidate the plain castability assertions into the parameterized file and let `PerLanguagePromptTests` own the edge cases. Low priority; no action required now.

### High-iteration loops
No findings. No `for _ in 0..<N` stress loops or repeated deterministic-output calls in any test.

## Pass 2 — Superfluous tests

- `Tests/SwiftEchadaTests/SwiftEchadaTests.swift:5` — `versionIsSet()` asserts `!SwiftEchada.version.isEmpty`. `version` is a compile-time string literal, so this auto-passes forever and can only fail if someone sets it to `""`. Very low signal.
  - **Action**: keep-or-delete (low priority). It's nearly free; the only real value is catching an accidental empty version constant. Delete if you want a leaner suite, otherwise harmless.

## Pass 3 — Coverage gaps

Coverage measured by running the CI test invocation with coverage enabled:
`xcodebuild test -scheme SwiftEchada-Package -destination 'platform=macOS,arch=arm64' -enableCodeCoverage YES` and parsing `xccov --json`. Library + CLI sources shown; tests, `.build/`, and vendored deps excluded.

**Library (`Sources/SwiftEchada/`) — fully covered:**

| File | Line coverage |
|------|---------------|
| `CharacterInfo.swift` | 100% |
| `CharacterProfile.swift` | 100% |
| `CharacterMerger.swift` | 100% |

**CLI (`Sources/EchadaCLICore/`) — gaps:**

| File | Line coverage | Why it matters | Top uncovered |
|------|---------------|----------------|---------------|
| `VoiceCommand.swift` | 0% (0/105) | Entire `voice` command path — public CLI surface | `run()` (model load → generate → lock → export) |
| `VoiceDesigner.swift` | 0% (0/73) | Candidate-WAV generation helper | `generateCandidate`, `generateCandidates` |
| `TestVoiceCommand.swift` | 0% (0/74) | Hidden integration command | `run()` |
| `ReferenceAudioGenerator.swift` | 0% (0/58) | `say`-based reference audio | `generate`, `generateData` |
| `CastVoiceGenerator.swift` | 12% (44/354) | **Core `cast` orchestration** | `generate(cast:)` Phase A/B (model loading, locking, export) |
| `CastCommand.swift` | 58% (105/181) ✅ | `cast` entry point | remaining lines are the model-dependent generate/merge/write path |
| `FoundationModelSentence.swift` | 72% (80/111) | On-device sentence source (new) | error-message branches, a few `sanitize` edges |

**The real story:** most of the uncovered CLI lines require a real Qwen3-TTS model to be loaded, so they are inherently *integration* concerns. The pure logic that *can* be unit-tested already is (decision functions in `CastVoiceGenerator` at 12% are the tested 44 lines; the untested 310 are model orchestration). Two actionable gaps that need **no** model:

- ✅ **DONE** — `CastCommand.run()` model-free branches are now covered by `CastCommandTests` (7 tests: missing project, no cast, unsupported `--tts-model`, unknown `--character`, dry-run-writes-nothing, dry-run `--character` filter, case-insensitive filter). This raised `CastCommand.swift` from **18% → 58%**; the remaining uncovered lines are the model-dependent generate/merge/write path that needs a real TTS model.
- The model-dependent paths (`CastVoiceGenerator.generate`, `VoiceCommand.run`, `VoiceDesigner`, `TestVoiceCommand`) are exercised only by `make integration-test`, which is **not in CI** (`tests.yml` runs `xcodebuild test` on the package; `integration-test` is a separate target requiring `make install`). **Action**: decide whether the integration target should run in a gated CI job (it now hard-requires Apple Intelligence + model downloads), or accept that these paths are validated locally only — and document that choice.

## Pass 4 — Flaky-in-CI predictions

No findings. Specifically checked and cleared:

- **Temp filesystem**: `VoxFileIntegrationTests` and `CastVoiceGeneratorDecisionTests` build per-test paths under `FileManager.default.temporaryDirectory` with a `UUID()` segment and clean up via `defer { try? removeItem(...) }`. Correct isolation, not a fixed-path race.
- **Randomness**: `UInt8.random` only fills opaque synthetic WAV/clone-prompt payloads that are never asserted on; `UUID()`/`Date()` feed temp paths and an unread `created` field, not assertion paths.
- **No** `Thread.sleep`/`Task.sleep`, wall-clock `accuracy:` assertions, network calls, shared singletons/`UserDefaults`, or order-dependent state.

> note (low risk, by design): `FoundationModelSentenceTests` makes real on-device `SystemLanguageModel` calls and asserts the generated sentence's `NLLanguageRecognizer.dominantLanguage` equals the requested language (es/pt/it/de). Detection was stable across repeated local runs, but this is a genuine dependency on a nondeterministic model + Apple Intelligence availability on the runner. It is intentional (the project now hard-requires Apple Intelligence and you confirmed it's available on `macos-26`). If it ever flakes, loosen `dominantLanguage == expected` to "expected is the top-1 or top-2 hypothesis" rather than deleting the test.

## Pass 5 — Performance test gating

No findings. No `measure {}` blocks, `.timeLimit` benchmarks, `*Perf*`/`*Benchmark*` files, or custom timing assertions exist. (The `measure` grep hits are the word "measured" inside voice-prompt strings.)

> note: `make integration-test` exists but isn't run by any workflow. That's the inverse case — a heavyweight target that's defined but unwired. Called out under Pass 3 rather than here since it's about coverage of model paths, not perf gating.

## Consolidated action items

### Delete
- (optional, low priority) `Tests/SwiftEchadaTests/SwiftEchadaTests.swift:5` — `versionIsSet()` non-empty-on-a-literal check.

### Refactor / merge
- ✅ **DONE** — merged the two base-description castability tests in `PerLanguagePromptTests.swift` into one parameterized test.
- (watch, no action yet) Cross-file castability overlap between `NonEnglishPassthroughTests` and `PerLanguagePromptTests`.

### Gate / move out of CI
- None. No perf tests, and no flaky tests currently running in CI.
- Decision needed (not a fix): whether `make integration-test` (model-dependent paths) should run in a gated CI job or stay local-only — document the choice.

### Add tests for
- ✅ **DONE** — `CastCommand.run()` model-free branches (`CastCommandTests`, 7 tests). `CastCommand.swift` coverage 18% → 58%.
