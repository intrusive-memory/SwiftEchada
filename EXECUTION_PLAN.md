---
type: execution-plan
target_version: 1.0.0
---

# EXECUTION_PLAN.md — SwiftEchada: CAST.md Extraction

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

---

## Mission Scope

**Source**: `REQUIREMENTS-cast-md-changes.md` (the controlling document for a three-repo effort).

**In scope** — SwiftEchada requirements `EC-1` … `EC-22`, corresponding to sequencing steps 1–3, plus the release that step 3 gates on, plus the `confessions` pilot rollout (`PC-1`, `PC-2`, `PC-5`, `PC-6`) that validates the whole chain.

**Out of scope** — deliberately excluded, each has its own owner:

| Excluded | Owner | Why |
|---|---|---|
| Step 0 — SwiftHablare phantom `SwiftProyecto` dependency | `pkg/SwiftHablare` | Different repo. Blocks step 7 only, not steps 1–3. Independently valuable (§9 Q10) |
| Step 4 — remaining 11 podcast repos | `~/Projects/podcasts/*` | `PC-6` forbids rolling out past the pilot until `confessions` is eyeballed by a human. See OQ-6 |
| Step 5 — Produciesta repoint | `apps/Produciesta` | Own requirements doc (`PD-1` … `PD-40`) |
| Step 6 — `cast:` removal across podcast repos | `~/Projects/podcasts/*` | Gated on step 5 shipping. Removing before Produciesta is repointed is silent data loss (§6) |
| Step 7 — SwiftProyecto 5.0 deletions | `pkg/SwiftProyecto` | Own requirements doc (`PR-0` … `PR-31`) |
| `DEF-1` … `DEF-4` | tracked separately | Explicitly deferred by §8 |

**Standing constraints** (from `CLAUDE.md` and the requirements doc, apply to every sortie):

- Never `swift build` / `swift test`. Use `make build` / `make test`. Test scheme is `SwiftEchada-Package`.
- Targeted imports in files that see both modules: `import struct SwiftEchada.CastMember`, not `import SwiftEchada`. Both `SwiftProyecto` and `SwiftEchada` export `CastMember` for the whole transition window.
- Dependency direction is `SwiftEchada → SwiftProyecto`, never the reverse (`D6`).
- `PROJECT.md` is never modified by any sortie in WU-1 … WU-3 except the dedicated `prune` command (EC-10). Generation and removal never fuse (`D7`).

---

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies |
|-----------|-----------|---------|-------|-------------|
| WU-1 Cast Model & Parser | `Sources/SwiftEchada/` | 2 | 0 | none |
| WU-2 Non-Destructive Rollout Commands | `Sources/EchadaCLICore/` | 4 | 1 | WU-1 |
| WU-3 Command Rewiring | `Sources/EchadaCLICore/`, `Tests/SwiftEchadaTests/` | 3 | 2 | WU-2 |
| WU-4 Documentation & Skills | repo root, `Docs/`, `~/.claude/skills/` | 2 | 3 | WU-3 |
| WU-5 Release & Pilot Rollout | repo root, `~/Projects/podcasts/confessions` | 2 | 4 | WU-4 |

---

## WU-1 — Cast Model & Parser

Requirements `EC-1` … `EC-5`. Purely additive: SwiftProyecto still owns `cast:` when this work unit lands. Nothing outside `Sources/SwiftEchada/` changes behaviour.

### Sortie 1: Move `CastMember` and `Gender` into the SwiftEchada library

**Entry criteria**:
- [ ] First sortie — no prerequisites
- [ ] OQ-3 (`AnyCodable` vendor vs. import) resolved

**Tasks**:
1. Create `Sources/SwiftEchada/CastMember.swift` defining `public struct CastMember` and `public enum Gender`, ported from `pkg/SwiftProyecto/Sources/SwiftProyecto/Models/CastMember.swift`. Conformances: `Codable`, `Sendable`, `Equatable`, `Hashable`, `Identifiable`.
2. Preserve every decoding form currently in the wild: `voicePrompt` plus the legacy `voiceDescription` alias; `voices` as both a scalar (`voxalta: path.vox`) and an array (`voxalta: [path.vox]`).
3. Add the new optional `portrait: String?` field (`D4`, §3.2) — project-relative path, manually populated, no generator.
4. Preserve `extraKeys` lossless round-trip (`EC-2`) — unknown per-member keys such as `bio:` decode into `extraKeys` and re-emit verbatim.
5. Satisfy `EC-5` by resolving `AnyCodable` per OQ-3's decision, without introducing any SwiftEchada → SwiftProyecto reverse edge.
6. Add `Tests/SwiftEchadaTests/CastMemberTests.swift` covering: `voiceDescription` → `voicePrompt` decode, scalar-`voices` decode, array-`voices` decode, `portrait` encode/decode, and `bio` surviving a decode→encode cycle inside `extraKeys`.

