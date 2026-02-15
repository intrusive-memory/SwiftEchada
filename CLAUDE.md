# CLAUDE.md

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation, architecture, and development guidelines.

This file contains instructions specific to Claude Code agents working on SwiftEchada.

---

## Quick Reference

**Project**: SwiftEchada - AI-powered cast management for screenplay projects

**Platforms**: iOS 26.0+, macOS 26.0+

**Key Components**:
- Character extraction from screenplay files via LLM
- Cast-to-voice matching via LLM
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

**Usage Pattern** (optional):
```swift
// Alternative to direct xcodebuild commands
swift_package_test(
  packagePath: "/Users/stovak/Projects/SwiftEchada",
  scheme: "SwiftEchada-Package"
)
```

### App Store Connect MCP

**Status**: Not applicable (SwiftEchada is a library, not an app)

---

## Global Claude Settings

Your global Claude instructions are located at `~/.claude/CLAUDE.md`.

**Key patterns relevant to SwiftEchada**:
- **Communication Style**: Complete candor (flag ill-advised decisions directly)
- **Security**: NEVER expose secrets, API keys, or credentials
- **Swift Build Preference**: ALWAYS use `xcodebuild` (aligns with SwiftEchada's Metal shader requirement)
- **GitHub Actions CI/CD**: Use `macos-26` or later, Swift 6.2+, exact iOS simulator versions

---

## Claude-Specific Critical Rules

1. **ALWAYS use `xcodebuild`** - NEVER `swift build` or `swift test` (Metal shader requirement)
2. **Test scheme is `SwiftEchada-Package`** - NOT `SwiftEchada` (see AGENTS.md)
3. **Use `GIT_LFS_SKIP_SMUDGE=1`** - When building to avoid pulling large SwiftHablare models
4. **Follow global CLAUDE.md patterns** - Communication, security, CI/CD best practices
5. **Leverage MCP servers when appropriate** - XcodeBuildMCP available but optional for this project

---

## Project-Specific Notes

- SwiftEchada is a **library**, not an app (no Xcode project, no App Store distribution)
- Distributed via **Homebrew** (`brew install intrusive-memory/tap/echada`)
- **Multi-provider voice support** - Apple, ElevenLabs, and SwiftVoxAlta (on-device, as of v0.9.1)
- **Strict concurrency** - Swift 6 language mode, actor-based patterns throughout

---

**Last Updated**: February 14, 2026 (v0.9.1)
