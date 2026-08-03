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
4. **Library depends only on SwiftReparto** — a leaf package with no `intrusive-memory` dependencies, which owns the `CAST.md` schema (`CastMember`, `Gender`, `CastDocument`, `CastMarkdownParser`). The real invariant: **no ML/voice dependencies in the library target**; those belong to `EchadaCLICore`, which also keeps SwiftProyecto for project-level `PROJECT.md` fields (`title`, `episodesDir`, `filePattern`, `tts.model`).
5. **Ownership split**: `PROJECT.md` is SwiftProyecto's config file; `CAST.md` is SwiftReparto's. All generate stages read and write the cast roster in `CAST.md`. `PROJECT.md`'s legacy `cast:` block is read-only (via `LegacyProjectCastReader`, for seeding/verification) — nothing writes it except `echada prune cast`, which excises it.
6. **No default subcommand** — bare `echada` prints help. `echada cast` runs the full pipeline (bootstrap PROJECT.md + CAST.md → `generate cast` → `generate prompt` → `generate vox`), not just `.vox` generation. Individual stages live under `echada generate {cast,prompt,vox}`; the migration gates live at `echada verify cast` (read-only) and `echada prune cast` (explicit removal). `extract` and the standalone `prompt` command were removed (hard-cut, v0.16.0).

## MCP Servers

### XcodeBuildMCP
Available globally but the Makefile is preferred. Use `swift_package_build`/`swift_package_test` only if the Makefile isn't working.

### App Store Connect MCP
Not applicable -- SwiftEchada is a library, not an app.

## Project Context

- SwiftEchada is a **library + CLI**, not an app. No Xcode project.
- Distributed via **Homebrew** (`brew install intrusive-memory/tap/echada`)
- **On-device voice generation** via SwiftVoxAlta (Qwen3-TTS)
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

**Last Updated**: August 3, 2026 (v1.0.0, CAST.md extraction)