**Exit criteria**:
- [ ] `Sources/SwiftEchada/CastMember.swift` exists and declares `public struct CastMember` and `public enum Gender`
- [ ] `grep -c 'import SwiftEchada' pkg/SwiftProyecto/Sources -r` returns `0` (no reverse dependency introduced)
- [ ] `make build` exits 0
- [ ] `make test` exits 0
- [ ] `CastMemberTests` contains at least one test per decode form listed in task 6, and all pass

---

### Sortie 2: `CastDocument` and `CastMarkdownParser`

**Entry criteria**:
- [ ] Sortie 1 exit criteria met (`CastMember` and `Gender` exist in `Sources/SwiftEchada/`)
- [ ] OQ-4 (`type:` discriminator collision) resolved

**Tasks**:
1. Add the `marcprux/universal` package dependency to `Package.swift` and wire it into the `SwiftEchada` library target only (`EC-4`).
2. Create `Sources/SwiftEchada/CastDocument.swift` — `public struct CastDocument` holding `cast: [CastMember]`, `body: String`, and front-matter-level fields including `type` (`EC-3`).
3. Create `Sources/SwiftEchada/CastMarkdownParser.swift` with `parse(fileURL:)`, `parse(content:)`, `generate(document:)`, and `write(document:to:)` (`EC-4`).
4. Port `renderCast` (`pkg/SwiftProyecto/.../ProjectMarkdownParser.swift:280`) and `replacingCastBlock` (`:346`) plus the YAML emit/escape logic. Port `replacingCastBlock` deliberately — it is needed twice: CAST.md write-back and EC-10's `cast:` excision.
5. Implement the file-acceptance rule per OQ-4's resolution so that a `.md` file carrying `type: cast` but no `cast:` key is not mistaken for a cast document.
6. Add `Tests/SwiftEchadaTests/CastMarkdownParserTests.swift`: parse→generate round-trip byte-stability; markdown body preserved verbatim across a write-back that mutates only `cast:`; `extraKeys` (`bio:`) preserved; a `type: cast` file with no `cast:` key is rejected.

**Exit criteria**:
- [ ] `Package.swift` declares `marcprux/universal` and the `SwiftEchada` target depends on it
- [ ] `Sources/SwiftEchada/CastDocument.swift` and `Sources/SwiftEchada/CastMarkdownParser.swift` exist
- [ ] `CastMarkdownParser` exposes all four methods named in task 3
- [ ] A round-trip test asserts `generate(parse(x)) == x` for a fixture containing a body, `bio:`, and scalar `voices:`
- [ ] A body-preservation test asserts the markdown body is byte-identical after a cast-only mutation
- [ ] `make build` exits 0 and `make test` exits 0

---

## WU-2 — Non-Destructive Rollout Commands

Requirements `EC-6` … `EC-11`. Generation, verification, and removal are three separate, separately-triggered commands with a human gate between them (`D7`). Nothing here may fuse generation and removal.

### Sortie 3: Legacy `cast:` read path

**Entry criteria**:
- [ ] Sortie 2 exit criteria met (`CastMarkdownParser` builds and round-trips)

**Tasks**:
1. Create a legacy read path (`EC-6`) that extracts `cast:` from a `PROJECT.md` front matter **as raw YAML**, decoding into `[CastMember]` without touching `ProjectFrontMatter.cast`.
2. Mark it clearly as temporary — it is deleted at step 7 once SwiftProyecto 5.0 ships. Include that in the doc comment so it is greppable later.
3. Handle the absent case: a `PROJECT.md` with no `cast:` returns empty, not an error.
4. Support both scalar and array `voices` forms and the `voiceDescription` alias, matching Sortie 1's decoding.
5. Add tests covering: a real-shaped `PROJECT.md` fixture with `bio:` and scalar `voices:`; a `PROJECT.md` with no `cast:`; a `PROJECT.md` whose `appSections` (`episodes_index`, `tts`) must be ignored, not consumed.

