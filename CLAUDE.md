---
type: project
---

# CLAUDE.md

**Read [AGENTS.md](AGENTS.md) first** for project overview. Deep dives in [Docs/](Docs/).

---

## Claude-Specific Rules

1. **Always use the Makefile** (`make build`, `make test`). Never `swift build` or `swift test`. See [Docs/build-and-test.md](Docs/build-and-test.md).
2. **Test scheme is `SwiftEchada-Package`**, not `SwiftEchada`.
3. **Targeted imports in CLI files**: `import struct SwiftEchada.CharacterProfile` -- not `import SwiftEchada`. See [Docs/gotchas.md](Docs/gotchas.md#moduletype-name-collision).
4. **Library depends only on SwiftReparto** — a leaf package with no `intrusive-memory` dependencies, which owns the `CAST.md` schema (`CastMember`, `Gender`, `CastDocument`, `CastMarkdownParser`). The real invariant: **no ML/voice dependencies in the library target**; those belong to `EchadaVoice` (the app-linkable voice builder: **never add ArgumentParser or a PROJECT.md reader to it**) and `EchadaCLICore`, which also keeps SwiftProyecto for project-level `PROJECT.md` fields (`title`, `episodesDir`, `filePattern`, `tts.model`). Language models come from **SwiftLlavero** (`--llm`, `echada auth`), also `EchadaCLICore`-only.
5. **Ownership split**: `PROJECT.md` is SwiftProyecto's config file; `CAST.md` is SwiftReparto's. All generate stages read and write the cast roster in `CAST.md`. An older `PROJECT.md` that still carries a `cast:` block is migrated automatically by `ProjectMigration` the first time a generate stage opens it (roster → `CAST.md`, original → `PROJECT.md.bak`, `cast:` removed, `schemaVersion: 5` stamped). `LegacyProjectCastReader` is the migration's only reader of the old block.
6. **No default subcommand** — bare `echada` prints help. `echada cast` runs the voice pipeline (bootstrap PROJECT.md + CAST.md → `generate prompt` → `generate vox`). Individual stages live under `echada generate {prompt,vox}`; `generate cast` was removed in v3.0.0 (discovery is `personaje cast-discover`); `verify cast` and `prune cast` were removed in v2.0.0 (migration is automatic). `extract` and the standalone `prompt` command were removed (hard-cut, v0.16.0).

## MCP Servers

### XcodeBuildMCP
Available globally but the Makefile is preferred. Use `swift_package_build`/`swift_package_test` only if the Makefile isn't working.

### App Store Connect MCP
Not applicable -- SwiftEchada is a library, not an app.

## Project Context

- SwiftEchada is a **library + CLI**, not an app. No Xcode project.
- Distributed via **Homebrew** (`brew install intrusive-memory/tap/echada`)
- **On-device voice generation** via SwiftVoxAlta (Qwen3-TTS), into the character record (`characters/<NAME>.dossier/voice/`, EC-23); `EchadaVoice` is the library an app links
- **Voice prompts** from any FoundationModels `LanguageModel` via SwiftLlavero (on-device default; `--llm pcc`, `--llm anthropic:…`)
- **macOS 27 / iOS 27 minimum** (FoundationModels `LanguageModel`); CI runs on the `xcode-27` image
- **Swift 6 language mode**, `Sendable` throughout, strict concurrency
- **Multi-model .vox support** -- single .vox can hold 0.6b + 1.7b embeddings

## Key Documentation

| Need | Read |
|------|------|
| Architecture & data flow | [Docs/architecture.md](Docs/architecture.md) |
| How .vox files are created | [Docs/vox-pipeline.md](Docs/vox-pipeline.md) |
| Full API reference | [Docs/api.md](Docs/api.md) |
| Build, test, CI/CD | [Docs/build-and-test.md](Docs/build-and-test.md) |
| All dependencies | [Docs/dependencies.md](Docs/dependencies.md) |
| Common pitfalls | [Docs/gotchas.md](Docs/gotchas.md) |

---

**Last Updated**: October 22, 2026 (3.0.0-dev: voices in the character record, `EchadaVoice`, `migrate voices`, `sample`; `generate cast` removed — see REQUIREMENTS.md, REQUIREMENTS-personaje.md)
