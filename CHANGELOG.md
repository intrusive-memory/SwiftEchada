---
type: doc
---

# Changelog

All notable changes to SwiftEchada will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Voice-audition sentences are now curated data instead of Foundation Model output**, removing Apple Intelligence from the `generate vox` path entirely. `FoundationModelSentence` is replaced by `AuditionSentence`, which supplies a deterministic, in-language sentence for every language the TTS model supports (zh, en, de, it, pt, es, ja, ko, fr, ru) — total coverage of what can actually be synthesized, so no language regressed.

  Generation was the wrong tool for this job on three counts. **Reliability:** the on-device model failed requests transiently and sometimes returned a fluent sentence in the *wrong* language; a bounded retry (added in 0.16.2) reduced but could not eliminate the failures, and they aborted real cast runs. **Reproducibility:** the audition audio *is* the voice-lock reference the `.vox` embedding derives from, so non-deterministic reference text meant the same `voicePrompt` produced a different embedding on every run, with no record of which text produced which voice. **Portability:** it made `echada generate vox` unavailable on CI and on any Mac without Apple Intelligence, despite the TTS pipeline itself having no such requirement.

  Consequences: `.vox` generation is now reproducible; `echada generate vox`, `echada voice`, and `echada test-voice` run without Apple Intelligence; and the model-backed `generate vox` CI test is gated on TTS-weight presence alone, so it now runs on hosted `macos-26` instead of silently skipping. Regional tags (`es-MX`, `pt-BR`) resolve to their base language; an uncurated language throws `AuditionSentenceError` naming the supported set.

  `generate prompt` still uses the on-device Foundation Model — writing a voice-design brief from a character's dialogue is genuine generative work, unlike a fixed reference sentence.

  The flaky `FoundationModelSentenceTests` (which asked the model for a sentence, then asserted `NLLanguageRecognizer` agreed on its language — doubly non-deterministic, and skipped on CI) is replaced by `AuditionSentenceTests`: pure data validation that runs identically everywhere, enforcing coverage, determinism, the TTS text contract, and length bounds.

### Added

