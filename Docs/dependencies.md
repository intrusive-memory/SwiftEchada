# Dependencies

---

## Dependency Graph

```
SwiftEchada (library)
└── SwiftProyecto (branch: development)

echada (CLI executable)
├── SwiftEchada (library)
├── SwiftVoxAlta (branch: development)
│   └── vox-format, mlx-audio-swift, mlx-swift (transitive)
├── swift-argument-parser (1.3.0+)
├── mlx-swift (0.21.0+)
├── mlx-swift-lm (branch: main)
├── mlx-audio-swift (branch: development)
└── vox-format (0.3.0+)
```

---

## Package Details

### Library Dependencies

| Package | Pin | Purpose | Key Types |
|---------|-----|---------|-----------|
| [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto) | `branch: development` | PROJECT.md parsing, cast management | `Gender`, `CastMember`, `ProjectMarkdownParser`, `ProjectFrontMatter` |

### CLI-Only Dependencies

| Package | Pin | Purpose | Key Types |
|---------|-----|---------|-----------|
| [SwiftVoxAlta](https://github.com/intrusive-memory/SwiftVoxAlta) | `branch: development` | On-device voice generation | `VoxAltaModelManager`, `VoiceLockManager`, `VoxExporter`, `Qwen3TTSModelRepo` |
| [swift-argument-parser](https://github.com/apple/swift-argument-parser) | `from: "1.3.0"` | CLI argument parsing | `AsyncParsableCommand`, `CommandConfiguration` |
| [mlx-swift](https://github.com/ml-explore/mlx-swift) | `from: "0.21.0"` | MLX framework (GPU compute) | `MLXArray`, `Stream`, `Memory` |
| [mlx-swift-lm](https://github.com/ml-explore/mlx-swift-examples) | `branch: main` | Language model commons | `GenerateParameters` |
| [mlx-audio-swift](https://github.com/intrusive-memory/mlx-audio-swift) | `branch: development` | Qwen3-TTS voice synthesis | `Qwen3TTSModel`, `AudioConversion` |
| [vox-format](https://github.com/intrusive-memory/vox-format) | `from: "0.3.0"` | .vox archive format | `VoxFile`, `VoxManifest`, `VoxManifest.Provenance` |

---

## Branch Pins vs Semver

Several dependencies use `branch:` pins instead of semver because they're in active development:

| Package | Pin Type | Reason |
|---------|----------|--------|
| SwiftProyecto | `branch: development` | Co-developed; API evolving |
| SwiftVoxAlta | `branch: development` | Co-developed; API evolving |
| mlx-swift-lm | `branch: main` | No stable release matching our needs |
| mlx-audio-swift | `branch: development` | Co-developed; API evolving |

These will switch to semver pins once APIs stabilize.

---

## Sibling Repos (Local Development)

For integration tests and cross-repo development:

| Repo | Expected Path | Used By |
|------|--------------|---------|
| vox-format | `../vox-format` | `make integration-test` (vox CLI validator) |
| SwiftVoxAlta | `../SwiftVoxAlta` | `make integration-test` (diga CLI synthesizer) |

---

## Key Types from Dependencies

### From SwiftProyecto

- **`Gender`**: Enum (`.male`, `.female`, `.nonBinary`, `.notSpecified`)
- **`CastMember`**: Struct with `character`, `actor?`, `gender?`, `voiceDescription?`, `voices: [String: String]`
- **`ProjectMarkdownParser`**: Parses PROJECT.md frontmatter + body
- **`ProjectFrontMatter`**: Decoded YAML frontmatter including `tts` config

### From SwiftVoxAlta

- **`VoxAltaModelManager`**: Loads/unloads Qwen3-TTS models (manages GPU memory)
- **`VoiceLockManager`**: Creates voice locks (speaker embeddings) from candidate audio
- **`VoxExporter`**: Static methods to add clone prompts and sample audio to VoxFile
- **`Qwen3TTSModelRepo`**: Enum of model repos (`.voiceDesign1_7B`, `.base0_6B`, `.base1_7B`)

### From vox-format

- **`VoxFile`**: Mutable class -- zip archive container for voice data
- **`VoxManifest`**: JSON manifest inside .vox with name, description, provenance, paths
- **`VoxManifest.Provenance`**: Metadata about how the voice was created
