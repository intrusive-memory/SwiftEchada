---
type: doc
---

# Changelog

All notable changes to SwiftEchada will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-08-03

### Changed — Breaking

- **Cast data moves out of PROJECT.md into its own file, CAST.md** (the CAST.md
  extraction). `PROJECT.md` is [SwiftProyecto](https://github.com/intrusive-memory/SwiftProyecto)'s
  config file — project identity, episode discovery (`episodesDir`,
  `filePattern`), and `tts` config. `CAST.md` is
  [SwiftReparto](https://github.com/intrusive-memory/SwiftReparto)'s config
  file — the cast roster (`character`, `actor`, `gender`, `language`,
  `voicePrompt`, `voices`) plus a free markdown body preserved byte-for-byte.
  All three `generate` stages (`cast`, `prompt`, `vox`) now read and write the
  roster in CAST.md; `.vox` output paths are recorded under `voices.voxalta`
  in CAST.md, relative to its directory. SwiftReparto is the single writer of
  CAST.md — `echada` mutates a `CastDocument` and hands it back, never
  building YAML or splicing text itself.

- **`PROJECT.md`'s `cast:` block is now read-only legacy.** It is consulted
  only through `LegacyProjectCastReader` — to seed a brand-new CAST.md
  verbatim (voice prompts, bios, and voice pointers included) and to power
  `verify cast`. Nothing writes it except `echada prune cast`'s excision. A
  PROJECT.md without a `cast:` key is the expected end state, not an error.
  The reader is deleted at SwiftProyecto 5.0, when `cast:` leaves the
  PROJECT.md schema entirely.

- **The library target depends only on SwiftReparto.** The
  `SwiftEchada → SwiftProyecto` dependency edge is gone: SwiftProyecto (4.8.1)
  survives on `EchadaCLICore` alone, for project-level PROJECT.md fields.
  SwiftReparto is a leaf with no `intrusive-memory` dependencies, so no
  package cycle around cast data is possible. `CharacterProfile.gender` and
  `CharacterMerger`'s rosters are now SwiftReparto's `Gender`/`CastMember`
  (previously SwiftProyecto's); the enum cases and YAML wire format are
  unchanged, but consumers that named the module in source must import
  SwiftReparto. `CastMember.voices` is now `[String: [String]]` (scalar wire
  form still decodes), the legacy `voiceDescription:` key still decodes into
  `voicePrompt`, and undeclared per-member keys (`bio:`, the reserved
  `appearance.portrait`) are preserved verbatim through `extraKeys`.

### Added

- **`echada verify cast`** — read-only migration gate. Compares the CAST.md
  roster against the legacy `cast:` block in PROJECT.md and reports
  membership divergences, per-field mismatches on matched characters, and
  `.vox` pointers that do not resolve on disk. Never writes either file;
  exits non-zero on any divergence so it can gate CI or a rollout loop.
- **`echada prune cast`** — explicit, gated removal of the migrated legacy
  `cast:` block from PROJECT.md. Requires CAST.md to exist beside PROJECT.md
  and the `verify cast` check to pass; excises only the `cast:` line span,
  preserving every other byte of the file. Idempotent, supports `--dry-run`,
  and is never invoked by any other command. Migration is therefore two-phase
  and non-destructive: `generate cast` (create/seed CAST.md) →
  `verify cast` (human gate) → `prune cast` (remove the legacy block).
- **`--cast <filename>` flag** on every roster-touching command
  (`cast`, `generate cast|prompt|vox`, `verify cast`, `prune cast`). Default
  `CAST.md`; a bare filename resolved beside `--project` — path separators
  are rejected.

## [0.17.0] - 2026-07-31

### Changed

- **Voice-audition sentences are now curated data instead of Foundation Model output**, removing Apple Intelligence from the `generate vox` path entirely. `FoundationModelSentence` is replaced by `AuditionSentence`, which supplies a deterministic, in-language sentence for every language the TTS model supports (zh, en, de, it, pt, es, ja, ko, fr, ru) — total coverage of what can actually be synthesized, so no language regressed.

  Generation was the wrong tool for this job on three counts. **Reliability:** the on-device model failed requests transiently and sometimes returned a fluent sentence in the *wrong* language; a bounded retry (added in 0.16.2) reduced but could not eliminate the failures, and they aborted real cast runs. **Reproducibility:** the audition audio *is* the voice-lock reference the `.vox` embedding derives from, so non-deterministic reference text meant the same `voicePrompt` produced a different embedding on every run, with no record of which text produced which voice. **Portability:** it made `echada generate vox` unavailable on CI and on any Mac without Apple Intelligence, despite the TTS pipeline itself having no such requirement.

  Consequences: `.vox` generation is now reproducible; `echada generate vox`, `echada voice`, and `echada test-voice` run without Apple Intelligence; and the model-backed `generate vox` CI test is gated on TTS-weight presence alone, so it now runs on hosted `macos-26` instead of silently skipping. Regional tags (`es-MX`, `pt-BR`) resolve to their base language; an uncurated language throws `AuditionSentenceError` naming the supported set.

  `generate prompt` still uses the on-device Foundation Model — writing a voice-design brief from a character's dialogue is genuine generative work, unlike a fixed reference sentence.

  The flaky `FoundationModelSentenceTests` (which asked the model for a sentence, then asserted `NLLanguageRecognizer` agreed on its language — doubly non-deterministic, and skipped on CI) is replaced by `AuditionSentenceTests`: pure data validation that runs identically everywhere, enforcing coverage, determinism, the TTS text contract, and length bounds.

- **`echada --version` output is now multi-line.** The first line is still the bare version string, so `echada --version | head -1` is unaffected, but the dependency table (below) follows it. Anything comparing the *entire* output against a fixed string needs updating. The Homebrew formula only invokes `echada --version` and checks the exit status, so it needs no change.

### Added

- **`echada --version` now reports the dependency versions compiled into the binary.** It lists every direct dependency from `Package.swift` alongside both its *declared* requirement (e.g. `4.6.1 ..< 5.0.0`) and the version SwiftPM actually *resolved and linked* (e.g. `4.6.1`), followed by the transitive graph. The table is generated at build time by `Scripts/generate-dependency-versions.py` and baked in via `make resolve` (which every build target already depends on); `make generate-deps` regenerates it on demand.

  This exists because `Package.resolved` is gitignored, so nothing in version control records what a given release links against. Diagnosing [#44](https://github.com/intrusive-memory/SwiftEchada/issues/44)/[#55](https://github.com/intrusive-memory/SwiftEchada/issues/55) required inferring the compiled-in SwiftProyecto version by running the shipped binary against a fixture and reading the behaviour. Now the binary just says. The generated Swift file is committed, so it doubles as the missing lockfile record.

### Fixed

- **PROJECT.md write-back no longer destroys or corrupts non-cast content** ([#44](https://github.com/intrusive-memory/SwiftEchada/issues/44), [#55](https://github.com/intrusive-memory/SwiftEchada/issues/55)). All three `generate` stages (`cast`, `prompt`, `vox`) re-serialized the entire YAML front matter from the typed model on every write-back, routing through the hand-rolled emitter in `ProjectMarkdownParser.generate`. That emitter deleted keys it did not know how to write (`introFile`/`outroFile`, #55) and, for unknown top-level keys captured into `appSections`, preserved the key name while destroying its structure — a nested list of maps such as `episodes_index` came back as an Objective-C `NSDictionary.description` dump inside a YAML string (#44). On a real 309-line project file this collapsed it to 103 lines, and because the mangled form still contained the original substrings, the existing regression tests passed while the data was being lost.

  All three stages now write through the new `ProjectCastWriteBack` helper, which splices only the `cast:` line span via `ProjectMarkdownParser.replacingCastBlock(in:with:)` and copies every other byte verbatim. Unknown keys, nested structure, key ordering, comments, and spacing are preserved by construction. Regression tests now assert structure after re-parsing and line-level equality outside the cast block, rather than substring presence.

  Requires SwiftProyecto 4.8.1, which fixes a splice bug the surgical write-back would otherwise have been exposed to: a blank line or column-0 comment inside the `cast:` block terminated the block scan early, leaving the entries below it unreplaced but still indented, so re-parsing read them back as **duplicate cast members**. Blank lines between cast entries are ordinary in hand-maintained project files — the same population that hit #44 and #55 — so this was reachable from a normal cast run.

- **`AuditionSentence` now accepts every language tag `TTSLanguage` does.** Its alias table normalized `_` to `-` *before* looking up aliases, which made the `beijing_dialect`/`sichuan_dialect` entries unreachable dead code, and it had no entry for `auto`, `beijing`, `beijingdialect`, `sichuan`, or `sichuandialect`. Because `CastVoiceGenerator` resolves the audition sentence outside its per-character `do`/`catch`, any of those tags aborted the **entire cast run** rather than skipping one character. Dialects now resolve to the language they are spoken in, and `auto` resolves to English (its historical default). A new test drives `TTSLanguage.allCases`, so adding a TTS language fails the suite until it has curated sentences.

### Internal

- **`make verify-deps` and a matching CI job** fail the build when the committed `DependencyVersions.swift` no longer matches what SwiftPM resolves. The unit-test workflow runs `xcodebuild` directly and never invokes `make`, so nothing previously regenerated the table in CI and `DependencyVersionsTests` validated whatever stale data happened to be committed — a confidently-wrong version table being worse than none. Note that direct dependencies use open `.upToNextMajor` ranges, so an unrelated upstream release can turn this job red; the fix is always `make resolve` plus committing the regenerated file.
- `make generate-deps` no longer breaks the build when `python3` is absent, since the version table is diagnostics rather than a build input. The generator also refuses to write an empty table instead of silently emptying it if manifest parsing regresses.

## [0.16.2] - 2026-07-21

### Fixed

- **Transient `FoundationModels` failures during casting are retried** ([#54](https://github.com/intrusive-memory/SwiftEchada/issues/54)). The on-device system model intermittently failed a single request (e.g. "Failed to deserialize a Generable type from model output"), which aborted an entire cast run. `FoundationModelRetry` retries with a fresh session so one flaky call no longer takes down the run.

  Superseded for audition sentences in 0.17.0, which removes the Foundation Model from that path altogether; the retry still covers `generate prompt`.

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
