---
type: project
---

# AGENTS.md

Universal project documentation for AI agents. Agent-specific files: [CLAUDE.md](CLAUDE.md), [GEMINI.md](GEMINI.md).

**Version**: 2.0.0-dev | **Swift**: 6.2 | **Platforms**: macOS 26+, iOS 26+

---

## What Is This?

SwiftEchada generates on-device custom voices from text prompts and manages cast data in CAST.md files for screenplay projects.

**Ownership split (v2.0.0)**: `PROJECT.md` is [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto)'s config file (project identity, episode discovery, `tts` config). `CAST.md` is [SwiftReparto](https://github.com/intrusive-memory/SwiftReparto)'s config file (cast roster, voice prompts, voice pointers). SwiftEchada is a consumer of both: it creates voice assets and records where they went — in `CAST.md`. An older `PROJECT.md` that still holds a `cast:` block is migrated automatically the first time any generate stage opens it: the roster moves into `CAST.md`, every character is checked, the original is saved as `PROJECT.md.bak`, and the `cast:` block is removed and `schemaVersion: 5` stamped.

- **Library** (`SwiftEchada`): Pure data types -- `CharacterProfile`, `CharacterInfo`, `CharacterMerger`. Depends only on SwiftReparto (a leaf package: `CastMember`, `Gender`, `CastDocument`, `CastMarkdownParser`). No ML.
- **CLI** (`echada` / `EchadaCLICore`): Voice generation via Qwen3-TTS. Depends on SwiftVoxAlta, MLX, vox-format — and keeps SwiftProyecto for project-level `PROJECT.md` fields (`title`, `episodesDir`, `filePattern`, `tts.model`).

## Build and Test (30-second version)

```bash
make build   # Debug build
make test    # Unit tests (138 tests)
make clean   # Clean artifacts
```

**Never use `swift build` or `swift test`** -- Metal shaders require xcodebuild. The Makefile handles everything.

Full details: [Docs/build-and-test.md](Docs/build-and-test.md)

## CLI Commands

| Command | Description |
|---------|-------------|
| `echada` (no subcommand) | Prints help. There is **no** default subcommand — invoke a command explicitly. |
| `echada cast` | Full pipeline: bootstrap PROJECT.md and CAST.md (if absent) → `generate cast` → `generate prompt` → `generate vox`. Idempotent; single cascading `--force`. |
| `echada generate cast` | Heuristically discover cast members from the screenplay source (no LLM) and merge into the CAST.md roster (an older PROJECT.md is first migrated into CAST.md) |
| `echada generate prompt` | Examine the screenplay source material and write a `voicePrompt` for each cast member in CAST.md, via the on-device Foundation Model |
| `echada generate vox` | Generate `.vox` voice identities for all cast members from their `voicePrompt` in CAST.md — this is what `echada cast` used to do before the restructure |
| `echada voice <prompt>` | Generate a single `.vox` from a text description (no PROJECT.md/CAST.md required) |
| `echada test-voice` (hidden) | Integration test helper — fixed NARRATOR profile |

All `cast`-touching commands take `--cast <filename>` (default `CAST.md`) — a
bare filename resolved beside `--project`, never a path.

Typical flow: `echada cast` runs the whole pipeline in one step, or run each
stage standalone in order — `echada generate cast` (scripts → CAST.md roster) →
`echada generate prompt` (roster → voice briefs) → `echada generate vox`
(briefs → `.vox`). Older projects migrate on first contact; there is no
separate migration command.

**Breaking change (v2.0.0):** `echada verify cast` and `echada prune cast` were
removed. Migration off a legacy `PROJECT.md` `cast:` block is now automatic.

**Breaking change (v0.16.0):** the old standalone `echada prompt` was removed
(use `echada generate prompt`); the old `.vox`-only `echada cast` is now
`echada generate vox`; `echada cast` is repurposed to run the full pipeline.
No back-compat alias — see [CHANGELOG.md](CHANGELOG.md). Bare `echada` (no
subcommand) prints help rather than running a command.

Full CLI reference: [Docs/api.md](Docs/api.md#cli-echada)

## Architecture at a Glance

```
Library:  SwiftEchada --> SwiftReparto (CAST.md schema; pure data types, no ML)
CLI:      echada --> EchadaCLICore --> SwiftEchada + SwiftReparto + SwiftProyecto + SwiftVoxAlta + MLX + vox-format
```

SwiftReparto is a leaf (no `intrusive-memory` deps) and is the **only** writer
of `CAST.md` — consumers mutate a `CastDocument` and hand it back. SwiftProyecto
appears only in `EchadaCLICore`, for project-level `PROJECT.md` fields.

Voice generation uses a **two-phase pipeline** to avoid GPU OOM:
1. **Phase A**: VoiceDesign 1.7B generates candidate WAVs
2. **Phase B**: Base model creates voice locks and exports .vox bundles

Full architecture: [Docs/architecture.md](Docs/architecture.md)
| .vox pipeline detail: [Docs/vox-pipeline.md](Docs/vox-pipeline.md)

## Queryable Codemap

A prebuilt [graphify](https://pypi.org/project/graphifyy/) knowledge graph of this
codebase lives in [`graphify-out/`](graphify-out/) — 843 nodes · 1411 edges across 59
communities, mapping how the library, CLI, tests, and fixtures connect. **Prefer
querying it before grepping** when answering architecture or "what connects to what"
questions:

```bash
graphify query "How does cast voice generation flow from CLI to .vox?"
graphify path "CastCommand" "VoxFile"      # shortest path between two nodes
graphify explain "decideVoxGeneration"     # plain-language node explanation
```

- Human-readable summary (god nodes, communities, surprising edges): [`graphify-out/GRAPH_REPORT.md`](graphify-out/GRAPH_REPORT.md)
- Interactive visualization: `graphify-out/graph.html` · GraphRAG JSON: `graphify-out/graph.json`
- Rebuild after significant changes: `graphify . --update`

## Deep Dives

| Document | Contents |
|----------|----------|
| [Docs/architecture.md](Docs/architecture.md) | Module graph, source layout, data flow diagrams |
| [Docs/vox-pipeline.md](Docs/vox-pipeline.md) | Step-by-step .vox creation process |
| [Docs/api.md](Docs/api.md) | Complete public API with Swift type signatures |
| [Docs/build-and-test.md](Docs/build-and-test.md) | Makefile, testing, CI/CD, release process |
| [Docs/dependencies.md](Docs/dependencies.md) | All packages, pins, key types from each |
| [Docs/gotchas.md](Docs/gotchas.md) | Sharp edges that will trip you up |

## Critical Rules (All Agents)

1. **Use the Makefile** -- `make build`, `make test`, never `swift build`/`swift test`
2. **Test scheme is `SwiftEchada-Package`** -- not `SwiftEchada`
3. **Targeted imports in CLI** -- `import struct SwiftEchada.CharacterProfile` (module/type name collision); fully qualify `SwiftReparto.CastMember` in files that also import SwiftProyecto (see [Docs/gotchas.md](Docs/gotchas.md))
4. **Library depends only on SwiftReparto, no ML deps** -- all voice generation is CLI-only; SwiftProyecto is CLI-only too
5. **CAST.md is the cast roster** -- generate stages read/write CAST.md; an older PROJECT.md's `cast:` block is migrated into CAST.md automatically (see `ProjectMigration`)
6. **No default subcommand** -- bare `echada` prints help; run `echada cast` for the full pipeline. `extract` and `download` were removed

More: [Docs/gotchas.md](Docs/gotchas.md)
