# SwiftAcervo v2 Integration Audit

**Audited**: 2026-04-26
**Standard**: SwiftAcervo v0.8.2 (sole supplier of ML models)
**Verdict**: Largely compliant. Three concrete deviations to address, plus one architectural question to resolve.

---

## Scope

This audit checks every place SwiftEchada touches model files, model paths, or CDN endpoints, against the SwiftAcervo v2 contract:

- All model downloads go through `Acervo.*` / `AcervoManager.*` / `ModelDownloadManager.*`.
- Consumers never construct CDN URLs, never call `URLSession` for model assets, never hardcode cache paths, never compute checksums.
- Model resolution uses `Acervo.modelDirectory(for:)` and `Acervo.isModelAvailable(_:)`.
- Component-style models (`Qwen3TTSModelRepo`, etc.) are registered via `ComponentDescriptor` and loaded with `Acervo.ensureComponentReady(_:)`.
- A repo that publishes models has a `.github/workflows/ensure-model-cdn.yml` following the canonical R2 upload pattern.

## What is correct

- **`Package.swift:24`** pins `SwiftAcervo` `from: "0.8.2"` directly. Test target depends on it explicitly (`Package.swift:62`); CLI target gets it transitively via `SwiftVoxAlta`. Library target (`SwiftEchada`) has zero ML dependencies — only `SwiftProyecto` (`Package.swift:34-36`). The library/CLI split mandated by `CLAUDE.md` is intact.
- **All runtime model loading is delegated.** Every CLI call site uses `VoxAltaModelManager().loadModel(.voiceDesign1_7B / .base1_7B / .base0_6B)`:
  - `Sources/echada/VoiceDesigner.swift:59`
  - `Sources/echada/VoiceCommand.swift:41,53`
  - `Sources/echada/CastVoiceGenerator.swift:87,249`
  - `Sources/echada/TestVoiceCommand.swift:44`

  `VoxAltaModelManager.loadModel(...)` internally registers `ComponentDescriptor`s and calls `Acervo.ensureComponentReady(...)`. SwiftEchada itself never constructs a download, never names a file, never computes a path.
- **No HuggingFace direct access, no `~/Library/Caches`, no `~/.cache/huggingface`, no `snapshot_download`-equivalent code anywhere in `Sources/`.** All `FileManager.fileExists` calls in `Sources/echada/` target `.vox` output artifacts (CastVoiceGenerator.swift:109,202; TestVoiceCommand.swift:77; VoiceCommand.swift:89; CastCommand.swift:31), not model files.
- **Model identifiers come from one place** — `Qwen3TTSModelRepo` (re-exported from SwiftVoxAlta). No raw `mlx-community/...` strings in `Sources/`.

## Deviations

### D1. Test file bypasses `Acervo.fetchManifest(_:)` with raw `URLSession`
**File**: `Tests/SwiftEchadaTests/CDNAvailabilityTests.swift:33-37, 57, 67`

```swift
private let cdnBase = "https://pub-8e049ed02be340cbb18f921765fd24f3.r2.dev/models"

private func manifestURL(for modelId: String) -> URL {
  URL(string: "\(cdnBase)/\(Acervo.slugify(modelId))/manifest.json")!
}

// Test bodies:
let (_, response) = try await URLSession.shared.data(from: manifestURL(for: repo.rawValue))
let (data, response) = try await URLSession.shared.data(from: manifestURL(for: repo.rawValue))
```

**Classification**: HARDCODED CDN BASE + MANUAL HTTP FETCH

**Why this is wrong**: The audit standard says consumers must not know the CDN base URL or construct manifest URLs by hand. SwiftAcervo exposes `Acervo.fetchManifest(for:) -> CDNManifest` for exactly this purpose. If the CDN base ever moves, this test breaks silently and the rest of the ecosystem keeps working — the wrong failure mode.

**Fix**: Replace the manual fetch with `Acervo.fetchManifest(for: repo.rawValue)` and assert against the returned `CDNManifest.files` array. Delete `cdnBase` and `manifestURL(_:)`. The "HTTP 200" test collapses into "fetchManifest succeeds"; the "manifest declares required files" test becomes `#expect(manifest.files.contains { $0.path == "config.json" })`.

**Effort**: ~15 minutes. One file, two tests rewritten, no behavior change.

---

### D2. Test target uses `@testable import SwiftAcervo`
**File**: `Tests/SwiftEchadaTests/CDNAvailabilityTests.swift:19`

```swift
@testable import SwiftAcervo
```

**Classification**: REACHING INTO ACERVO INTERNALS

