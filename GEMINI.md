# GEMINI.md

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation, architecture, and development guidelines.

This file contains instructions specific to Google Gemini agents working on SwiftEchada.

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

## Gemini-Specific Configuration

**Build Tools**: Standard `xcodebuild` commands (no MCP access)

**Test Strategy**: Use `xcodebuild test` with `-scheme SwiftEchada-Package`

---

## Build and Test Commands

**CRITICAL**: This project requires `xcodebuild` for ALL build and test operations due to Metal shader dependencies in SwiftBruja.

### Build Library

```bash
GIT_LFS_SKIP_SMUDGE=1 xcodebuild \
  -scheme SwiftEchada \
  -destination 'platform=macOS,arch=arm64' \
  build
```

### Run Tests

```bash
GIT_LFS_SKIP_SMUDGE=1 xcodebuild \
  -scheme SwiftEchada-Package \
  -destination 'platform=macOS,arch=arm64' \
  test
```

**Important**: Use `-scheme SwiftEchada-Package` for tests, NOT `-scheme SwiftEchada`.

### Build CLI Executable

```bash
GIT_LFS_SKIP_SMUDGE=1 xcodebuild \
  -scheme echada \
  -destination 'platform=macOS,arch=arm64' \
  build
```

Binary location: `DerivedData/SwiftEchada-*/Build/Products/Debug/echada`

---

## Gemini-Specific Critical Rules

1. **Use standard `xcodebuild` commands** - No MCP access; follow commands above
2. **NEVER use `swift build` or `swift test`** - Metal shader requirement makes these fail
3. **Always use `GIT_LFS_SKIP_SMUDGE=1`** - Avoid pulling large model files from dependencies
4. **Test scheme is `SwiftEchada-Package`** - NOT `SwiftEchada` (see AGENTS.md)
5. **Follow Xcode best practices** - Standard iOS/macOS development patterns

---

## CI/CD Integration

For GitHub Actions workflows:

```yaml
- name: Build and Test
  run: |
    GIT_LFS_SKIP_SMUDGE=1 xcodebuild \
      -scheme SwiftEchada-Package \
      -destination 'platform=macOS,arch=arm64' \
      test
```

**Requirements**:
- Runner: `macos-26` or later
- Swift: 6.2+
- Xcode: Latest stable

See [AGENTS.md](AGENTS.md) for complete build requirements.

---

## Future Gemini Integrations

**Placeholder for**:
- Gemini API integration patterns (if applicable)
- Gemini Code Assist workflows (if configured)
- Custom Gemini-specific automation (TBD)

---

**Last Updated**: February 21, 2026 (v0.9.2)
