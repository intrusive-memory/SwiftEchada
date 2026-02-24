# CLAUDE.md

**Read [AGENTS.md](AGENTS.md) first** for universal project documentation, architecture, and development guidelines.
**See [API.md](API.md)** for complete public API reference with type signatures.

This file contains instructions specific to Claude Code agents working on SwiftEchada.

---

## Quick Reference

**Project**: SwiftEchada - AI-powered cast management for screenplay projects

**Platforms**: iOS 26.0+, macOS 26.0+

**Key Components**:
- Data types for character profiles and voice descriptions (library)
- On-device voice generation from text prompts via VoxAlta/Qwen3-TTS (CLI)
- Character deduplication and merging (library)
- `echada` CLI with `cast`, `voice`, and `test-voice` commands

---

## Claude-Specific Build Preferences

**CRITICAL**: Always use the **Makefile** (`make build`, `make test`, etc.) for builds. The project requires `xcodebuild` for ALL build and test operations due to Metal shader dependencies in SwiftVoxAlta. Never use `swift build` or `swift test`.

See [AGENTS.md](AGENTS.md) § Build and Test for complete build instructions.

---

## MCP Server Configuration

### XcodeBuildMCP

**Status**: Available globally but not required for this project

XcodeBuildMCP provides structured Swift package operations. While available, the Makefile (documented in AGENTS.md) is preferred for SwiftEchada.

**Available Operations** (if needed):
- `swift_package_build` - Build Swift package
- `swift_package_test` - Run Swift package tests
- `swift_package_clean` - Clean build artifacts

### App Store Connect MCP

**Status**: Not applicable (SwiftEchada is a library, not an app)

---

## Claude-Specific Critical Rules

1. **ALWAYS use Makefile or `xcodebuild`** - NEVER `swift build` or `swift test`
2. **Test scheme is `SwiftEchada-Package`** - NOT `SwiftEchada` (see AGENTS.md)
3. **Use `GIT_LFS_SKIP_SMUDGE=1`** - When building outside the Makefile
4. **Targeted imports in CLI** - Use `import struct SwiftEchada.CharacterProfile` (not `import SwiftEchada`) to avoid module/type name collision
5. **Library depends only on SwiftProyecto** - All ML/voice deps are CLI-only
6. **No LLM in the library** - The library has no ML dependencies; voice generation is prompt-based in the CLI
7. **Default subcommand is `cast`** - Not `extract` (which was removed)

---

## Project-Specific Notes

- SwiftEchada is a **library**, not an app (no Xcode project, no App Store distribution)
- Distributed via **Homebrew** (`brew install intrusive-memory/tap/echada`)
- **On-device voice generation** via SwiftVoxAlta (Qwen3-TTS)
- **Strict concurrency** - Swift 6 language mode, `Sendable` throughout
- **Multi-model .vox support** - Single .vox file can contain 0.6b and 1.7b embeddings

---

**Last Updated**: February 24, 2026 (v0.9.4)
