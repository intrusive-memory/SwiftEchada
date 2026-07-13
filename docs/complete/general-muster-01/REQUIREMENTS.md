---
type: requirements
status: draft
created: 2026-07-04
---

# REQUIREMENTS — `echada` CLI restructure: `generate` subcommands + `cast` meta-pipeline

## 1. Motivation

Today the `echada` CLI has four flat subcommands (`cast`, `prompt`, `voice`,
`test-voice`) where **`cast` means "turn voice prompts into `.vox` files."** We
are restructuring so that:

- All generative steps live under a single **`echada generate`** namespace.
- **`cast` becomes a meta / orchestrator command** that runs the whole pipeline
  end-to-end: ensure a `PROJECT.md` exists → build the cast list → write voice
  prompts → generate `.vox` files. Each step builds on the output of the prior
  one and is individually re-runnable.

This turns `echada cast` (with no other input) into a one-shot "take this folder
of episode scripts and produce castable voices" command.

## 2. Target command tree

```
echada
├── cast                      (default) META pipeline: ensure PROJECT.md → generate cast → generate prompt → generate vox
├── generate
│   ├── cast                  episodes → cast list written into PROJECT.md   (SwiftProyecto, heuristic, no ML/LLM)
│   ├── prompt                cast list → voicePrompt per member             (Apple Foundation Model)  ← today's `prompt`
│   └── vox                   voicePrompts → .vox voice identities           (SwiftVoxAlta / MLX)      ← today's `cast`
├── voice <prompt>            single .vox from a text description (unchanged)
└── test-voice                (hidden) integration-test helper (unchanged)
```

### 2.1 Migration map (breaking change)

| Old | New | Notes |
|-----|-----|-------|
| `echada cast` (generated `.vox`) | `echada generate vox` | Same `CastVoiceGenerator` logic, moved verbatim. |
| `echada prompt` | `echada generate prompt` | Same `VoicePromptSynthesizer`/`DialogueExtractor` logic, moved verbatim. |
| — (new) | `echada generate cast` | New: extract cast list from episodes via SwiftProyecto. |
| `echada cast` | `echada cast` (repurposed) | **Behavior changes** — now the full orchestrator, no longer just `.vox`. |
| `echada voice` | `echada voice` | Unchanged. |
| `echada test-voice` | `echada test-voice` | Unchanged. |

> **Breaking:** anything calling `echada cast` expecting only `.vox` output must
> switch to `echada generate vox`. Call this out in CHANGELOG and bump the minor
> version. Consider keeping `cast` accepting the old `.vox`-only flags so the
> common invocation still works, but its *default* effect is now the full run.

## 3. Command specifications

### 3.1 `echada generate cast`

**Purpose:** Read the project's episode/screenplay files and write a cast list
into `PROJECT.md`, merging with (never clobbering) any existing cast entries.

**Inputs / flags**
- `--project <path>` (default `PROJECT.md`)
- `--force` — overwrite existing cast entries instead of merge-preserving them
- `--dry-run` — print discovered characters, write nothing
- `--verbose`

**Library calls (SwiftProyecto — already the only lib dependency):**
- Locate scripts: reuse `SourceMaterialLocator` (episodesDir + filePattern from
  `ProjectFrontMatter`), consistent with `generate prompt`.
- Extract names: `CastExtractor().extractCast(from: fountainText) -> [String]`
  (heuristic uppercase-cue Fountain parsing — **no LLM, no ML required**), or
  `ProjectService.analyzeForGeneration(at:)` for a directory-level scan.
- Map `[String]` → `[CastMember]` (character only; `actor`/`gender`/`voices`
  left unset).
- Merge into existing: `ProjectFrontMatter.withCast(...)` +
  `ProjectService.mergeCastLists(discovered:existing:)` (or the static
  `ProjectFrontMatter.mergeCast(_:_:strategy:)`), preserving any existing
  `actor`, `voicePrompt`, `voices`, `language`, `gender`.

**Output:** updated `cast:` block in `PROJECT.md` via `ProjectMarkdownParser`.

**Idempotency:** re-running only adds newly-appearing characters; existing
members and their downstream fields are untouched unless `--force`.

**Out of scope (v1):** LLM enrichment of `gender`/`language`/`description`. That
path exists (`ProjectGeneratorService.generateFrom(projectPath:)`, needs a
backend) and can be added later behind an `--enrich` flag.

### 3.2 `echada generate prompt`  (= today's `prompt`)

Unchanged behavior; only the invocation path moves under `generate`. Reads the
scripts, gathers each member's dialogue (`DialogueExtractor`), and asks the
on-device Foundation Model (`VoicePromptSynthesizer`) to write a `voicePrompt`.