**Exit criteria**:
- [ ] The legacy reader compiles with zero references to `ProjectFrontMatter.cast` (`grep -n 'frontMatter\.cast' <new file>` returns nothing)
- [ ] A test parses a fixture `PROJECT.md` containing scalar `voices:` and per-member `bio:` and asserts both survive into `[CastMember]`
- [ ] A test asserts a `cast:`-less `PROJECT.md` yields an empty array and does not throw
- [ ] `make test` exits 0

---

### Sortie 4: Seeded, non-destructive `echada generate cast` → CAST.md

**Entry criteria**:
- [ ] Sortie 3 exit criteria met (legacy read path available)
- [ ] OQ-1 (CAST.md location convention) resolved
- [ ] OQ-2 (command names) resolved

**Tasks**:
1. Rewire `Sources/EchadaCLICore/GenerateCastCommand.swift` to write `CAST.md` via `CastMarkdownParser` instead of `PROJECT.md`'s `cast:`. It still reads `PROJECT.md` through SwiftProyecto for `title`, `episodesDir`, `filePattern`.
2. Implement seeding (`EC-7`): when `CAST.md` is absent **and** `PROJECT.md` carries a legacy `cast:`, seed that cast into `CAST.md` verbatim — every field including `voicePrompt`, `bio`/`extraKeys`, `language`, and `voices.voxalta` paths — then merge newly-discovered characters on top with the existing additive merge.
3. Guarantee `PROJECT.md` is never written by this command. Remove the `parser.write(frontMatter:body:to:)` call at `GenerateCastCommand.swift:171`.
4. Preserve current flag semantics (`EC-8`): default is additive and non-clobbering; `--force` re-syncs to discovered characters; `--dry-run` prints the resulting cast without writing.
5. Add the `--cast` option (`EC-13`, default `CAST.md`) resolved per OQ-1's decision.
6. Add tests: seeding fidelity against a `confessions`-shaped fixture (assert `bio`, multi-line `voicePrompt`, and scalar `voices` all survive); idempotency (two consecutive runs produce byte-identical `CAST.md`); `PROJECT.md` byte-identical before and after; `--force` re-sync; `--dry-run` writes nothing.

**Exit criteria**:
- [ ] `grep -n 'withCast\|frontMatter\.cast' Sources/EchadaCLICore/GenerateCastCommand.swift` returns nothing
- [ ] A test asserts the `PROJECT.md` fixture is byte-identical (SHA-256 match) before and after `generate cast`
- [ ] A seeding test asserts `bio`, `voicePrompt`, `language`, and `voices.voxalta` from the legacy `cast:` all appear in the generated `CAST.md`
- [ ] An idempotency test asserts two consecutive runs produce byte-identical `CAST.md`
- [ ] A `--dry-run` test asserts no `CAST.md` is created
- [ ] `make build` exits 0 and `make test` exits 0

---

### Sortie 5: Verification command (`EC-9`)

**Entry criteria**:
- [ ] Sortie 4 exit criteria met (`generate cast` writes `CAST.md`)
- [ ] OQ-2 (command names) resolved

**Tasks**:
1. Create the verification command under the name chosen in OQ-2. It compares a project's `CAST.md` against the legacy `cast:` still present in its `PROJECT.md`.
2. Report three divergence classes: characters present in one file and not the other; differing field values on a matched character; `.vox` paths in `CAST.md` that do not resolve to an existing file on disk.
3. Exit non-zero on any divergence so it can gate CI or a rollout loop. Exit zero when clean.
4. Report only — never fix, never write. This is the human gate.
5. Register the command in `Sources/EchadaCLICore/EchadaCLI.swift`'s `subcommands` list (or the `generate`-parallel namespace chosen in OQ-2).
6. Add tests: identical cast → exit 0; a character missing from `CAST.md` → non-zero with that name in the output; a differing `voicePrompt` → non-zero naming the field; a dangling `.vox` path → non-zero naming the path; assert neither file is modified in any case.

**Exit criteria**:
- [ ] The command appears in `echada --help` output
- [ ] A test asserts exit code 0 for a matching `CAST.md` / `PROJECT.md` pair
- [ ] A test asserts non-zero exit for each of the three divergence classes in task 2
- [ ] A test asserts both input files are byte-identical after every verification run
- [ ] `make build` exits 0 and `make test` exits 0

---

### Sortie 6: Removal command (`EC-10`) and losslessness test (`EC-11`)

