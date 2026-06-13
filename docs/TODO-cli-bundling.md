# TODO — Extract `EchadaCLICore` library (CLI-bundling prep)

Part of a cross-repo effort to embed the `echada` CLI (and siblings) into `Produciesta.app`,
signed with the `group.intrusive-memory.models` App Group, following the SwiftVinetas pattern
(`VinetasCLICore` library + thin executable). An Xcode tool target cannot link an SPM
*executable* product, so the command logic must live in a **library** product.

Reference: `/Users/stovak/Projects/SwiftVinetas/Package.swift` (the `VinetasCLICore` library
product) and `/Users/stovak/Projects/Vinetas/VinetasCLI/VinetasCLIMain.swift` (thin re-host).

## Goal
Expose a new `EchadaCLICore` library product holding the `echada` command tree, reduce the
`echada` executable target to a thin `@main` re-host, keep the build and tests green.

## Steps
1. **Package.swift**
   - Add product: `.library(name: "EchadaCLICore", targets: ["EchadaCLICore"])`.
   - Add target `EchadaCLICore` whose dependencies = the **current `echada` executable
     target's** deps (`SwiftEchada`, `SwiftVoxAlta`, `ArgumentParser`, `MLX`, `MLXAudioTTS`,
     `MLXLMCommon`, `VoxFormat`) **plus `SwiftProyecto`** (imported by the moved command
     sources). Carry over `swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]`.
   - Slim the `echada` executable target deps to `["EchadaCLICore", ArgumentParser]` plus
     `SwiftEchada` (the thin root still imports `SwiftEchada.version`).
   - In the `SwiftEchadaTests` target deps, replace `"echada"` → `"EchadaCLICore"`.

2. **Move sources** `Sources/echada/` → `Sources/EchadaCLICore/`:
   `CastCommand.swift`, `VoiceCommand.swift`, `TestVoiceCommand.swift`,
   `CastVoiceGenerator.swift`, `VoiceDesigner.swift`, `ReferenceAudioGenerator.swift`,
   **and the root `EchadaCLI` struct** (move it out of `Sources/echada/EchadaCLI.swift`).
   - Make `EchadaCLI`, `CastCommand`, `VoiceCommand`, `TestVoiceCommand` `public`
     (`public init() {}`, `public static let configuration`, `public` on `@Option`/`@Flag`
     parsed properties and `public func run()`).
   - **Strip `@main`** from `EchadaCLI` in the library (a library cannot declare `@main`).
   - Helpers (`CastVoiceGenerator`, `VoiceDesigner`, `ReferenceAudioGenerator`, error enums)
     stay `internal`.

3. **Thin executable** — `Sources/echada/EchadaCLI.swift` (keep this filename; do NOT name it
   `main.swift`, which would make `@main` illegal):
   ```swift
   import ArgumentParser
   import EchadaCLICore
   @main
   struct EchadaCLIEntry: AsyncParsableCommand {
     static let configuration = EchadaCLI.configuration
   }
   ```

4. **Tests** — `Tests/SwiftEchadaTests/CastVoiceGeneratorDecisionTests.swift`:
   change `@testable import echada` → `@testable import EchadaCLICore`. (`@testable` keeps
   internal symbols visible, so no further API changes needed.) Other test files import
   `SwiftEchada` and are untouched.

5. **Build green** via the Makefile / xcodebuild (NEVER `swift build` or `swift test`):
   `make resolve && make install && make test` (uses `-destination platform=macOS,arch=arm64`).

6. **Version**: bump `SwiftEchada.version` in `Sources/SwiftEchada/SwiftEchada.swift` to
   `0.11.0` (or `-dev` per the repo's convention).

## Wrap-up
- Branch off `development`, commit, push to `development`, then run `/create-pull-request`.
- **Do NOT tag/release in this PR.** Release to **0.11.0** happens after merge (via
  `/ship-swift-library`, minor bump — additive new product). Produciesta pins this remotely
  and needs the release before it can link `EchadaCLICore`.

## Guardrails
- No source here uses `Bundle.module` — the new target needs no `resources:`.
- Keep `@main` only on the thin executable's `EchadaCLIEntry`, never on the library type.
