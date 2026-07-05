---
type: mission-completion
state: completed
---

# Test Cleanup Report — OPERATION GENERAL MUSTER

**Date:** 2026-07-04
**Branch:** mission/general-muster/01
**Base Commit:** d514db0

## Summary

Comprehensive review of test files added/modified during OPERATION GENERAL MUSTER. **No violations found.** All new tests follow hermetic patterns with proper isolation, no hardcoded paths, no env-var-gated failures, and correct skip gates where needed. Retargeted files (type name changes only) require no logic evaluation. FoundationModelSentenceTests was comment-edited only.

---

## Removed

None.

---

## Flagged for Review

**ModelBackedGenerationTests.swift** — _Verified CI-safe, no action required._

- **Concern:** Tests gated on `SystemLanguageModel.default.isAvailable && TTSWeights.present`.
- **Pattern:** Environment-gated tests.
- **Finding:** Both gates correctly SKIP (not fail) when conditions are unmet. `TTSWeights.present` is a pure filesystem check (`FileManager.fileExists`) that never loads a model or touches the network. The `.enabled(if:)` gate is the correct Swift Testing mechanism for conditional skipping. Gates align with GitHub Actions CI (macos-26 has no Apple Intelligence; TTSWeights.present checks `$ACERVO_MODELS_DIR` which CI primes via actions/cache). No CI failure risk.
- **Recommendation:** Keep as-is. This pattern is correctly gated and verified CI-safe per OPERATION GENERAL MUSTER's resolved OQ-4 coverage gap.

---

## New Test Files Evaluated

| File | Test Count | Pattern | Result |
|------|-----------|---------|--------|
| GenerateCastCommandTests.swift | 8 | Offline cast discovery + bootstrap; all use `FileManager.default.temporaryDirectory` with `defer` cleanup | CLEAN |
| CLIWiringTests.swift | 9 | CLI wiring/help metadata checks; no I/O or external calls | CLEAN |
| CastPipelineTests.swift | 4 | Offline pipeline behavior (`--dry-run`, `--force` cascade); all use isolated temp dirs | CLEAN |
| GenerateVoxCommandTests.swift | 7 | Model-free validation gates + dry-run; all use isolated temp dirs | CLEAN |
| ModelBackedGenerationTests.swift | 3 | Model-backed tests (Foundation Model, MLX TTS); correctly gated with skip conditions | VERIFIED SAFE |

---

## Retargeted Files (Type Name Changes Only)

The following files were updated to rename command types (`CastCommand` → `GenerateVoxCommand`, etc.) but contain **no new test logic** and are therefore not evaluated:

- `GenerateVoxCommandTests.swift` (retarget of old `CastCommandTests`, renamed)
- `AccentOptionTests.swift`
- `LanguageOptionTests.swift`
- `NonEnglishPassthroughTests.swift`

---

## Comment-Only Edits

- `FoundationModelSentenceTests.swift` — Clarified availability gate behavior; no test logic changes.

---

## Build Verification

```
Test session results:
  132 tests in 20 suites
  All passed
  Duration: 5.931 seconds

Status: ✓ PASS
```

Makefile target used: `make test`

---

## Conclusion

**Status:** ✓ APPROVED FOR CI

All tests added during OPERATION GENERAL MUSTER are CI-safe. No deletions needed. The ModelBackedGenerationTests suite correctly gates on model availability and will skip gracefully on hosted CI runners lacking Apple Intelligence or the Acervo TTS weights.