**Entry criteria**:
- [ ] Sortie 5 exit criteria met (verification command exists and gates on divergence)

**Tasks**:
1. Create the removal command under the name chosen in OQ-2. It strips only the `cast:` block from `PROJECT.md`, preserving all other front matter and the body byte-for-byte. `appSections` (`episodes_index`, `tts`, …) must survive — this is the issue-#44 failure class.
2. Use the ported `replacingCastBlock` line-span excision rather than a field-by-field front matter rebuild.
3. Refuse to run unless a `CAST.md` exists **and** the Sortie 5 verification passes. Exit non-zero with an actionable message otherwise.
4. Support `--dry-run`, printing the exact diff it would apply.
5. Make it idempotent: a `PROJECT.md` with no `cast:` is a no-op with a clear message and a zero exit.
6. Ensure no other command invokes it — it is only ever run explicitly.
7. Add the `EC-11` losslessness test: against a copy of a real podcast `PROJECT.md` (use `confessions`, per `PC-6`), seed to `CAST.md`, assert every cast field including `bio`/`extraKeys` is present, run verification clean, run removal, then assert the residual `PROJECT.md` differs from the original **only** by removal of the `cast:` block.

**Exit criteria**:
- [ ] The command appears in `echada --help` output
- [ ] A test asserts the command exits non-zero when `CAST.md` is absent
- [ ] A test asserts the command exits non-zero when verification diverges
- [ ] A test asserts a second consecutive run is a no-op with exit 0
- [ ] A `--dry-run` test asserts `PROJECT.md` is byte-identical afterward
- [ ] The `EC-11` round-trip test passes and asserts the residual `PROJECT.md` diff contains only `cast:`-block line removals — no `appSections` change, no reordering
- [ ] `grep -rn '<removal command symbol>' Sources/ | grep -v '<its own file>' | grep -v EchadaCLI.swift` returns nothing (never invoked implicitly)
- [ ] `make test` exits 0

---

## WU-3 — Command Rewiring

Requirements `EC-12` … `EC-18`, `EC-21`, `EC-22`. After this work unit, no SwiftEchada command reads or writes `PROJECT.md`'s `cast:` except the WU-2 legacy read path and removal command.

### Sortie 7: Rewire `generate prompt` and `generate vox` to CAST.md

**Entry criteria**:
- [ ] Sortie 6 exit criteria met (full generate → verify → prune chain lands and round-trips)

**Tasks**:
1. Rewire `Sources/EchadaCLICore/GeneratePromptCommand.swift` to read and write `CAST.md` via `CastMarkdownParser`. It still reads `PROJECT.md` for `title` and `tts.model` via SwiftProyecto (`EC-12`).
2. Rewire `Sources/EchadaCLICore/GenerateVoxCommand.swift` the same way, replacing the `withCast(_:)` write-back path at `:99-101` and `:220-225`.
3. Add the `--cast` option to both (`EC-13`, default `CAST.md`), resolved per OQ-1, matching Sortie 4's resolution logic exactly.
4. Implement `EC-14`: when `CAST.md` is absent, both commands fail with an actionable error naming `echada generate cast`. They must not create it.
5. Update `Sources/EchadaCLICore/CastVoiceGenerator.swift` so `.vox` files are still written to `voices/` and paths recorded in `voices.voxalta`, now CAST.md-relative (`EC-16`).
6. Update `Sources/SwiftEchada/CharacterMerger.swift` for the new `CastMember` location, behaviour unchanged (`EC-17`).

**Exit criteria**:
- [ ] `grep -n 'frontMatter\.cast\|withCast' Sources/EchadaCLICore/GeneratePromptCommand.swift Sources/EchadaCLICore/GenerateVoxCommand.swift` returns nothing
- [ ] `echada generate prompt --help` and `echada generate vox --help` both list `--cast`
- [ ] A test asserts each command exits non-zero with a message containing `echada generate cast` when `CAST.md` is absent
- [ ] A test asserts `.vox` paths written into `CAST.md` resolve relative to the `CAST.md` directory
- [ ] `CharacterMergerTests` passes unchanged in behaviour
- [ ] `make build` exits 0 and `make test` exits 0

---

### Sortie 8: `echada cast` orchestrator and body-preservation regression

**Entry criteria**:
- [ ] Sortie 7 exit criteria met (all three `generate` stages read/write `CAST.md`)

