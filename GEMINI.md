# GEMINI.md

**Read [AGENTS.md](AGENTS.md) first** for project overview. Deep dives in [Docs/](Docs/).

---

## Gemini-Specific Rules

1. **No MCP access** -- use raw `xcodebuild` commands or the Makefile.
2. **Never use `swift build` or `swift test`** -- Metal shaders require xcodebuild.
3. **Always set `GIT_LFS_SKIP_SMUDGE=1`** before xcodebuild commands.
4. **Test scheme is `SwiftEchada-Package`**, not `SwiftEchada`.

## Build Commands

```bash
# Preferred: use the Makefile
make build            # Debug build
make test             # Run unit tests
make clean            # Clean artifacts

# Raw xcodebuild (if Makefile unavailable)
GIT_LFS_SKIP_SMUDGE=1 xcodebuild -scheme echada -destination 'platform=macOS,arch=arm64' build
GIT_LFS_SKIP_SMUDGE=1 xcodebuild test -scheme SwiftEchada-Package -destination 'platform=macOS,arch=arm64'
```

Binary location after build: `DerivedData/SwiftEchada-*/Build/Products/Debug/echada`

## CI/CD

```yaml
runs-on: macos-26    # Always macos-26 or later
```

```bash
GIT_LFS_SKIP_SMUDGE=1 xcodebuild test \
  -scheme SwiftEchada-Package \
  -destination 'platform=macOS,arch=arm64'
```

See [Docs/build-and-test.md](Docs/build-and-test.md) for full CI/CD details.

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

**Last Updated**: February 28, 2026 (v0.10.0)