- **`echada --version` now reports the dependency versions compiled into the binary.** It lists every direct dependency from `Package.swift` alongside both its *declared* requirement (e.g. `4.6.1 ..< 5.0.0`) and the version SwiftPM actually *resolved and linked* (e.g. `4.6.1`), followed by the transitive graph. The table is generated at build time by `Scripts/generate-dependency-versions.py` and baked in via `make resolve` (which every build target already depends on); `make generate-deps` regenerates it on demand.

  This exists because `Package.resolved` is gitignored, so nothing in version control records what a given release links against. Diagnosing [#44](https://github.com/intrusive-memory/SwiftEchada/issues/44)/[#55](https://github.com/intrusive-memory/SwiftEchada/issues/55) required inferring the compiled-in SwiftProyecto version by running the shipped binary against a fixture and reading the behaviour. Now the binary just says. The generated Swift file is committed, so it doubles as the missing lockfile record.

### Fixed

- **PROJECT.md write-back no longer destroys or corrupts non-cast content** ([#44](https://github.com/intrusive-memory/SwiftEchada/issues/44), [#55](https://github.com/intrusive-memory/SwiftEchada/issues/55)). All three `generate` stages (`cast`, `prompt`, `vox`) re-serialized the entire YAML front matter from the typed model on every write-back, routing through the hand-rolled emitter in `ProjectMarkdownParser.generate`. That emitter deleted keys it did not know how to write (`introFile`/`outroFile`, #55) and, for unknown top-level keys captured into `appSections`, preserved the key name while destroying its structure — a nested list of maps such as `episodes_index` came back as an Objective-C `NSDictionary.description` dump inside a YAML string (#44). On a real 309-line project file this collapsed it to 103 lines, and because the mangled form still contained the original substrings, the existing regression tests passed while the data was being lost.

  All three stages now write through the new `ProjectCastWriteBack` helper, which splices only the `cast:` line span via `ProjectMarkdownParser.replacingCastBlock(in:with:)` and copies every other byte verbatim. Unknown keys, nested structure, key ordering, comments, and spacing are preserved by construction. Regression tests now assert structure after re-parsing and line-level equality outside the cast block, rather than substring presence.

## [0.16.1] - 2026-07-12

### Fixed

- **Cast lists no longer include emphasis-wrapped scene markers** - Bumped the `SwiftProyecto` dependency floor to 4.3.3, which pulls in the upstream Fountain parser fix ([SwiftCompartido#71](https://github.com/intrusive-memory/SwiftCompartido/issues/71)). Emphasis-wrapped direction lines like `**END OF SCENE.**` are no longer mis-detected as characters by `echada generate cast`.

## [0.16.0] - 2026-07-04

### Changed — Breaking

**`echada cast` is repurposed into the full pipeline orchestrator** (OPERATION
GENERAL MUSTER). This is a hard-cut breaking change to the CLI surface — there
is no back-compat alias, and for the removed `echada prompt` command there is
no runtime breadcrumb pointing at the replacement (it fails with
ArgumentParser's generic "unknown subcommand" error). Update any scripts or CI
jobs that call `echada cast` or `echada prompt` directly.

All generative steps now live under a new `echada generate` namespace:

- `echada generate cast` — **(new)** heuristically discovers cast members from
  the screenplay source (no LLM/ML) and merges them into PROJECT.md's `cast:`
  list.
- `echada generate prompt` — **was `echada prompt`.** Same
  `VoicePromptSynthesizer`/`DialogueExtractor` logic, moved verbatim. Old
  invocations of `echada prompt ...` now fail with a generic argument error;
  use `echada generate prompt ...` instead.
- `echada generate vox` — **was `echada cast`'s old `.vox`-only behavior.**
  Same `CastVoiceGenerator` logic, moved verbatim (same flags: `--project`,
  `--force-regenerate`, `--dry-run`, `--verbose`, `--tts-model`, `--character`,
  `--language`, `--accent`). If you previously ran `echada cast ...` to
  generate `.vox` files from existing `voicePrompt`s, use
  `echada generate vox ...` instead — the exact same flags apply.

**`echada cast` (bare or explicit, still the default subcommand) now runs the
full production pipeline end to end**: bootstrap `PROJECT.md` (scaffolded
automatically, no LLM, when absent) → `generate cast` → `generate prompt` →
`generate vox`. Every stage is idempotent, so re-running only fills the gaps.
It takes a superset flag surface (`--project`, `--character`, `--tts-model`,
`--language`, `--accent`, `--dry-run`, `--verbose`) plus a single cascading
`--force` that fans out to each stage's own force flag; per-stage control
remains available via the standalone `echada generate <stage>` subcommands.

**Migration summary:**

| Old | New |
|-----|-----|
| `echada cast` (produced `.vox` only) | `echada generate vox` |
| `echada prompt` | `echada generate prompt` |
| — | `echada generate cast` (new) |
| `echada cast` (bare, one-shot pipeline) | `echada cast` now runs the **full pipeline** (bootstrap → cast → prompt → vox), not just `.vox` generation |
| `echada voice`, `echada test-voice` | Unchanged |

### Added
- `echada generate` command container (no default subcommand — `echada
  generate --help` lists `cast`/`prompt`/`vox`).
- CI: SwiftAcervo model-cache wiring in `tests.yml` so the Qwen3-TTS weights
  `generate vox` needs are cached across hosted-CI runs (see
  [Docs/build-and-test.md](Docs/build-and-test.md) for the important caveat
  that this caching does not by itself unlock `.vox` test coverage on hosted
  CI — those tests are also gated on Apple Intelligence availability, which
  hosted `macos-26` does not provide).

## [0.15.0] - 2026-06-26

### Changed
- Raised the `SwiftProyecto` dependency floor from `3.8.0` to `4.0.0`. SwiftProyecto
  4.x changes `CastMember.voices` from `[String: String]` to `[String: [String]]`
  (multiple voice IDs per provider). The voxalta voice-path writes now store
  single-element arrays and the `cast` voice-list display joins each provider's
  list. Reads via `CastMember.voice(for:)` are unchanged (it returns the first
  entry). The transitive chain SwiftVoxAlta → SwiftHablare 6.2.0 → SwiftProyecto
  4.x resolves with SwiftHablare 6.2.0 published.

## [0.14.1] - 2026-06-15

### Added
- `--verbose` language audit at the voice-designer generation boundary. When
  `--verbose` is passed to `cast`/`voice`, each TTS generation site emits one
  `[lang]` stderr line confirming the resolved `TTSLanguage` case and exact
  `modelName` handed to `Qwen3TTSModel.generate(language:)`, and validates it
  against the loaded model's real `codec_language_id` keys (via
  `recognizesLanguage`) — surfacing values that would silently produce
  un-conditioned audio. Ships in the signed release CLI (no longer `#if DEBUG`).

### Changed
- Bumped the mlx-audio-swift dependency floor `0.8.6` → `0.8.7` for the
  language-key accessors the audit relies on.

## [0.14.0] - 2026-06-15

### Changed
- Adopted SwiftVoxAlta's type-safe `TTSLanguage` enum at the generation boundary
  (`cast`, `voice`, and voice-lock creation), replacing the stringly-typed `"en"`
  literal. The model-aligned `language.modelName` now conditions the speaker
  encoder, fixing silent fall-through to un-conditioned generation.
- Bumped the SwiftVoxAlta dependency floor to `0.14.0` (the release that ships
  `TTSLanguage`) and vox-format to `0.4.1`. The prior floor (`0.13.1`) predated
  `TTSLanguage`, so the build only resolved against a local sibling checkout.

## [0.13.2] - 2026-06-14

### Changed
- `.vox` manifest provenance now records the generating echada utility version
  (e.g. "echada 0.13.2") in its `notes` field, across the `cast`, `voice`, and
  `test-voice` commands, for build traceability. The format-spec `voxVersion`
  field is unchanged (still owned by vox-format).

## [0.10.3] - 2026-03-27

### Changed
- All intrusive-memory dependencies now track main branch (previously development)
- Cleaned up development branch history (rebased onto main after squash merges)

## [0.10.1] - 2026-02-28

### Added
- VoxFile integration tests (5 tests verifying .vox creation, multi-model support, append workflow, gender mapping)
- VoxFormat added as test target dependency for end-to-end testing with synthetic data

### Changed
- CI workflow cleaned up: removed obsolete integration-tests job and `-skip-testing` flag
- Branch protection updated: only "Unit Tests" required (removed defunct "Integration Tests" check)
- Restructured documentation: AGENTS.md tightened to onboarding hub with links to Docs/
- Moved detailed reference docs to `Docs/` folder: architecture, vox-pipeline, api, build-and-test, dependencies, gotchas
- CLAUDE.md and GEMINI.md streamlined to agent-specific concerns with doc links
- API.md redirects to Docs/api.md

## [0.9.2] - 2026-02-21

### Added
- CharacterProfile for detailed voice profiling (gender, age range, voice traits)
- CharacterAnalyzer for building profiles from cast members via LLM
- SampleSentenceGenerator for TTS audition sentences
- ParentheticalMapper for screenplay parenthetical-to-TTS mapping
- VoiceDesigner for candidate WAV generation via Qwen3-TTS
- CastVoiceGenerator for orchestrating .vox pipeline
- ReferenceAudioGenerator (macOS `say` fallback)
- `echada cast` command for on-device voice generation

### Changed
- Library now depends only on SwiftProyecto (removed SwiftHablare dependency)
- Makefile uses xcodebuild exclusively (no more swift build/swift test)
- 54 tests across 7 suites (up from 31)

### Removed
- CastMatcher and `echada match` command (replaced by `echada cast`)
- ElevenLabs types and defaults export
- CastMember+Provider extension
- SwiftHablare dependency
- REQUIREMENTS.md

## [0.9.1] - 2026-02-14

### Added
- SwiftVoxAlta integration for on-device voice generation
- VoiceDescriptionEnricher for LLM-powered voice descriptions

### Changed
- Updated architecture documentation

## [0.6.0] - 2026-02-01

### Added
- AGENTS.md with comprehensive project documentation
- LICENSE (MIT)
- CONTRIBUTING.md
- CHANGELOG.md

### Changed
- CLAUDE.md now serves as a stub referencing AGENTS.md

## [0.5.0] - 2026-01-27

### Added
- Initial public release
- CharacterExtractor with LLM-powered character discovery
- CharacterMerger for deduplication across files
- CastMatcher for TTS voice assignment via LLM
- `echada` CLI with extract, match, and download commands
- Closure-based dependency injection for testability
- Scene-based chunking for large screenplay files
- Homebrew distribution support