**Tasks**:
1. Update `Sources/EchadaCLICore/CastCommand.swift` so its bootstrap ensures a `CAST.md` alongside the existing `PROJECT.md` bootstrap (`EC-15`).
2. Cascade `--cast` from `CastCommand` to every stage it invokes, alongside the existing `--force` cascade.
3. Assert by construction that `CastCommand` never invokes the `EC-10` removal command.
4. Add the `EC-18` body-preservation regression test: a `CAST.md` with hand-authored `## Major Characters` body content survives a full `echada cast` run byte-for-byte in its body region. This is the issue-#44 class — a field-by-field front matter rebuild that silently destroyed `appSections`.
5. Add a companion assertion that `PROJECT.md` is untouched by an `echada cast` run.

**Exit criteria**:
- [ ] `echada cast --help` lists `--cast`
- [ ] A test asserts a hand-authored `CAST.md` markdown body is byte-identical after a full `echada cast` run
- [ ] A test asserts `PROJECT.md` is byte-identical after a full `echada cast` run
- [ ] `grep -n '<removal command symbol>' Sources/EchadaCLICore/CastCommand.swift` returns nothing
- [ ] `make build` exits 0 and `make test` exits 0

---

### Sortie 9: Migrate the existing test suite

**Entry criteria**:
- [ ] Sortie 8 exit criteria met (orchestrator rewired, body preservation proven)

**Tasks**:
1. Update the ten affected test files named in `EC-21` to construct and assert against `CAST.md` rather than `PROJECT.md`'s `cast:`: `CastPipelineTests`, `GenerateCastCommandTests`, `GenerateVoxCommandTests`, `GenerateVoxWriteBackTests`, `VoicePromptRoundTripTests`, `PerLanguagePromptTests`, `ModelBackedGenerationTests`, `CastingLanguageResolutionTests`, `NonEnglishPassthroughTests`, `CharacterMergerTests`.
2. Convert every test fixture that embeds a `cast:` block in a `PROJECT.md` string into the paired `PROJECT.md` + `CAST.md` shape.
3. Switch `import SwiftProyecto` to targeted `import struct SwiftEchada.CastMember` in every test file that sees both modules (`CLAUDE.md` rule 3 — both modules export `CastMember` for the whole transition window).
4. Audit the `EC-22` coverage list against what Sorties 1–8 already added, and fill any gap: CAST.md parse/generate round-trip, `extraKeys` preservation, body preservation, legacy `voiceDescription` decode, scalar-`voices` decode, seeding fidelity, `EC-7` idempotency, `EC-9` divergence detection, `EC-10` idempotency and PROJECT.md preservation, missing-CAST.md error paths.
5. Write the audit result into the sortie's completion notes as a checklist of the ten `EC-22` items with the test name that covers each.

**Exit criteria**:
- [ ] `grep -rn 'frontMatter\.cast\|withCast' Tests/` returns nothing
- [ ] All ten `EC-21` test files compile and pass
- [ ] Every one of the ten `EC-22` coverage items maps to a named, passing test
- [ ] `make test` exits 0 with zero skipped tests among the migrated files

---

## WU-4 — Documentation & Skills

Requirements `EC-19`, `EC-20`. No code changes.

### Sortie 10: Repository documentation (`EC-19`)

**Entry criteria**:
- [ ] Sortie 9 exit criteria met (full suite green against CAST.md)

**Tasks**:
1. Update `AGENTS.md`, `CLAUDE.md`, and `README.md` for the ownership split: `PROJECT.md` is SwiftProyecto's config, `CAST.md` is SwiftEchada's.
2. Update `Docs/architecture.md` with the new `CastDocument` / `CastMarkdownParser` layer and the `SwiftEchada → SwiftProyecto` boundary.
3. Update `Docs/api.md` with `CastMember`, `Gender`, `CastDocument`, `CastMarkdownParser`, and the new `portrait` field.
4. Update `Docs/vox-pipeline.md` — `.vox` paths now recorded in `CAST.md`'s `voices.voxalta`.
5. Update `Docs/gotchas.md` with the transition-window `CastMember` ambiguity and the required targeted-import style.
6. Add a `CHANGELOG.md` entry under `## [1.0.0]` describing the CAST.md extraction, the two new commands, and the fact that `PROJECT.md`'s `cast:` is now read-only legacy.

