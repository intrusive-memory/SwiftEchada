# CLAUDE.md

**Read [AGENTS.md](AGENTS.md) first** for project overview. Deep dives in [Docs/](Docs/).

---

## Claude-Specific Rules

1. **Always use the Makefile** (`make build`, `make test`). Never `swift build` or `swift test`. See [Docs/build-and-test.md](Docs/build-and-test.md).
2. **Test scheme is `SwiftEchada-Package`**, not `SwiftEchada`.
3. **Targeted imports in CLI files**: `import struct SwiftEchada.CharacterProfile` -- not `import SwiftEchada`. See [Docs/gotchas.md](Docs/gotchas.md#moduletype-name-collision).
4. **Library depends only on SwiftProyecto**. All ML/voice deps are CLI-only.
5. **Default subcommand is `cast`**, not `extract` (removed).

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

**Last Updated**: February 28, 2026 (v0.10.1)
