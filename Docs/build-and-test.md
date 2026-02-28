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
| `SampleSentenceGeneratorTests` | 4 | Random quotes, async generation |
| `VoicePromptRoundTripTests` | 3 | YAML parse/serialize, field preservation |

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
