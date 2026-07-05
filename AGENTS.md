---
type: project
---

# AGENTS.md

Universal project documentation for AI agents. Agent-specific files: [CLAUDE.md](CLAUDE.md), [GEMINI.md](GEMINI.md).

**Version**: 0.16.0-dev | **Swift**: 6.2 | **Platforms**: macOS 26+, iOS 26+

---

## What Is This?

SwiftEchada generates on-device custom voices from text prompts and manages cast data in PROJECT.md files for screenplay projects.

- **Library** (`SwiftEchada`): Pure data types -- `CharacterProfile`, `CharacterInfo`, `CharacterMerger`. Depends only on SwiftProyecto. No ML.
- **CLI** (`echada`): Voice generation via Qwen3-TTS. Depends on SwiftVoxAlta, MLX, vox-format.

## Build and Test (30-second version)

```bash
make build   # Debug build
make test    # Unit tests (32 tests)
make clean   # Clean artifacts
```

**Never use `swift build` or `swift test`** -- Metal shaders require xcodebuild. The Makefile handles everything.

Full details: [Docs/build-and-test.md](Docs/build-and-test.md)

## CLI Commands

| Command | Description |
|---------|-------------|
| `echada cast` (default) | Full pipeline: bootstrap PROJECT.md (if absent) → `generate cast` → `generate prompt` → `generate vox`. Idempotent; single cascading `--force`. |
| `echada generate cast` | Heuristically discover cast members from the screenplay source (no LLM) and merge into PROJECT.md's `cast:` list |
| `echada generate prompt` | Examine the screenplay source material and write a `voicePrompt` for each cast member in PROJECT.md, via the on-device Foundation Model |
| `echada generate vox` | Generate `.vox` voice identities for all cast members from their `voicePrompt` in PROJECT.md — this is what `echada cast` used to do before the restructure |
| `echada voice <prompt>` | Generate a single `.vox` from a text description (no PROJECT.md required) |
| `echada test-voice` (hidden) | Integration test helper — fixed NARRATOR profile |

Typical flow: `echada cast` runs the whole pipeline in one step, or run each
stage standalone in order — `echada generate cast` (scripts → cast list) →
`echada generate prompt` (cast list → voice briefs) → `echada generate vox`
(briefs → `.vox`).

**Breaking change (v0.16.0):** the old standalone `echada prompt` was removed
(use `echada generate prompt`); the old `.vox`-only `echada cast` is now
`echada generate vox`; bare `echada cast` is repurposed to run the full
pipeline. No back-compat alias — see [CHANGELOG.md](CHANGELOG.md).

Full CLI reference: [Docs/api.md](Docs/api.md#cli-echada)

## Architecture at a Glance

```
Library:  SwiftEchada --> SwiftProyecto (pure data types, no ML)
CLI:      echada --> SwiftEchada + SwiftVoxAlta + MLX + vox-format
```

Voice generation uses a **two-phase pipeline** to avoid GPU OOM:
1. **Phase A**: VoiceDesign 1.7B generates candidate WAVs
2. **Phase B**: Base model creates voice locks and exports .vox bundles

Full architecture: [Docs/architecture.md](Docs/architecture.md)
| .vox pipeline detail: [Docs/vox-pipeline.md](Docs/vox-pipeline.md)

## Queryable Codemap

A prebuilt [graphify](https://pypi.org/project/graphifyy/) knowledge graph of this
codebase lives in [`graphify-out/`](graphify-out/) — 322 nodes · 524 edges across 14
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
3. **Targeted imports in CLI** -- `import struct SwiftEchada.CharacterProfile` (module/type name collision)
4. **Library has no ML deps** -- all voice generation is CLI-only
5. **Default subcommand is `cast`** -- `extract` and `download` were removed

More: [Docs/gotchas.md](Docs/gotchas.md)