**Exit criteria**:
- [ ] All eight files listed in `EC-19` have a diff in `git diff --stat`
- [ ] `grep -rn 'cast:' README.md AGENTS.md Docs/` contains no instruction to write cast into `PROJECT.md`
- [ ] `CHANGELOG.md` has a new entry naming both new commands
- [ ] No `.swift` file appears in this sortie's diff

---

### Sortie 11: Global agent skills (`EC-20`)

**Entry criteria**:
- [ ] Sortie 10 exit criteria met (repo docs consistent)
- [ ] OQ-5 (EC-20 timing vs. the embedded signed `echada` binary) resolved

**Tasks**:
1. Update `~/.claude/skills/cast-voices/SKILL.md` — it currently instructs agents to read `voicePrompt`/`voiceDescription` out of `PROJECT.md`. Repoint to `CAST.md`.
2. Update `~/.claude/skills/podcast-audio-plan/SKILL.md` — it currently writes the cast list into `PROJECT.md`. Repoint to `CAST.md`.
3. Apply whatever version-gating OQ-5's decision requires, so the skills do not instruct agents to use a `CAST.md` path against an `echada` binary that predates it.
4. Grep both skill trees for any other `PROJECT.md`-cast reference (helper scripts, examples, reference files) and repoint those too.

**Exit criteria**:
- [ ] `grep -rn 'PROJECT.md' ~/.claude/skills/cast-voices ~/.claude/skills/podcast-audio-plan` contains no cast-read or cast-write instruction
- [ ] Both `SKILL.md` files reference `CAST.md` as the cast source
- [ ] No file inside this repository appears in this sortie's diff

---

## WU-5 — Release & Pilot Rollout

Sequencing step 3's tail and step 4's pilot. `X-2` requires SwiftEchada to be a **real tagged release** before Produciesta can build against it — there is no `sibling()` pattern in that repo and its `Package.resolved` is gitignored.

### Sortie 12: Ship 1.0.0

**Entry criteria**:
- [ ] Sortie 11 exit criteria met (docs and skills consistent)
- [ ] Working tree clean, `make test` green on the mission branch

**Tasks**:
1. Bump the package version to `1.0.0`.
2. Flip `Package.swift` out of the sibling-checkout pattern to remote-only pinned dependencies via `/toggle-sibling-libraries`.
3. Run `make release` and confirm the built `echada` binary reports the new version.
4. Merge to `development`, then open and merge the release PR to `main` per the repo's release convention.
5. Tag and create the GitHub release from `main`.

**Exit criteria**:
- [ ] `git tag --list` contains the new version tag and it is reachable from `main`
- [ ] `gh release view <tag>` exits 0
- [ ] `Package.swift` on the tagged commit contains no `sibling(` helper and no local path dependencies
- [ ] `echada --version` from the release build prints the new version

---

### Sortie 13: Pilot rollout on `confessions` (`PC-6`)

**Entry criteria**:
- [ ] Sortie 12 exit criteria met (tagged release exists, `echada` installed from it)
- [ ] OQ-6 (rollout scope) resolved

**Tasks**:
1. In `~/Projects/podcasts/confessions`, confirm a clean working tree, then run `echada generate cast` to produce `CAST.md` from the existing legacy `cast:`.
2. Run the Sortie 5 verification command and confirm it exits 0.
3. Confirm every `.vox` path in `CAST.md` resolves to an existing file (`PC-5`).
4. Run `echada generate vox --dry-run` and confirm it lists the same members as a pre-rollout run against the legacy `cast:`.
5. Confirm `git diff PROJECT.md` is empty — step 4 is generate-only and leaves `PROJECT.md` byte-identical.
6. Commit `CAST.md` alone as a single commit in the `confessions` repo (`PC-2` — generation and removal are separate commits so either reverts independently).
7. Stop. Do not run the removal command, and do not touch any other podcast repo — `PC-6` requires a human to eyeball this `CAST.md` first, and step 6 removal is blocked on Produciesta shipping.

**Exit criteria**:
- [ ] `~/Projects/podcasts/confessions/CAST.md` exists and contains every character from the legacy `cast:`, including each `bio` and `voicePrompt`
- [ ] The verification command exits 0 in `confessions`
- [ ] `git -C ~/Projects/podcasts/confessions diff HEAD~1 --name-only` lists `CAST.md` and nothing else
- [ ] `git -C ~/Projects/podcasts/confessions diff HEAD~1 -- PROJECT.md` is empty
- [ ] No file under `~/Projects/podcasts/` outside `confessions` was modified

---

## Open Questions