**Why this is wrong**: `@testable` exposes `internal` symbols. SwiftEchada is a *consumer* of SwiftAcervo, not a co-developer of it — it should only depend on the public surface. If a refactor inside Acervo renames or removes an internal symbol, SwiftEchada's tests break for reasons that have nothing to do with SwiftEchada. This is the wrong coupling direction.

The current test only uses public symbols (`Acervo.slugify`, `Acervo.download`, `Acervo.isModelAvailable`), so the `@testable` is dead weight today — but it advertises that we *might* reach inside, which invites future drift.

**Fix**: Change to `import SwiftAcervo`. If the build still passes (it should), commit and move on. If something fails, the missing symbol needs to be added to Acervo's public API.

**Effort**: ~2 minutes. Delete one keyword, rebuild.

---

### D3. CI workflow does not match the canonical `ensure-model-cdn.yml` pattern
**File**: `.github/workflows/mirror-models.yml`

The skill `acervo-cdn-setup` documents the standard as a single self-contained `ensure-model-cdn.yml` workflow that runs `swiftacervo download` → `swiftacervo manifest generate` → `swiftacervo upload` on a `macos-26` runner per repo.

What we have instead is `mirror-models.yml`, which delegates each model to `intrusive-memory/SwiftAcervo/.github/workflows/mirror_model.yml@main` (a reusable workflow inside SwiftAcervo).

**Classification**: NON-STANDARD PATTERN — needs a decision, not necessarily a fix.

**Two defensible interpretations**:

1. **The reusable workflow IS the new standard** (and the `acervo-cdn-setup` skill is out of date). Rationale: a single source of truth in the SwiftAcervo repo means upload logic only changes in one place. SwiftEchada's workflow is then *more* correct than the skill's template.
2. **The skill is right and we should standardize on `ensure-model-cdn.yml` per repo.** Rationale: each library owns its publishing pipeline; centralizing it in SwiftAcervo couples release timing across the ecosystem.

**Other items to surface regardless of which way you go**:
- Workflow pins to `@main` (`.github/workflows/mirror-models.yml:42,51,60`). A `main` branch change in SwiftAcervo can silently break our mirror. Prefer a tag (`@v0.8.2`) or commit SHA.
- The header at lines 8-13 lists `R2_ENDPOINT` as a required secret; the skill template uses `R2_ACCOUNT_ID`. Confirm which the reusable workflow actually consumes — these are not interchangeable.
- Schedule is monthly (`cron: "0 3 1 * *"`); the skill default is daily. Acceptable if Qwen3-TTS upstream is stable, but worth a conscious choice.

**Fix (path 1, keep reusable workflow)**: Pin the `uses:` line to a tag, reconcile the secret name in the header comment, and update the `acervo-cdn-setup` skill so the rest of the ecosystem follows this pattern. ~30 minutes including a SwiftAcervo PR if a tag doesn't exist.

**Fix (path 2, switch to per-repo `ensure-model-cdn.yml`)**: Run the `acervo-cdn-setup` skill against this repo. It will scan, generate the standard workflow, and replace `mirror-models.yml`. ~10 minutes, but you lose the centralization benefit.

---

## Open architectural question

The `acervo-cdn-setup` skill description says it "removes legacy upload patterns" and "generates the ensure-model-cdn.yml workflow following Cloudflare R2 standards." The reusable-workflow approach used here is either an evolution past that skill or a parallel pattern that was never harmonized. **You need to decide which is canonical before this audit can tell other libraries what to copy.** The fix for D3 depends entirely on that decision.

---

## Items intentionally NOT flagged

- `VoxAltaModelManager()` is instantiated per-command rather than as a singleton. This is fine — `AcervoManager.shared` (the actor underneath) handles serialization across instances.
- `Qwen3TTSModelRepo` is imported from `SwiftVoxAlta` rather than declared in SwiftEchada. Correct — model identifiers belong with the framework that registers them.
- `FileManager.fileExists` calls in `Sources/echada/` operate on `.vox` *output* artifacts produced by the CLI, not model files. Out of scope for an Acervo audit.
- `ReferenceAudioGenerator.swift` uses `FileManager.default.temporaryDirectory` for AIFF scratch files (lines 75-77). Audio scratch space, not model storage.

---

## Suggested order of operations

1. Resolve the D3 architectural question (reusable workflow vs per-repo `ensure-model-cdn.yml`). Until that's decided, the rest of the ecosystem can't be aligned.
2. Land D1 + D2 together as a single small PR — both are in `CDNAvailabilityTests.swift`, both are mechanical, both reduce coupling to Acervo internals.
3. Apply the D3 outcome (either pin the `uses:` ref + fix secret naming, or regenerate via the skill).
4. Once SwiftEchada is the reference, update `acervo-cdn-setup` skill or SwiftAcervo docs so the next library that integrates copies the right pattern.
