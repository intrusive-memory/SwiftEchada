---
type: reference
---

# Dependencies

---

## Dependency Graph

```
SwiftEchada (library)
└── SwiftReparto (0.2.0+)          ← CAST.md schema, canonicalName. A leaf: no intrusive-memory deps.

EchadaVoice (voice library an app links — no ArgumentParser, no PROJECT.md reader)
├── SwiftEchada (library)
├── SwiftReparto (0.2.0+)          ← manifest:, canonicalName (EC-23, EC-24)
├── SwiftVoxAlta (0.14.2+)
├── mlx-swift, mlx-swift-lm, mlx-audio-swift
└── vox-format (0.4.1+)

EchadaCLICore (CLI library) / echada (executable)
├── EchadaVoice
├── SwiftEchada (library)
├── SwiftReparto (0.2.0+)
├── SwiftProyecto (5.3.2+)         ← PROJECT.md only: title, episodesDir, filePattern, tts.model
├── SwiftVoxAlta (0.14.2+)
│   └── vox-format, mlx-audio-swift, mlx-swift (transitive)
├── SwiftLlavero (0.1.0-beta.2, 0.1.x) ← --llm models + `echada auth` credentials
│   └── ClaudeForFoundationModels, firebase-ios-sdk (transitive)
├── swift-argument-parser (1.7.1+)
├── Yams (6.2.2+)                  ← PROJECT.md `personaje:` block (charactersDir)
├── mlx-swift (0.31.3+)
├── mlx-swift-lm (3.31.3+)
├── mlx-audio-swift (0.10.0+)
└── vox-format (0.4.1+)
```

**The ownership split (v1.0.0)**: SwiftReparto owns `CAST.md` (schema, parser,
serializer) and is the library target's **only** dependency. SwiftProyecto owns
`PROJECT.md` and left the library target entirely — it survives on
`EchadaCLICore` alone, for project-level configuration fields. Because
SwiftReparto declares no dependency on any `intrusive-memory` package, no
package cycle involving cast data is possible by construction.

---

## Package Details

### Library Dependencies

| Package | Pin | Purpose | Key Types |
|---------|-----|---------|-----------|
| [SwiftReparto](https://github.com/intrusive-memory/SwiftReparto) | `from: "0.2.0"` | CAST.md schema, parse, serialize; canonical names | `CastMember` (`manifest`, `role`, `canonicalName`), `Gender`, `CastDocument`, `CastMarkdownParser`, `ProjectCastImporter` |

### CLI-Only Dependencies

| Package | Pin | Purpose | Key Types |
|---------|-----|---------|-----------|
| [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto) | `from: "5.3.2"` | PROJECT.md parsing (project-level fields only) and the migration rewrite | `ProjectMarkdownParser`, `ProjectFrontMatter`, `ProjectService` |
| [SwiftVoxAlta](https://github.com/intrusive-memory/SwiftVoxAlta) | `from: "0.14.2"` | On-device voice generation | `VoxAltaModelManager`, `VoiceLockManager`, `VoxExporter`, `Qwen3TTSModelRepo` |
| [SwiftLlavero](https://github.com/intrusive-memory/SwiftLlavero) | `upToNextMinor(from: "0.1.0-beta.2")` | The `--llm` model (on-device, PCC, Claude, OpenAI-compatible, Gemini) and `echada auth` (Keychain credentials shared across tools). Beta: pinned to 0.1.x | `Llavero`, `ModelReference`, `LlaveroAuthCommand` |
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | `from: "1.7.1"` | CLI argument parsing (`EchadaCLICore` only, never `EchadaVoice`) | `AsyncParsableCommand`, `CommandConfiguration` |
| [Yams](https://github.com/jpsim/Yams) | `from: "6.2.2"` | PROJECT.md `personaje:` block, `samples.yaml`, CHARACTER.md `sampleLine` | `YAMLDecoder` |
| [mlx-swift](https://github.com/ml-explore/mlx-swift) | `from: "0.31.3"` | MLX framework (GPU compute) | `MLXArray`, `Stream`, `Memory` |
| [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) | `from: "3.31.3"` | Language model commons | `GenerateParameters` |
| [mlx-audio-swift](https://github.com/intrusive-memory/mlx-audio-swift) | `from: "0.10.0"` | Qwen3-TTS voice synthesis | `Qwen3TTSModel`, `AudioConversion` |
| [vox-format](https://github.com/intrusive-memory/vox-format) | `from: "0.4.1"` | .vox archive format | `VoxFile`, `VoxManifest`, `VoxManifest.Provenance` |

All pins are `.upToNextMajor` semver ranges — no `branch:` pins remain in the
manifest. `mlx-audio-swift` is kept in lockstep with the range SwiftVoxAlta
declares; bump both together when SwiftVoxAlta adopts a newer mlx-audio-swift
line.

---

## Sibling Repos (Local Development)

For integration tests and cross-repo development:

| Repo | Expected Path | Used By |
|------|--------------|---------|
| vox-format | `../../../vox-format` (`~/Projects/vox-format`) | `make integration-test` (vox CLI validator) |
| SwiftVoxAlta | `../SwiftVoxAlta` | `make integration-test` (diga CLI synthesizer) |

---

## Key Types from Dependencies

### From SwiftReparto (library + CLI)

- **`CastMember`**: Struct with `character`, `actor?`, `gender?`, `language?`,
  `voicePrompt?` (legacy alias `voiceDescription` still decodes),
  `voices: [String: [String]]`, and `extraKeys` (undeclared per-member keys such
  as `bio:` or the reserved `appearance.portrait`, preserved verbatim)
- **`Gender`**: Enum (`.male`, `.female`, `.nonBinary`, `.notSpecified`) —
  `CharacterProfile.gender`'s type since the CAST.md extraction
- **`CastDocument`**: `type: cast` front matter + `cast: [CastMember]` + opaque
  markdown body (re-emitted byte-for-byte)
- **`CastMarkdownParser`**: Parses a CAST.md into a `CastDocument`
- **`CastMarkdownGenerator`**: The **only** CAST.md serializer anywhere — no
  consumer builds YAML or splices text
- **`ProjectCastImporter`**: Decodes a legacy `cast:` block out of a PROJECT.md
  (used via `EchadaCLICore`'s `LegacyProjectCastReader`, read-only)

### From SwiftProyecto (CLI only)

- **`ProjectMarkdownParser`**: Parses PROJECT.md frontmatter + body
- **`ProjectFrontMatter`**: Decoded YAML frontmatter — `title`, `episodesDir`,
  `filePattern`, `tts` config. Since 5.0 it no longer models `cast:`; echada
  reads an old block through `LegacyProjectCastReader` → SwiftReparto and
  removes it with `removingCastBlock(in:)` during automatic migration
- **`ProjectService`**: Directory analysis for PROJECT.md bootstrap

### From SwiftVoxAlta

- **`VoxAltaModelManager`**: Loads/unloads Qwen3-TTS models (manages GPU memory)
- **`VoiceLockManager`**: Creates voice locks (speaker embeddings) from candidate audio
- **`VoxExporter`**: Static methods to add clone prompts and sample audio to VoxFile
- **`Qwen3TTSModelRepo`**: Enum of model repos (`.voiceDesign1_7B`, `.base0_6B`, `.base1_7B`)

### From vox-format

- **`VoxFile`**: Mutable class -- zip archive container for voice data
- **`VoxManifest`**: JSON manifest inside .vox with name, description, provenance, paths
- **`VoxManifest.Provenance`**: Metadata about how the voice was created