<!-- Consumed by Pass 1 of refine (`refine-blockers`). Each entry MUST be resolved before refinement can proceed past Pass 1. -->

### OQ-1: CAST.md location — convention or declared in PROJECT.md?
**Affects**: Sortie 4, Sortie 7, Sortie 8
**Question**: Is `CAST.md` located purely by convention (sibling of `PROJECT.md`, overridable with `--cast`), or may `PROJECT.md` declare `castFile: CAST.md`?
**Source**: `REQUIREMENTS-cast-md-changes.md` §9 Q1 (lines 437–440)
**Why blocking**: Sortie 4 cannot implement `--cast` resolution, and Sortie 7 cannot mirror it, without knowing whether a `PROJECT.md` key can override the default.
**Recommendation**: Convention only. `--cast` defaults to `CAST.md` resolved as a sibling of `--project` when relative. No `castFile:` key.
**Rationale**: The requirements doc itself recommends this, and a `castFile:` key would put a cast concern back into `PROJECT.md`, directly contradicting `D1`'s ownership split — the entire point of the effort.

### OQ-2: Command names for verification (`EC-9`) and removal (`EC-10`)
**Affects**: Sortie 4, Sortie 5, Sortie 6, Sortie 8
**Question**: What are the two command verbs? They must read as clearly separate and clearly non-destructive vs. destructive, and must not be confused with `echada cast`, which is the full-pipeline orchestrator.
**Source**: `REQUIREMENTS-cast-md-changes.md` §9 Q3 (lines 447–451)
**Why blocking**: Sorties 5 and 6 cannot name a file, register a subcommand, or write a greppable exit criterion without the verb. Sorties 4 and 8 reference the names in error messages and negative assertions.
**Recommendation**: `echada verify cast` and `echada prune cast`, each a top-level namespace parallel to the existing `generate` namespace — matching `GenerateCommand.swift`'s structure with new `VerifyCommand`/`PruneCommand` container types registered in `EchadaCLI.swift:30-33`.
**Rationale**: The requirements doc recommends exactly this. The `generate cast` / `verify cast` / `prune cast` triad reads as three verbs over one noun, keeps `echada cast` unambiguously the orchestrator, and reuses the container-command pattern already in the codebase.

### OQ-3: `AnyCodable` — vendor into SwiftEchada or import from SwiftProyecto?
**Affects**: Sortie 1
**Question**: `EC-5` requires `AnyCodable` in the `SwiftEchada` target. Vendor a copy or consume SwiftProyecto's public type?
**Source**: `REQUIREMENTS-cast-md-changes.md` §9 Q4 (lines 452–455)
**Why blocking**: Sortie 1 cannot write `CastMember.extraKeys` without deciding which `AnyCodable` it stores, and a wrong choice silently changes round-trip fidelity.
**Recommendation**: Import from SwiftProyecto. Do not vendor.
**Rationale**: `Package.swift:47-51` already makes `SwiftProyecto` the sole dependency of the `SwiftEchada` target, and `EC-12` keeps SwiftEchada reading `PROJECT.md` forever, so the dependency cannot be dropped anyway. Vendoring risks divergence in the exact JSON round-trip semantics that make `extraKeys` and `appSections` lossless — the property `EC-2` and `EC-18` both depend on.

### OQ-4: `type: cast` discriminator collides with the requirements docs themselves
**Affects**: Sortie 2
**Question**: The repo-wide frontmatter policy forces `type:` onto every `.md`, so the three sibling `REQUIREMENTS-cast-md-changes.md` files also declare `type: cast`. Narrow the discriminator to `type: echada-cast`, or have `CastMarkdownParser` additionally require a `cast:` key?
**Source**: `REQUIREMENTS-cast-md-changes.md` §3.1 (lines 102–105) and §9 Q6 (lines 458–464)
**Why blocking**: Sortie 2's file-acceptance rule is the deliverable. A naive `type: cast` scan currently matches this very execution plan's source document.
**Recommendation**: Require **both** `type: cast` and a `cast:` key in `CastMarkdownParser`, and relabel the three requirements docs to `type: requirements`.
**Rationale**: The requirements doc recommends this, and it matches Produciesta's own convention for this document class (`Docs/REQUIREMENTS-fcpxml-export.md` uses `type: requirements`). Note: `breakdown` deliberately left `REQUIREMENTS-cast-md-changes.md`'s `type: cast` untouched pending this decision — relabelling is part of resolving it, and the sibling docs in `pkg/SwiftProyecto` and `apps/Produciesta` need the same treatment.