- Flags: `--project`, `--character`, `--force`, `--dry-run`, `--verbose`
  (as-is).
- Idempotency: fills empty `voicePrompt` only; `--force` regenerates all.

### 3.3 `echada generate vox`  (= today's `cast`)

Unchanged behavior; the current `CastCommand` body moves here verbatim. Iterates
each member's `voicePrompt` and generates a `.vox` (two-phase VoiceDesign →
Base), storing paths under `voices.voxalta` in `PROJECT.md`.

- Flags: `--project`, `--force-regenerate`, `--dry-run`, `--verbose`,
  `--tts-model`, `--character`, `--language` (repeatable), `--accent` (as-is).
- Idempotency: skips members whose `.vox` already holds the requested variant
  unless `--force-regenerate`.

### 3.4 `echada cast`  (meta / orchestrator, default subcommand)

**Purpose:** Run the entire pipeline, bootstrapping anything missing.

**Flow:**
1. **Ensure `PROJECT.md`.** If `--project` (default `PROJECT.md`) is missing:
   - Infer scaffolding without an LLM: `ProjectService.analyzeForGeneration(at:)`
     yields `inferredTitle`, `episodePattern`, `detectedLanguages`,
     `extractedCast`.
   - Build a `ProjectFrontMatter` (`type`, `title`, `author` =
     `NSFullUserName()`, `created` = now, `episodesDir`, `filePattern`) and write
     it with `ProjectMarkdownParser().write(frontMatter:body:to:)`.
   - Detection uses `ProjectDiscovery().findProjectMd(from:)` (handles the
     `episodes/` subfolder convention).
2. **`generate cast`** — populate/merge the cast list from episodes.
3. **`generate prompt`** — fill `voicePrompt` for members that lack one.
4. **`generate vox`** — generate `.vox` for members that don't yet have one.

Each stage is the same code invoked by the standalone subcommands, so
re-running `echada cast` is safe: completed work is skipped, only gaps are
filled. `--force*` flags cascade to the relevant stages.

**Flags:** superset that fans out to the stages — at minimum `--project`,
`--character`, `--tts-model`, `--language`, `--accent`, `--dry-run`,
`--verbose`, plus a `--force` that maps to each stage's force flag. (Exact flag
surface TBD — see open questions.)

## 4. Architecture / dependency notes

- **Library boundary holds.** All new logic lives in the **CLI target**
  (`EchadaCLICore`). The `SwiftEchada` *library* still depends only on
  SwiftProyecto. Cast extraction uses SwiftProyecto library API (already a CLI
  dependency); no new dependency is introduced for `generate cast`.
- **Dependency footprint per stage:**
  - `generate cast` → SwiftProyecto only (fast, offline, no models).
  - `generate prompt` → Apple Foundation Model (Apple Intelligence must be on).
  - `generate vox` → SwiftVoxAlta + MLX (Metal; heaviest).
- **`generate` is a container command** (an `AsyncParsableCommand` with
  `subcommands: [GenerateCast, GeneratePrompt, GenerateVox]`, no default), added
  to `EchadaCLI.subcommands` alongside `cast`, `voice`, `test-voice`.
- SwiftProyecto entry points confirmed present (as of this draft):
  `CastExtractor`, `ProjectService.analyzeForGeneration`,
  `ProjectService.mergeCastLists`, `ProjectDiscovery.findProjectMd`,
  `ProjectMarkdownParser.parse/generate/write`, `ProjectFrontMatter.withCast`.

## 5. Self-documentation (`--help`) requirements

Agents drive `echada` primarily by reading `--help`, so the in-binary help is a
first-class deliverable, not an afterthought. ArgumentParser renders help from
`CommandConfiguration.abstract`/`discussion` and each `@Option`/`@Flag`/
`@Argument` `help:` string; there is no separate man page to maintain.

**R-HELP-1 — Every command has an `abstract` AND a `discussion`.** Today only
`abstract` is set (verified: no `discussion:` anywhere in `EchadaCLICore`). Each
command gains a `discussion:` block (the long text shown under `--help`) that
states what it consumes, what it produces, and its idempotency rule. Required
for: `EchadaCLI` (root), `cast`, `generate` (container), `generate cast`,
`generate prompt`, `generate vox`, `voice`. (`test-voice` stays
`shouldDisplay: false`.)

**R-HELP-2 — Root `discussion` documents the pipeline.** `echada --help` must
explain the `PROJECT.md → cast → prompt → vox` flow and that bare `echada`
(default `cast`) runs the whole thing, so an agent that reads only the top-level
help understands the mental model and the four stages.

