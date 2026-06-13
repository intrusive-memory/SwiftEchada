# TEST_CLEANUP_REPORT — OPERATION ACCENT TOWER

**Mission branch:** `mission/accent-tower/01` · **Starting commit:** `bd95a2d` · **Date:** 2026-06-12

Post-mission pass to prune tests added during the mission that cannot run reliably in CI.

## Test files in scope (mission diff `bd95a2d..HEAD`)

| File | Added by | Kind |
|------|----------|------|
| `Tests/SwiftEchadaTests/AccentOptionTests.swift` | Sortie 1 | swift-testing, pure logic (8 `@Test`) |
| `Tests/SwiftEchadaTests/PerLanguagePromptTests.swift` | Sorties 2–3 | swift-testing, pure logic (14 `@Test`) |

## Removed

_None._ Neither file matches any of the 12 high-confidence CI-failure patterns.

| file:test | reason | confidence |
|-----------|--------|------------|
| — | — | — |

## Flagged for Review

_None._

| file:test | concern | recommended action |
|-----------|---------|--------------------|
| — | — | — |

## Build Verification

Skipped as redundant: **no tests were removed**, so the suite is unchanged from the mission's last green run (`make test` green at Sortie 3 completion — 74 tests, commit `5c61cb2`).

## Rationale

Both files were screened against the danger patterns (hardcoded `/Users/`·`/home/` paths, public-host network calls, local-only services, unset env-var gating, user-profile reads, sub-100ms sleep timing, `Date()`/`.now` assertions, unordered-collection iteration order, unseeded randomness, rotting `@skip` markers, empty/assertion-less bodies, exact duplicates). A direct scan (`grep` for `/Users/`·`/home/`·`https?://`·`Date()`·`.now`·`sleep`·`Task.sleep`·`random`·`localhost`·`ProcessInfo`·`getenv`·`FileManager`) returned **zero matches** in either file.

Both test files exercise pure functions (`composeVoicePrompt`, `castableLanguages`, and the `voice(for:) ?? voiceDescription` selection) over in-memory `CastMember` values with deterministic string/dictionary assertions — no I/O, no clock, no network, no randomness, no MLX/Metal. They are fully CI-safe and stay.
