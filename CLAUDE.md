# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

For detailed project documentation, architecture, and development guidelines, see **[AGENTS.md](AGENTS.md)**.

## Quick Reference

**Project**: SwiftEchada - AI-powered cast management for screenplay projects

**Platforms**: iOS 26.0+, macOS 26.0+

**Key Components**:
- Character extraction from screenplay files via LLM
- Cast-to-voice matching via LLM
- Character deduplication and merging
- `echada` CLI for cast management

**Important Notes**:
- ONLY supports iOS 26.0+ and macOS 26.0+ (NEVER add code for older platforms)
- `echada` CLI MUST be built with `xcodebuild`, NOT `swift build` (requires Metal shaders)
- See [AGENTS.md](AGENTS.md) for complete development workflow, architecture, and integration patterns
