---
type: reference
---

# Build, Test, and Release

---

## Build System

**CRITICAL**: Always use `xcodebuild` (via the Makefile). Never use `swift build` or `swift test` -- Metal shader compilation in the mlx-swift dependency requires Xcode's build system.

### Makefile Targets

```bash
make resolve          # Resolve SPM package dependencies
make build            # Debug build (xcodebuild)
make install          # Debug build + copy binary to ./bin (default target)
make release          # Release build + copy binary to ./bin
make test             # Run unit tests
make integration-test # Full voice pipeline end-to-end test
make clean            # Remove build artifacts and ./bin
make help             # Show all targets
```

### Build Configuration

| Setting | Value |
|---------|-------|
| Scheme (CLI) | `echada` |
| Scheme (Tests) | `SwiftEchada-Package` |
| Destination | `platform=macOS,arch=arm64` |
| Environment | `GIT_LFS_SKIP_SMUDGE=1` (auto-exported by Makefile) |

### Raw xcodebuild (if needed)

```bash
# Build CLI
GIT_LFS_SKIP_SMUDGE=1 xcodebuild -scheme echada -destination 'platform=macOS,arch=arm64' build

# Run tests
GIT_LFS_SKIP_SMUDGE=1 xcodebuild test -scheme SwiftEchada-Package -destination 'platform=macOS,arch=arm64'
```

### Metal Bundle

The CLI binary requires `mlx-swift_Cmlx.bundle` (containing `default.metallib`) to be colocated in the same directory. The `install` and `release` targets handle this automatically.

---

## Testing

### Test Framework

Swift Testing (`@Test` macro) -- not XCTest.

### Test Suite (31 tests across 6 files)

| Suite | Tests | What It Covers |
|-------|------:|----------------|
| `SwiftEchadaTests` | 1 | Version constant |
| `CharacterProfileTests` | 6 | Profile struct, gender mapping, equality, JSON codability |
| `CharacterInfoTests` | 9 | Extraction struct, optional fields, JSON round-trip |
| `CharacterMergerTests` | 8 | Dedup, voice preservation, alphabetical sorting |
| `VoicePromptRoundTripTests` | 3 | YAML parse/serialize, field preservation |
| `NonEnglishPassthroughTests` | -- | Non-English `--language` passthrough (es/pt/it/de) |
| `FoundationModelSentenceTests` | -- | On-device in-language audition sentences (es/pt/it/de) |

### Fixtures

Test fixture files live in `Fixtures/`:
- `.fountain` screenplays for extraction tests
- `PROJECT.md` examples for round-trip tests

### Integration Test

`make integration-test` runs the full pipeline:

1. Build `vox` validator (from `../vox-format`)
2. Generate `.vox` with 0.6b embeddings (`echada test-voice`)
3. Append 1.7b embeddings to same `.vox`
4. Validate `.vox` structure with strict mode (`vox validate --strict`)
5. Synthesize speech with both models (`diga` from `../SwiftVoxAlta`)
6. Clean up temp files

**Requirements**: Local clones of `vox-format` and `SwiftVoxAlta` at `../vox-format` and `../SwiftVoxAlta`.

---

## CI/CD

### GitHub Actions Workflows

#### `tests.yml` -- Unit Tests

- **Trigger**: Push to `main`, PR to `main`
- **Runner**: `macos-26`
- **Command**: `xcodebuild test -scheme SwiftEchada-Package -destination 'platform=macOS'`
- **Artifact**: `test-output.log` (30-day retention)
- **Summary**: Pass/fail counts posted to Actions summary
- **SwiftAcervo model cache (R-CI-2)**: before running tests, the job computes a
  cache key from the live CDN manifests of the Qwen3-TTS weights `generate vox`
  loads (Base 1.7B, Base 0.6B, VoiceDesign 1.7B), restores `ACERVO_MODELS_DIR`
  via `actions/cache`, and primes any cache miss from the CDN using
  `.github/scripts/acervo-ci-prime.sh` (credential-free curl+jq, no `acervo`
  binary needed). The test step forwards `TEST_RUNNER_ACERVO_MODELS_DIR` and
  `TEST_RUNNER_ACERVO_CDN_BASE_URL` into the xctest runner (xcodebuild strips
  the `TEST_RUNNER_` prefix) so that, on a machine that also has Apple
  Intelligence available (see below), model-backed `.vox` tests would find the
  weights already on disk instead of re-downloading multi-GB checkpoints every
  run. This caching is correct, valuable infrastructure on its own, but **it
  does not by itself make the `.vox` tests run on hosted CI** -- see the next
  bullet. `TEST_RUNNER_ACERVO_OFFLINE` is forwarded as `"0"`, not `"1"` -- see
  the comment block in `tests.yml` for why (SwiftVoxAlta registers its
  Qwen3-TTS components as bare/auto-hydrating descriptors, so strict offline
  mode would block the harmless manifest re-fetch that happens on every fresh
  test process, defeating the cache).
- **Apple Intelligence is NOT available on this runner (R-CI-1, UNMET)**:
  GitHub-hosted `macos-26` reports `SystemLanguageModel.default.isAvailable ==
  false` (no device opt-in, no signed-in Apple Account, no on-device model
  download on ephemeral hosted runners). Every test gated with `.enabled(if:
  SystemLanguageModel.default.isAvailable)` -- `FoundationModelSentenceTests`,
  `generate prompt` -- **skips** on this workflow; that is accepted, expected
  coverage, not a failure.
  **This also includes the `generate vox` and full-pipeline `.vox` tests**
  (`ModelBackedGenerationTests`), even though the TTS weights are cached and
  present: `CastVoiceGenerator.generate()` sources every audition sentence
  exclusively from the on-device Foundation Model
  (`FoundationModelSentence.requireAvailable()`), so those tests are gated on
  the **conjunction** of both Apple Intelligence availability *and* TTS-weight
  presence. Since Apple Intelligence is unavailable on hosted `macos-26`, the
  model-backed `.vox` and full-pipeline `voicePrompt`/`.vox` assertions skip
  here too -- the weight cache keeps the infrastructure ready, but does not by
  itself unlock coverage. All of these paths are exercised locally on a
  developer Mac with Apple Intelligence enabled, or would need a self-hosted
  Apple-Intelligence-provisioned runner, which this workflow does not provide.
  Full CI coverage of both the Foundation-Model paths (`generate prompt`) and
  the transitively-gated model-backed `.vox` paths (`generate vox`,
  full-pipeline `echada cast`) is a future item contingent on standing up such
  a self-hosted runner -- this workflow makes no claim to exercise them today.

#### `release.yml` -- Release Binary

- **Trigger**: GitHub release published OR manual `workflow_dispatch`
- **Runner**: `macos-26`
- **Cache**: DerivedData + SPM packages (keyed on `Package.resolved` hash)
- **Steps**:
  1. `make release`
  2. Verify binary + Metal bundle
  3. Package tarball: `echada-{version}-arm64-macos.tar.gz`
  4. Upload to GitHub release
  5. Dispatch to `intrusive-memory/homebrew-tap` for formula update

### Homebrew Distribution

```bash
brew tap intrusive-memory/tap
brew install echada
```

Formula lives at `intrusive-memory/homebrew-tap/Formula/echada.rb`. The release workflow auto-triggers formula updates via repository dispatch.
