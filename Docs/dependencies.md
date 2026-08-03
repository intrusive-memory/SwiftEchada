---
type: reference
---

# Dependencies

---

## Dependency Graph

```
SwiftEchada (library)
└── SwiftReparto (0.1.0+)          ← CAST.md schema. A leaf: no intrusive-memory deps.

EchadaCLICore (CLI library) / echada (executable)
├── SwiftEchada (library)
├── SwiftReparto (0.1.0+)
├── SwiftProyecto (4.8.1+)         ← PROJECT.md only: title, episodesDir, filePattern, tts.model
├── SwiftVoxAlta (0.14.1+)
│   └── vox-format, mlx-audio-swift, mlx-swift (transitive)
├── swift-argument-parser (1.7.1+)
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
| [SwiftReparto](https://github.com/intrusive-memory/SwiftReparto) | `from: "0.1.0"` | CAST.md schema, parse, serialize | `CastMember`, `Gender`, `CastDocument`, `CastMarkdownParser`, `CastMarkdownGenerator`, `ProjectCastImporter` |

### CLI-Only Dependencies

| Package | Pin | Purpose | Key Types |
|---------|-----|---------|-----------|
| [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto) | `from: "4.8.1"` | PROJECT.md parsing (project-level fields only) | `ProjectMarkdownParser`, `ProjectFrontMatter`, `ProjectService` |
| [SwiftVoxAlta](https://github.com/intrusive-memory/SwiftVoxAlta) | `from: "0.14.1"` | On-device voice generation | `VoxAltaModelManager`, `VoiceLockManager`, `VoxExporter`, `Qwen3TTSModelRepo` |
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | `from: "1.7.1"` | CLI argument parsing | `AsyncParsableCommand`, `CommandConfiguration` |
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
  `filePattern`, `tts` config. Its `cast` model is legacy: `echada` never reads
  cast through it (that goes through `LegacyProjectCastReader` → SwiftReparto)
  and never writes it (except `prune cast`'s surgical excision)
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
