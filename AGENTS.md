# AGENTS.md

Universal project documentation for AI agents. Agent-specific files: [CLAUDE.md](CLAUDE.md), [GEMINI.md](GEMINI.md).

**Version**: 0.10.0 | **Swift**: 6.2 | **Platforms**: macOS 26+, iOS 26+

---

## What Is This?

SwiftEchada generates on-device custom voices from text prompts and manages cast data in PROJECT.md files for screenplay projects.

- **Library** (`SwiftEchada`): Pure data types -- `CharacterProfile`, `CharacterInfo`, `CharacterMerger`, `SampleSentenceGenerator`. Depends only on SwiftProyecto. No ML.
- **CLI** (`echada`): Voice generation via Qwen3-TTS. Depends on SwiftVoxAlta, MLX, vox-format.

## Build and Test (30-second version)

```bash
make build   # Debug build
make test    # Unit tests (31 tests)
make clean   # Clean artifacts
```

**Never use `swift build` or `swift test`** -- Metal shaders require xcodebuild. The Makefile handles everything.

Full details: [Docs/build-and-test.md](Docs/build-and-test.md)

## CLI Commands

| Command | Description |
|---------|-------------|
| `echada cast` (default) | Generate voices for all cast members from PROJECT.md |
| `echada voice <prompt>` | Generate a single .vox from a text description |
| `echada test-voice` (hidden) | Integration test helper |

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
