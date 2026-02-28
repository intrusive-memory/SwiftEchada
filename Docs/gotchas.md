# Gotchas and Sharp Edges

Things that will trip you up if you don't know about them.

---

## Module/Type Name Collision

`SwiftEchada` is both the **module name** and an **enum type** inside that module. This means `import SwiftEchada` then using `SwiftEchada.CharacterProfile` resolves as member lookup on the enum, not the module.

**Fix**: Use targeted imports in CLI files:

```swift
// CORRECT
import struct SwiftEchada.CharacterProfile
import struct SwiftEchada.SampleSentenceGenerator

// WRONG -- creates ambiguity
import SwiftEchada
```

The CLI entry point uses `import enum SwiftEchada.SwiftEchada` to access the version constant.

---

## Test Scheme Name

The test scheme is `SwiftEchada-Package`, **not** `SwiftEchada`. Using the wrong scheme will build but not run tests.

```bash
# CORRECT
xcodebuild test -scheme SwiftEchada-Package ...

# WRONG -- builds library, runs zero tests
xcodebuild test -scheme SwiftEchada ...
```

---

## Never Use `swift build` / `swift test`

The mlx-swift dependency compiles Metal shaders that require Xcode's build system. `swift build` and `swift test` will fail. Always use the Makefile or `xcodebuild` directly.

---

## GIT_LFS_SKIP_SMUDGE

Dependencies reference Git LFS objects (model files). Set `GIT_LFS_SKIP_SMUDGE=1` to avoid pulling large files during builds. The Makefile exports this automatically.

---

## VoxFile is a Class

`VoxFile` from the `vox-format` package is a **class** (mutable reference type), not a struct. You create/open it, mutate by adding data, then write:

```swift
let vox = VoxFile(name: "Voice", description: "...")
vox.manifest.provenance = ...    // mutate in place
try VoxExporter.addClonePrompt(to: vox, ...)
try vox.write(to: url)
```

---

## VoxExporter Static API

`VoxExporter.addClonePrompt()` and `VoxExporter.addSampleAudio()` are **static functions** that take `modelRepo` to determine storage paths. They also auto-update the manifest.

---

## Package.resolved is Gitignored

`Package.resolved` is not checked into the repo. CI resolves fresh and gets latest dependency versions from branch pins. Locally, after pushing changes to a dependency, you must:

1. `rm Package.resolved`
2. Clear `SourcePackages/` in DerivedData
3. `make resolve`

---

## Default Subcommand

`echada` with no subcommand runs `cast`, not `voice`. The `extract` and `download` commands were removed in v0.9.2.

---

## GenerateParameters Inconsistency

`VoiceDesigner.generateCandidate()` uses explicit generation parameters (`maxTokens: 16384, temperature: 0.6, topP: 0.6, repetitionPenalty: 1.5`), while `CastVoiceGenerator.generateCandidateWithPrompt()` uses `GenerateParameters()` defaults. This is intentional -- the batch pipeline uses defaults for speed.

---

## Integration Test Dependencies

`make integration-test` expects sibling repos at `../vox-format` and `../SwiftVoxAlta`. Without them, it will attempt to build them and fail if not present.