**R-HELP-3 — `generate` is a discoverable container.** `echada generate --help`
lists `cast`, `prompt`, `vox` with one-line abstracts. The `generate` command
has `subcommands:` set and **no `defaultSubcommand`** (running `echada generate`
alone prints help).

**R-HELP-4 — Worked examples in `discussion`.** Each command's `discussion`
ends with a copy-pasteable example (ArgumentParser preserves newlines in
`discussion`), e.g.:
- `cast`: `echada cast` (bootstrap-and-run in an episodes folder)
- `generate cast`: `echada generate cast --project PROJECT.md`
- `generate prompt`: `echada generate prompt --character ALICE --force`
- `generate vox`: `echada generate vox --language es --language en`

**R-HELP-5 — Every flag has a `help:` string.** Audit on implementation; no
bare `@Flag`/`@Option`. Cross-stage flags on `cast` must state which stage they
forward to (e.g. `--accent` → the `vox` stage).

**R-HELP-6 — Deprecation breadcrumb (optional, see open Q4).** If a back-compat
alias is kept, the removed usage prints a one-line pointer to `echada generate
vox` on stderr. If hard-cut, the error message names the replacement command.

## 6. Testing requirements

Existing conventions (keep them): swift-testing (`import Testing`, `@Suite`/
`@Test`), `@testable import EchadaCLICore`, one `SwiftEchadaTests` target,
model-free branches exercised by `Command.parse([...])` + `run()`.

**Model paths run in CI.** Per project direction, the CI runner provides both
Apple Foundation Models and the MLX TTS weights, so `generate prompt` and
`generate vox` (and the full `cast` pipeline) execute end-to-end in CI rather
than being skipped. Tests still use graceful availability gates
(`.enabled(if:)` / model-presence skip) so a developer machine **without** those
provisions skips (never fails) — but the CI expectation is that nothing is
skipped there. This requires the CI-enablement work in §6.5; until that lands,
these tests skip on stock GitHub-hosted `macos-26`.

### 6.1 What is unit-testable without any model (must be covered)

Cast extraction is **heuristic** and the PROJECT.md bootstrap is **pure I/O**, so
the two genuinely new pieces are fully unit-testable offline:

- **R-TEST-1 `generate cast`** — extraction + merge against fixture Fountain
  text: names discovered, sorted/unique, merged into an existing cast without
  clobbering `actor`/`voicePrompt`/`voices`/`language`; `--force` overwrites;
  `--dry-run` writes nothing; empty/no-scripts path errors cleanly.
- **R-TEST-2 PROJECT.md bootstrap** (the `cast` meta step) — given a temp dir
  with episode files and **no** PROJECT.md, a `PROJECT.md` is created with
  inferred `title`, `episodesDir`, `filePattern`; given an existing one, it is
  detected (`ProjectDiscovery.findProjectMd`) and left in place.
- **R-TEST-3 command wiring / help** (guards doc drift, all offline):
  - `EchadaCLI.configuration.defaultSubcommand` is `CastCommand`.
  - `EchadaCLI.configuration.subcommands` contains `generate` and `voice`.
  - `generate`'s subcommands are exactly `cast`, `prompt`, `vox`; it has no
    default subcommand.
  - `GenerateCommand.parseAsRoot(["--help"])` (and each leaf) renders help
    containing the command name + a non-empty `discussion` — assert the abstract/
    discussion strings are non-empty and mention their inputs/outputs so help
    can't silently regress.
  - Each command's `configuration.abstract` and `.discussion` are non-empty.

### 6.2 Migrate existing tests (breaking change → test moves)

- `CastCommandTests.swift` currently tests today's `.vox` generator via
  `CastCommand`. Its logic moves to `generate vox` → rename to
  `GenerateVoxCommandTests`, retarget `CastCommand.parse` → `GenerateVox.parse`.
- `LanguageOptionTests` / `AccentOptionTests` call `CastCommand.parse(...)` /
  `cmd.resolvedLanguages()` / `resolvedAccent()` — those helpers move with the
  `.vox` command → retarget to the new `generate vox` type. Keep the same
  assertions (they test the flag surface, which is unchanged).
- `DialogueExtractorTests`, `PerLanguagePromptTests`, `VoicePromptRoundTripTests`
  cover the `prompt` path — unchanged logic; only add a thin wiring test that
  `generate prompt` parses.
- Add **`CastPipelineTests`** for the orchestrator: dry-run of the full `cast`
  runs bootstrap + `generate cast` and stops before the model stages (assert
  PROJECT.md now has a cast list and nothing under `voices/`); a `--force`
  cascade test asserting each stage receives the force flag.

