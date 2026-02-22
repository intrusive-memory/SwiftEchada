# CLAUDE.md

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation, architecture, and development guidelines.

This file contains instructions specific to Claude Code agents working on SwiftEchada.

---

## Quick Reference

**Project**: SwiftEchada - AI-powered cast management for screenplay projects

**Platforms**: iOS 26.0+, macOS 26.0+

**Key Components**:
- Character extraction from screenplay files via LLM
- On-device voice generation via VoxAlta (Qwen3-TTS)
- Character deduplication and merging
- `echada` CLI for cast management

---

## Claude-Specific Build Preferences

**CRITICAL**: This project requires `xcodebuild` for ALL build and test operations due to Metal shader dependencies in SwiftBruja. This is a **universal requirement**, not just a Claude preference.

See [AGENTS.md](AGENTS.md) § Build and Test for complete build instructions.

---

## MCP Server Configuration

### XcodeBuildMCP

**Status**: Available globally but not required for this project

XcodeBuildMCP provides structured Swift package operations. While available, standard xcodebuild commands (documented in AGENTS.md) work well for SwiftEchada.

**Available Operations** (if needed):
- `swift_package_build` - Build Swift package
- `swift_package_test` - Run Swift package tests
- `swift_package_clean` - Clean build artifacts

### App Store Connect MCP

**Status**: Not applicable (SwiftEchada is a library, not an app)

---

## Claude-Specific Critical Rules

1. **ALWAYS use `xcodebuild`** - NEVER `swift build` or `swift test` (Metal shader requirement)
2. **Test scheme is `SwiftEchada-Package`** - NOT `SwiftEchada` (see AGENTS.md)
3. **Use `GIT_LFS_SKIP_SMUDGE=1`** - When building to avoid pulling large model files
4. **Follow global CLAUDE.md patterns** - Communication, security, CI/CD best practices
5. **Targeted imports in CLI** - Use `import struct SwiftEchada.CharacterProfile` (not `import SwiftEchada`) to avoid module/type name collision
6. **Library depends only on SwiftProyecto** - All ML/voice deps are CLI-only

---

## Project-Specific Notes

- SwiftEchada is a **library**, not an app (no Xcode project, no App Store distribution)
- Distributed via **Homebrew** (`brew install intrusive-memory/tap/echada`)
- **On-device voice generation** via SwiftVoxAlta (Qwen3-TTS)
- **Strict concurrency** - Swift 6 language mode, actor-based patterns throughout

---

**Last Updated**: February 22, 2026 (v0.9.2)