### OQ-5: `EC-20` skill update timing vs. the embedded signed `echada` binary
**Affects**: Sortie 11
**Question**: `X-4` states the `echada` binary is embedded and code-signed inside `Produciesta.app`, so an `EC-20` skill update depends on a Produciesta *release*, not just a doc edit. Do the skills get updated now, or held until Produciesta ships (step 5, out of this mission's scope)?
**Source**: `REQUIREMENTS-cast-md-changes.md` §5 `X-4` (lines 350–351) and `EC-20` (lines 222–223)
**Why blocking**: Sortie 11 either runs or is cut. If it runs unconditionally it points `cast-voices` at a `CAST.md` path that the signed binary inside the currently-shipped `Produciesta.app` cannot produce, breaking every agent that invokes the skill.
**Recommendation**: Update both skills now, but make each one detect capability at runtime rather than assume it — check `echada --version` (or probe for the `verify cast` subcommand) and fall back to the `PROJECT.md` path when the available binary predates the release from Sortie 12.
**Rationale**: `X-4` establishes the real constraint but the skills are global and used against directly-installed `echada` (Homebrew) as well as the embedded copy, so a hard cut breaks the Homebrew path needlessly while an unconditional edit breaks the embedded path. Capability detection is the only option that is correct for both, and it costs one shell check.

### OQ-6: Rollout scope — pilot only, or all 12 podcast repos?
**Affects**: Sortie 13
**Question**: Does this mission stop after the `confessions` pilot, or does it roll `CAST.md` generation out to all 12 podcast repos carrying a `cast:` block?
**Source**: `REQUIREMENTS-cast-md-changes.md` §6 step 4 (line 379), §7 `PC-3`/`PC-4`/`PC-6` (lines 402–409)
**Why blocking**: Sortie 13's exit criteria assert that no repo outside `confessions` was modified. If the full rollout is in scope, WU-5 needs eleven more sorties and a decision on `common-voices` (`PC-4` — not a git repo).
**Recommendation**: Pilot only. This mission ends after `confessions` is generated, verified, and committed. Track the remaining 11 repos as a follow-on mission.
**Rationale**: `PC-6` explicitly forbids rolling out further until the pilot's `CAST.md` is eyeballed by a human and its `PROJECT.md` diff confirmed cast-block-only — that is a human gate this mission cannot pass on its own. `PC-3` also forbids cross-repo batching, so the remaining work is eleven independent commits with no shared context, which is a poor fit for the same mission.

---

## Cross-Repo Risks Carried Into This Mission

Not open questions — decided, but each sortie owner should know them.

| Risk | Impact here | Mitigation in this plan |
|---|---|---|
| **Diamond dependency** (§5): `SwiftEchada → SwiftVoxAlta → SwiftHablare → SwiftProyecto 4.x` vs. `SwiftEchada → SwiftProyecto 5.x` | None until step 7. This mission never raises the SwiftProyecto floor | Sortie 12 ships against the current `4.6.1` floor. SwiftHablare's phantom dependency removal is a separate, out-of-scope effort |
| **Transition-window type ambiguity** (§5): both `SwiftProyecto` and `SwiftEchada` export `CastMember` until SwiftProyecto 5.0 | Every file that imports both modules is a compile error waiting to happen | Targeted imports mandated in the standing constraints; Sortie 9 task 3 sweeps the test suite; `Docs/gotchas.md` records it in Sortie 10 |
| **`X-1` — `CastWriter` prunes** (`apps/Produciesta`) | Not this repo's code, but `EC-8`'s additive-only guarantee is the contract Produciesta must conform to | Sortie 4 proves additive-only with an idempotency test, giving Produciesta a reference behaviour to match |
| **Issue #44 class** — field-by-field front matter rebuild silently destroys `appSections` | Directly reproducible by `EC-10` if it rebuilds instead of excising | Sortie 6 task 2 mandates line-span excision via `replacingCastBlock`; Sortie 6 and Sortie 8 both assert byte-identity |

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 5 |
| Total sorties | 13 |
| Requirements in scope | 28 (`EC-1`…`EC-22`, `PC-1`…`PC-6`) |
| Atomic tasks | 74 |
| Open questions | 6 |
| Dependency structure | layers (0 → 4, strictly sequential between layers; no intra-layer parallelism identified yet) |