### 6.3 Model-backed tests (run in CI; gated so they skip locally when absent)

- `generate vox` end-to-end produces a valid multi-model `.vox` (existing
  coverage, retargeted to the new command).
- **New full-pipeline test:** `echada cast` on a fixture episodes dir with **no**
  PROJECT.md → asserts PROJECT.md created, cast populated (heuristic, always
  runs), `voicePrompt`s written (Foundation Model), and `.vox` files produced
  (MLX). Gate the model-dependent assertions with
  `.enabled(if: SystemLanguageModel.default.isAvailable)` + a TTS-weights
  presence check so the test runs fully in CI (§6.5) and skips gracefully on an
  unprovisioned dev machine.
- `generate prompt` against a fixture, gated on
  `SystemLanguageModel.default.isAvailable` — consistent with
  `FoundationModelSentenceTests`.
- The `make integration-test` shell pipeline (`test-voice` → `vox validate` →
  `diga` synth) stays as the belt-and-suspenders binary smoke test.

### 6.4 Makefile / CI

- `make test` runs the whole `SwiftEchadaTests` suite (offline unit tests from
  §6.1 always run; model-backed tests from §6.3 run when the models are present,
  which per project direction is the CI case).
- No new test target; everything lands in `SwiftEchadaTests`.

### 6.5 CI enablement (prerequisites for §6.3 to run, not skip)

The repo as it stands does **not** yet run model paths in CI: `tests.yml` uses
GitHub-hosted `macos-26` (which reports `SystemLanguageModel.isAvailable ==
false`) and has no model-download/cache step. For §6.3 to execute rather than
skip, this restructure must also deliver:

- **R-CI-1 Foundation Models available.** CI runs on a runner where
  `SystemLanguageModel.default.isAvailable == true` (provisioned / self-hosted
  runner with Apple Intelligence + signed-in Apple Account, or equivalent).
  Record the runner requirement in `tests.yml` and `Docs/build-and-test.md`.
- **R-CI-2 TTS weights cached.** Wire SwiftAcervo model caching into `tests.yml`
  (the `acervo-integration-ci` pattern: `actions/cache` restore + prime-on-miss,
  forwarding `TEST_RUNNER_ACERVO_*` into the xctest runner) so the Qwen3-TTS
  0.6b/1.7b weights are present when `generate vox` tests run.
- **R-CI-3 Correct the stale gate comment.** Update the `FoundationModelSentenceTests`
  header note (currently states AI is unavailable in CI) to reflect that CI now
  provisions it; keep the `.enabled(if:)` guard for local dev.
- **R-CI-4 Branch protection.** If job names change, update
  `required_status_checks.contexts` to match (per repo convention).

> Candid note: R-CI-1 is the load-bearing assumption. If the intended CI runner
> does **not** actually report `isAvailable == true`, `generate prompt` and the
> full-pipeline test will silently *skip* in CI (green but unexercised), which is
> worse than a hard failure. Verify `isAvailable` on the real runner early —
> before relying on CI to gate the pipeline.

## 7. Documentation impact

Update after implementation: `AGENTS.md` (CLI table), `README.md` (CLI usage —
currently says "three commands"), `Docs/api.md` (`## CLI (echada)` section),
`Docs/gotchas.md` (rule "default subcommand is `cast`" now means the pipeline),
and `CLAUDE.md`. The `--help` text (§5) is the source of truth; prose docs
should mirror it, not diverge.

## 8. Decisions & remaining open questions

**Resolved:**
- **D1 — Namespace = `echada generate`.** The subcommands live under `echada
  generate` (the "`proyecto generate …`" phrasing in the request was a slip).
- **D2 — Hard-cut breaking change (no alias).** `echada cast` is repurposed to
  the pipeline outright; the old `.vox`-only behavior is **not** aliased.
  Invoking removed usage errors with a message naming `echada generate vox`
  (per R-HELP-6). Announced in CHANGELOG + minor version bump.

**Still open (proposed defaults in brackets — proceeding unless you object):**
1. **`generate cast` enrichment** — [heuristic-only in v1: character names,
   gender/language/description left empty]. LLM enrichment via
   `ProjectGeneratorService` deferred behind a future `--enrich` flag.
2. **`cast` meta flag surface** — [single cascading `--force` that maps to each
   stage's force flag], vs. per-stage passthrough (`--force-cast`,
   `--force-prompt`, `--force-regenerate`).
3. **PROJECT.md bootstrap author/title** — [infer from folder name +
   `NSFullUserName()`, `created` = now], vs. prompting / requiring flags.
