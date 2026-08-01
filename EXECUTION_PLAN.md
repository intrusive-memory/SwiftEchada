---
type: execution-plan
target_version: 1.0.0
---

# EXECUTION_PLAN.md — SwiftEchada: CAST.md Extraction

## Terminology

> **Mission** — A definable, testable scope of work. Defines scope, acceptance criteria, and dependency structure.

> **Sortie** — An atomic, testable unit of work executed by a single autonomous AI agent in one dispatch. One aircraft, one mission, one return.

> **Work Unit** — A grouping of sorties (package, component, phase).

> **Human Gate** — A checkpoint the supervisor cannot pass on its own. Requires a human action or decision before the next sortie is dispatched.

---

## Revision Note

This is the **second pass**. The first draft (commit `0228d97`) was validated against the SwiftEchada
source tree, `Package.swift`, the Makefile, SwiftProyecto's sources, SwiftHablare's manifest, and
`~/Projects/podcasts/confessions/PROJECT.md`. Corrections are recorded inline and summarised in
[§ Corrections to the First Draft](#corrections-to-the-first-draft). Sortie numbering is unchanged so
that references from the sibling repo docs still resolve.

---

## Mission Scope

**Source**: `REQUIREMENTS-cast-md-changes.md` (the controlling document for a three-repo effort).

**In scope** — SwiftEchada requirements `EC-1` … `EC-22`, corresponding to sequencing steps 1–3, plus
the release that step 3 gates on, plus the `confessions` pilot rollout (`PC-1`, `PC-2`, `PC-5`,
`PC-6`) that validates the whole chain.

**Out of scope** — deliberately excluded, each has its own owner:

| Excluded | Owner | Why |
|---|---|---|
| Step 0 — SwiftHablare phantom `SwiftProyecto` dependency | `pkg/SwiftHablare` | Different repo. **Verified phantom**: `Package.swift:65-66,74` declares it, `Sources/` and `Tests/` reference it zero times. Blocks step 7 only, never this mission — see OQ-7 |
| Step 4 — remaining 11 podcast repos | `~/Projects/podcasts/*` | `PC-6` forbids rolling out past the pilot until `confessions` is eyeballed by a human. See OQ-6 |
| Step 5 — Produciesta repoint | `apps/Produciesta` | Own requirements doc (`PD-1` … `PD-40`) |
| Step 6 — `cast:` removal across podcast repos | `~/Projects/podcasts/*` | Gated on step 5 shipping. Removing before Produciesta is repointed is silent data loss (§6) |
| Step 7 — SwiftProyecto 5.0 deletions | `pkg/SwiftProyecto` | Own requirements doc (`PR-0` … `PR-31`) |
| `PC-3` (no cross-repo batching), `PC-4` (`common-voices` is not a git repo) | follow-on rollout mission | Both are constraints on the 11-repo rollout excluded above. Neither applies to a single-repo pilot |
| `DEF-1` … `DEF-4` | tracked separately | Explicitly deferred by §8 |

**Standing constraints** (from `CLAUDE.md` and the requirements doc, apply to every sortie):

- Never `swift build` / `swift test`. Use `make build` / `make test`. Test scheme is `SwiftEchada-Package`.
- Targeted imports in files that see both modules: `import struct SwiftEchada.CastMember`, not
  `import SwiftEchada`. Both `SwiftProyecto` and `SwiftEchada` export `CastMember` and `Gender` for
  the whole transition window.
- Dependency direction is `SwiftEchada → SwiftProyecto`, never the reverse (`D6`).
- **No sortie in this mission modifies any file outside this repository**, with the two explicitly
  scoped exceptions of Sortie 11 (`~/.claude/skills/`) and Sortie 13
  (`~/Projects/podcasts/confessions`). In particular `pkg/SwiftProyecto`, `pkg/SwiftHablare`, and
  `apps/Produciesta` are read-only to this mission.
- `PROJECT.md` is never written by any command in WU-1 … WU-3 except the dedicated prune command
  (`EC-10`). Generation and removal never fuse (`D7`).

### Decision consequences carried by this plan

Not open questions — settled by the requirements doc, but each has a concrete downstream cost that a
sortie must pay.

| Consequence | Origin | Paid by |
|---|---|---|
| The `SwiftEchada` **library** target gains a second dependency, `marcprux/universal`. This invalidates `CLAUDE.md` rule 4 ("Library depends only on SwiftProyecto") and `AGENTS.md`/`Docs/dependencies.md` alongside it | `EC-4` mandates it; §10 justifies keeping the cast processor in the library so GUIs can import it | Sortie 2 (manifest + `make generate-deps`), Sortie 10 (rule 4 rewrite) |
| `Sources/EchadaCLICore/Generated/DependencyVersions.swift` is generated from the manifest and is CI-drift-checked (`make verify-deps`) | Adding any dependency changes it | Sortie 2 must run `make generate-deps` and commit the regenerated file |
| `CharacterProfile.gender`'s type changes module from `SwiftProyecto.Gender` to `SwiftEchada.Gender`. `CharacterProfile` is public API of the light `SwiftEchada` library that `ProduciestaCore` already links | `EC-1` moves `Gender` | Sortie 1 must keep the spelling `Gender` unqualified at all four in-repo use sites so the change is source-compatible |

---

## Work Units

| Work Unit | Directory | Sorties | Layer | Dependencies | Intra-layer parallelism |
|-----------|-----------|---------|-------|-------------|--------------------------|
| WU-1 Cast Model & Parser | `Sources/SwiftEchada/` | 2 | 0 | none | none — Sortie 2 needs Sortie 1's types |
| WU-2 Non-Destructive Rollout Commands | `Sources/EchadaCLICore/` | 4 | 1 | WU-1 | none dispatched (see § Parallelism) |
| WU-3 Command Rewiring | `Sources/EchadaCLICore/`, `Tests/SwiftEchadaTests/` | 3 | 2 | WU-2 | none — each sortie's exit gate is a green build |
| WU-4 Documentation & Skills | repo root, `Docs/`, `~/.claude/skills/` | 2 | 3 | WU-3 | **Sortie 10 ∥ Sortie 11** — disjoint file sets, neither builds |
| WU-5 Release & Pilot Rollout | repo root, `~/Projects/podcasts/confessions` | 2 | 4 | WU-4 | none — Sortie 13 needs Sortie 12's tag, with HG-1 between |

---

## Parallelism

Declared parallelism is deliberately minimal, for one structural reason: **every sortie in WU-1 …
WU-3 carries `make build` / `make test` in its exit criteria, and those cannot run concurrently in a
single worktree.** Two agents invoking `xcodebuild` against the same `DerivedData` will corrupt each
other's artifacts and produce non-reproducible pass/fail.

| Pair | Verdict | Reasoning |
|---|---|---|
| **Sortie 10 ∥ Sortie 11** | **SAFE — dispatch in parallel** | Sortie 10 touches only files inside the repo; Sortie 11 touches only `~/.claude/skills/`. Zero file overlap, and neither sortie builds or tests. This is the only genuinely free parallelism in the plan |
| Sortie 4 ∥ Sortie 5 | **Code-disjoint but build-serialized — keep sequential** | Sortie 5's verification command reads `CAST.md` and the legacy `cast:`; it depends on Sortie 2 and Sortie 3, not on Sortie 4. The file sets barely overlap (`EchadaCLI.swift` subcommand list only). But both gate on `make test`, so parallel dispatch requires the supervisor to own a single serialized build. The coordination cost exceeds the saving for two sorties |
| Sortie 1 ∥ Sortie 3 | **UNSAFE** | Sortie 3's legacy reader decodes into `CastMember`, which Sortie 1 creates |
| Anything ∥ Sortie 12 | **UNSAFE** | Sortie 12 mutates `Package.swift` and the version, and its exit gate is a clean release build |

**Dependency ordering was re-verified and is correct as declared**, with one refinement recorded
above: Sortie 5 does not actually depend on Sortie 4, and its entry criteria have been relaxed to say
so. Everything else is a genuine data or artifact dependency.

---

## WU-1 — Cast Model & Parser

Requirements `EC-1` … `EC-5`. Purely additive: SwiftProyecto still owns `cast:` when this work unit
lands. Nothing outside `Sources/SwiftEchada/` and `Package.swift` changes behaviour.

### Sortie 1: Move `CastMember` and `Gender` into the SwiftEchada library

**Entry criteria**:
- [ ] First sortie — no prerequisites
- [ ] OQ-3 (`AnyCodable` vendor vs. import) resolved

**Tasks**:
1. Create `Sources/SwiftEchada/CastMember.swift` defining `public struct CastMember` and
   `public enum Gender`, ported from
   `pkg/SwiftProyecto/Sources/SwiftProyecto/Models/CastMember.swift` (`Gender` at `:32`,
   `CastMember` at `:103` — read-only reference; **do not modify that repo**). Conformances:
   `Codable`, `Sendable`, `Equatable`, `Hashable`, `Identifiable`.
2. Preserve every decoding form currently in the wild: `voicePrompt` plus the legacy
   `voiceDescription` alias; `voices` as both a scalar (`voxalta: path.vox`) and an array
   (`voxalta: [path.vox]`).
3. Add the new optional `portrait: String?` field (`D4`, §3.2) — project-relative path, manually
   populated, no generator.
4. Preserve `extraKeys` lossless round-trip (`EC-2`) — unknown per-member keys such as `bio:` decode
   into `extraKeys` and re-emit verbatim.
5. Satisfy `EC-5` by resolving `AnyCodable` per OQ-3's decision, without introducing any
   SwiftProyecto → SwiftEchada reverse edge.
6. **Absorb the `Gender` module change.** `Gender` is used unqualified at four in-repo sites today —
   `Sources/SwiftEchada/CharacterProfile.swift:10,26` and
   `Sources/EchadaCLICore/VoicePromptSynthesizer.swift:83,121`. Leave those spellings unqualified so
   they bind to the new `SwiftEchada.Gender` without edits, and confirm no site qualifies it as
   `SwiftProyecto.Gender`. (Note: the requirements doc's §10 claim that `Gender` has zero usages
   outside `CastMember.swift` is true **within SwiftProyecto only** — it is false for this repo.)
7. Add `Tests/SwiftEchadaTests/CastMemberTests.swift` with one named test per form:
   `testDecodesLegacyVoiceDescriptionAsVoicePrompt`, `testDecodesScalarVoicesForm`,
   `testDecodesArrayVoicesForm`, `testPortraitRoundTrips`, `testUnknownKeyBioSurvivesRoundTrip`,
   `testAbsentOptionalFieldsAreNotEmitted`.

**Exit criteria**:
- [ ] `Sources/SwiftEchada/CastMember.swift` exists and declares `public struct CastMember` and `public enum Gender`
- [ ] `git status --porcelain` lists no path outside this repository
- [ ] `Tests/SwiftEchadaTests/CastMemberTests.swift` contains all six test function names listed in task 7, and all six pass
- [ ] `make build` exits 0
- [ ] `make test` exits 0

---

### Sortie 2: `CastDocument`, `CastMarkdownParser`, and the `universal` dependency

**Entry criteria**:
- [ ] Sortie 1 exit criteria met (`CastMember` and `Gender` exist in `Sources/SwiftEchada/`)
- [ ] OQ-4 (`type:` discriminator collision) resolved

**Tasks**:
1. Add `marcprux/universal` to `Package.swift`'s `dependencies` and to the `SwiftEchada` **library**
   target only (`EC-4`). Pin the same major line SwiftProyecto uses (`5.3.0`, `.upToNextMajor`) so the
   two never diverge in the resolved graph.
2. Run `make generate-deps` and commit the regenerated
   `Sources/EchadaCLICore/Generated/DependencyVersions.swift`. `make verify-deps` reports drift in CI;
   an uncommitted regeneration produces a permanent CI warning.
3. Create `Sources/SwiftEchada/CastDocument.swift` — `public struct CastDocument` holding
   `cast: [CastMember]`, `body: String`, and front-matter-level fields including `type` (`EC-3`).
4. Create `Sources/SwiftEchada/CastMarkdownParser.swift` with `parse(fileURL:)`, `parse(content:)`,
   `generate(document:)`, and `write(document:to:)` (`EC-4`).
5. Port `renderCast` (`pkg/SwiftProyecto/Sources/SwiftProyecto/Utilities/ProjectMarkdownParser.swift:280`)
   and `replacingCastBlock` (**`:352`** — the first draft said `:346`) plus the YAML emit/escape logic.
   Port `replacingCastBlock` deliberately: it is the CAST.md write-back mechanism, and its
   line-span-splice semantics are what prevent the issue-#44/#55 failure class.
6. Implement the file-acceptance rule per OQ-4's resolution so that a `.md` file carrying
   `type: cast` but no `cast:` key is not mistaken for a cast document.
7. Expose the parse entry point that Sortie 3 will reuse for the legacy read path, so front-matter
   YAML decoding exists in exactly one place.
8. Add `Tests/SwiftEchadaTests/CastMarkdownParserTests.swift` against a checked-in fixture
   `Tests/SwiftEchadaTests/Fixtures/confessions-shaped-CAST.md` (3 members, one `bio:`, scalar
   `voices:`, a `## Major Characters` body): parse→generate byte-stability; body preserved verbatim
   across a write-back that mutates only `cast:`; `extraKeys` (`bio:`) preserved; a `type: cast` file
   with no `cast:` key is rejected.

**Exit criteria**:
- [ ] `Package.swift` declares `marcprux/universal` and only the `SwiftEchada` target lists it
- [ ] `git diff --exit-code Sources/EchadaCLICore/Generated/DependencyVersions.swift` exits 0 after `make generate-deps` (i.e. it was regenerated and committed)
- [ ] `Sources/SwiftEchada/CastDocument.swift` and `Sources/SwiftEchada/CastMarkdownParser.swift` exist
- [ ] `CastMarkdownParser` exposes all four methods named in task 4
- [ ] A test asserts `generate(parse(f)) == f` byte-for-byte for `Fixtures/confessions-shaped-CAST.md`
- [ ] A test asserts the markdown body region is byte-identical after a cast-only mutation
- [ ] A test asserts `parse` rejects a `type: cast` file with no `cast:` key
- [ ] `make build` exits 0 and `make test` exits 0

---

## WU-2 — Non-Destructive Rollout Commands

Requirements `EC-6` … `EC-11`. Generation, verification, and removal are three separate,
separately-triggered commands with a human gate between them (`D7`). Nothing here may fuse generation
and removal.

> **Existing asset — do not rebuild.** `Sources/EchadaCLICore/ProjectCastWriteBack.swift` already
> implements the surgical `cast:` splice against PROJECT.md, routing through
> `ProjectMarkdownParser.replacingCastBlock`, and its doc comment records the exact issue-#44/#55
> corruption modes. Its `applying(cast:to:using:)` explicitly documents that **passing an empty array
> removes the block** — which is `EC-10`'s entire requirement. Sortie 6 reuses it. Sortie 7 removes
> its last generate-stage caller. It survives as the prune command's implementation until step 7.
> The first draft did not mention this file at all.

### Sortie 3: Legacy `cast:` read path

**Entry criteria**:
- [ ] Sortie 2 exit criteria met (`CastMarkdownParser` builds and round-trips)

**Tasks**:
1. Create a legacy read path (`EC-6`) that extracts `cast:` from a `PROJECT.md` front matter **as raw
   YAML**, decoding into `[CastMember]` without touching `ProjectFrontMatter.cast`.
2. Reuse Sortie 2 task 7's front-matter decode rather than duplicating YAML plumbing.
3. Mark it clearly as temporary — it is deleted at step 7 once SwiftProyecto 5.0 ships. Put a
   greppable marker in the doc comment (e.g. `// LEGACY-CAST-READ: delete at SwiftProyecto 5.0`).
4. Handle the absent case: a `PROJECT.md` with no `cast:` returns empty, not an error.
5. Support both scalar and array `voices` forms and the `voiceDescription` alias, matching Sortie 1's
   decoding.
6. Add a checked-in fixture `Tests/SwiftEchadaTests/Fixtures/confessions-PROJECT.md` — a copy of
   `~/Projects/podcasts/confessions/PROJECT.md` (309 lines; `type: project`, 3 cast members, scalar
   `voices:`, one `bio:`, a large `episodes_index` appSection, `introFile`/`outroFile`). This is the
   same fixture `EC-11` needs in Sortie 6.
7. Add tests: the fixture's `bio:` and scalar `voices:` survive into `[CastMember]`; a `cast:`-less
   `PROJECT.md` yields an empty array without throwing; `episodes_index` and `tts` are ignored, not
   consumed into cast.

**Exit criteria**:
- [ ] `grep -n 'frontMatter\.cast' <the new legacy-reader file>` returns nothing
- [ ] `grep -rn 'LEGACY-CAST-READ' Sources/` returns at least one hit
- [ ] `Tests/SwiftEchadaTests/Fixtures/confessions-PROJECT.md` exists and is 309 lines
- [ ] A test parses that fixture and asserts all three characters, the `bio` on `THE PRACTITIONER`, and the scalar `voices.voxalta` path survive
- [ ] A test asserts a `cast:`-less `PROJECT.md` yields an empty array and does not throw
- [ ] `make test` exits 0

---

### Sortie 4: Seeded, non-destructive `echada generate cast` → CAST.md

**Entry criteria**:
- [ ] Sortie 3 exit criteria met (legacy read path available)
- [ ] OQ-1 (CAST.md location convention, and whether `--cast` may point outside the project directory) resolved
- [ ] OQ-2 (command names) resolved

**Tasks**:
1. Rewire `Sources/EchadaCLICore/GenerateCastCommand.swift` to write `CAST.md` via
   `CastMarkdownParser`. It still reads `PROJECT.md` through SwiftProyecto for `title`,
   `episodesDir`, `filePattern`.
2. Implement seeding (`EC-7`): when `CAST.md` is absent **and** `PROJECT.md` carries a legacy `cast:`,
   seed that cast into `CAST.md` verbatim — every field including `voicePrompt`, `bio`/`extraKeys`,
   `language`, and `voices.voxalta` paths — then merge newly-discovered characters on top with the
   existing additive merge (`ProjectFrontMatter.mergeCast(_:_:strategy: .preserveExisting)` at
   `GenerateCastCommand.swift:159-160`, or its CAST.md-side equivalent).
3. **Seeding must not invent fields.** The `confessions` cast has no `actor`, `gender`, `language`, or
   `portrait`. Absent optional fields stay absent in the emitted `CAST.md` — never `null`, never an
   empty string.
4. Guarantee `PROJECT.md` is never written by this command. The call to remove is
   `ProjectCastWriteBack.write(cast:to:using:)` at **`GenerateCastCommand.swift:172`**. (The first
   draft named a nonexistent `parser.write(frontMatter:body:to:)` call at `:171`.)
5. Preserve current flag semantics (`EC-8`): default is additive and non-clobbering; `--force`
   re-syncs to discovered characters; `--dry-run` prints the resulting cast without writing.
6. Add the `--cast` option (`EC-13`, default `CAST.md`) resolved per OQ-1's decision.
7. Add tests: seeding fidelity against `Fixtures/confessions-PROJECT.md` (assert `bio`, the
   multi-line `voicePrompt` on `ESPECTRO FAMILIAR`, and the scalar `voices` form all survive, and
   that no `gender`/`actor`/`language` key is emitted); idempotency (two consecutive runs produce
   byte-identical `CAST.md`); `PROJECT.md` SHA-256 unchanged; `--force` re-sync; `--dry-run` writes
   nothing.

**Exit criteria**:
- [ ] `grep -n 'ProjectCastWriteBack\|frontMatter\.cast' Sources/EchadaCLICore/GenerateCastCommand.swift` returns nothing
- [ ] A test asserts the `PROJECT.md` fixture's SHA-256 is identical before and after `generate cast`
- [ ] A seeding test asserts `bio`, `voicePrompt`, and `voices.voxalta` from the legacy `cast:` all appear in the generated `CAST.md`
- [ ] A seeding test asserts the emitted `CAST.md` contains no `gender:`, `actor:`, `language:`, or `portrait:` key for members that lacked them
- [ ] An idempotency test asserts two consecutive runs produce byte-identical `CAST.md`
- [ ] A `--dry-run` test asserts no `CAST.md` is created
- [ ] `echada generate cast --help` lists `--cast`
- [ ] `make build` exits 0 and `make test` exits 0

---

### Sortie 5: Verification command (`EC-9`)

**Entry criteria**:
- [ ] Sortie 3 exit criteria met (legacy read path available) — **this sortie does not depend on Sortie 4**; it is sequenced after it only because builds are serialized (see § Parallelism)
- [ ] OQ-2 (command names) resolved

**Tasks**:
1. Create the verification command under the name chosen in OQ-2. It compares a project's `CAST.md`
   against the legacy `cast:` still present in its `PROJECT.md`.
2. Report three divergence classes: characters present in one file and not the other; differing field
   values on a matched character; `.vox` paths in `CAST.md` that do not resolve to an existing file on
   disk (resolved relative to the `CAST.md` directory).
3. Exit non-zero on any divergence so it can gate CI or a rollout loop. Exit zero when clean.
4. Report only — never fix, never write. This is the human gate.
5. Register the command per OQ-2's decision. If OQ-2 selects a top-level namespace, add a container
   type mirroring `GenerateCommand.swift` and register it in
   `Sources/EchadaCLICore/EchadaCLI.swift:31-33`'s `subcommands` array (currently
   `[VoiceCommand, CastCommand, GenerateCommand, TestVoiceCommand]`).
6. Update `Tests/SwiftEchadaTests/CLIWiringTests.swift` for the new subcommand — it asserts the
   command tree and will fail otherwise. (`EC-21`'s file list omits it; this plan adds it.)
7. Add tests: identical cast → exit 0; a character missing from `CAST.md` → non-zero with that name
   in stderr; a differing `voicePrompt` → non-zero naming the field; a dangling `.vox` path →
   non-zero naming the path; both input files SHA-256-unchanged in every case.

**Exit criteria**:
- [ ] `echada --help` output contains the OQ-2 verification verb
- [ ] `CLIWiringTests` asserts the verification command is reachable from the root command and passes
- [ ] A test asserts exit code 0 for a matching `CAST.md` / `PROJECT.md` pair
- [ ] Three separate tests assert non-zero exit, one per divergence class in task 2, each asserting the offending name appears in the emitted diagnostics
- [ ] A test asserts both input files are SHA-256-identical after every verification run
- [ ] `make build` exits 0 and `make test` exits 0

---

### Sortie 6: Removal command (`EC-10`) and losslessness test (`EC-11`)

**Entry criteria**:
- [ ] Sortie 4 exit criteria met (seeding produces a `CAST.md`)
- [ ] Sortie 5 exit criteria met (verification command exists and gates on divergence)

**Tasks**:
1. Create the removal command under the name chosen in OQ-2. It strips only the `cast:` block from
   `PROJECT.md`, preserving all other front matter and the body byte-for-byte. `appSections`
   (`episodes_index`, `tts`) and the emitter-forgotten keys (`introFile`, `outroFile`) must survive —
   this is the issue-#44/#55 failure class.
2. **Reuse `ProjectCastWriteBack.applying(cast: [], to:)`** rather than writing a new excision path.
   Its doc comment already specifies that an empty array removes the block, and it is the code path
   already proven against the 309-line `confessions` file. Do **not** rebuild the front matter
   field-by-field.
3. Refuse to run unless a `CAST.md` exists **and** the Sortie 5 verification passes. Exit non-zero
   with an actionable message otherwise.
4. Support `--dry-run`, printing the exact diff it would apply.
5. Make it idempotent: a `PROJECT.md` with no `cast:` is a no-op with a clear message and a zero exit.
6. Ensure no other command invokes it — it is only ever run explicitly.
7. Register it and update `CLIWiringTests` as in Sortie 5 task 6.
8. Add the `EC-11` losslessness test against `Tests/SwiftEchadaTests/Fixtures/confessions-PROJECT.md`
   (copied into a temp dir): seed to `CAST.md`, assert every cast field including `bio`/`extraKeys` is
   present, run verification clean, run removal, then assert the residual `PROJECT.md` differs from the
   original **only** by removal of the `cast:` line span — specifically that `introFile`, `outroFile`,
   `tts`, and the full `episodes_index` structure are byte-identical and in their original positions.

**Exit criteria**:
- [ ] `echada --help` output contains the OQ-2 removal verb
- [ ] `CLIWiringTests` asserts the removal command is reachable and passes
- [ ] A test asserts non-zero exit when `CAST.md` is absent
- [ ] A test asserts non-zero exit when verification diverges
- [ ] A test asserts a second consecutive run exits 0 and leaves `PROJECT.md` SHA-256-identical
- [ ] A `--dry-run` test asserts `PROJECT.md` is SHA-256-identical afterward
- [ ] The `EC-11` test passes and asserts the residual/original diff is exactly the `cast:` line span — zero `episodes_index` lines changed, zero reordering, `introFile`/`outroFile` intact
- [ ] `grep -rn '<OQ-2 removal command symbol>' Sources/ | grep -v '<its own file>' | grep -v 'EchadaCLI.swift' | grep -v '<its container file>'` returns nothing
- [ ] `make test` exits 0

---

## WU-3 — Command Rewiring

Requirements `EC-12` … `EC-18`, `EC-21`, `EC-22`. After this work unit, no SwiftEchada command reads
or writes `PROJECT.md`'s `cast:` except the WU-2 legacy read path and the removal command.

### Sortie 7: Rewire `generate prompt` and `generate vox` to CAST.md

**Entry criteria**:
- [ ] Sortie 6 exit criteria met (full generate → verify → prune chain lands and round-trips)

**Tasks**:
1. Rewire `Sources/EchadaCLICore/GeneratePromptCommand.swift` to read and write `CAST.md` via
   `CastMarkdownParser`. Replace the `frontMatter.cast` read at `:64` and the merge at `:128`. It
   still reads `PROJECT.md` for `title` and `tts.model` via SwiftProyecto (`EC-12`).
2. Rewire `Sources/EchadaCLICore/GenerateVoxCommand.swift` the same way: the `frontMatter.cast` read
   at `:113` and the `ProjectCastWriteBack.write(cast:to:using:)` call at `:212`. Delete the now-stale
   `withCast(_:)` doc comment at `:205-211`.
3. **Retire the generate-stage use of `Sources/EchadaCLICore/ProjectCastWriteBack.swift`.** After this
   sortie its only caller is the Sortie 6 removal command. Update its doc comment to say so, and add a
   `LEGACY-CAST-READ`-style marker recording that it dies at step 7 with the legacy read path.
4. Add the `--cast` option to both (`EC-13`, default `CAST.md`), resolved per OQ-1, sharing Sortie 4's
   resolution helper rather than reimplementing it.
5. Implement `EC-14`: when `CAST.md` is absent, both commands fail with an actionable error containing
   the literal string `echada generate cast`. They must not create it.
6. Update `Sources/EchadaCLICore/CastVoiceGenerator.swift` so `.vox` files are still written to
   `voices/` and paths recorded in `voices.voxalta`, now resolved relative to the `CAST.md` directory
   (`EC-16`). Note `CastVoiceGenerator` holds `projectDirectory`; per OQ-1 this becomes the CAST.md
   directory.
7. Update `Sources/SwiftEchada/CharacterMerger.swift` for the new `CastMember` location, behaviour
   unchanged (`EC-17`).

**Exit criteria**:
- [ ] `grep -n 'frontMatter\.cast\|withCast\|ProjectCastWriteBack' Sources/EchadaCLICore/GeneratePromptCommand.swift Sources/EchadaCLICore/GenerateVoxCommand.swift` returns nothing (comments included)
- [ ] `grep -rln 'ProjectCastWriteBack' Sources/` lists exactly two files: `ProjectCastWriteBack.swift` and the OQ-2 removal command's file
- [ ] `echada generate prompt --help` and `echada generate vox --help` both list `--cast`
- [ ] A test per command asserts a non-zero exit whose message contains `echada generate cast` when `CAST.md` is absent
- [ ] A test asserts a `.vox` path written into `CAST.md` resolves to an existing file relative to the `CAST.md` directory
- [ ] `CharacterMergerTests` passes with no assertion changes (import line may change)
- [ ] `make build` exits 0 and `make test` exits 0

---

### Sortie 8: `echada cast` orchestrator and body-preservation regression

**Entry criteria**:
- [ ] Sortie 7 exit criteria met (all three `generate` stages read/write `CAST.md`)

**Tasks**:
1. Update `Sources/EchadaCLICore/CastCommand.swift` so its bootstrap ensures a `CAST.md` alongside the
   existing `ensureProjectMarkdown(at:projectDir:)` bootstrap at `:170` (`EC-15`).
2. Cascade `--cast` from `CastCommand` to every stage it invokes at `:125`, `:142`, `:153`, alongside
   the existing `--force` cascade.
3. Assert by construction that `CastCommand` never invokes the `EC-10` removal command.
4. Add the `EC-18` body-preservation regression test: a `CAST.md` with hand-authored
   `## Major Characters` body content survives a full `echada cast` run byte-for-byte in its body
   region. This is the issue-#44/#55 class.
5. Add a companion assertion that `PROJECT.md` is SHA-256-unchanged by an `echada cast` run.
6. Update `CLIWiringTests` if the `--cast` cascade changes the command tree's option surface.

**Exit criteria**:
- [ ] `echada cast --help` lists `--cast`
- [ ] A test asserts a hand-authored `CAST.md` markdown body is byte-identical after a full `echada cast` run
- [ ] A test asserts `PROJECT.md` is SHA-256-identical after a full `echada cast` run
- [ ] `grep -n '<OQ-2 removal command symbol>' Sources/EchadaCLICore/CastCommand.swift` returns nothing
- [ ] `make build` exits 0 and `make test` exits 0

---

### Sortie 9: Migrate the existing test suite

**Entry criteria**:
- [ ] Sortie 8 exit criteria met (orchestrator rewired, body preservation proven)

**Tasks**:
1. Update the ten `EC-21` test files to construct and assert against `CAST.md` rather than
   `PROJECT.md`'s `cast:`. Verified against the tree — these are exactly the ten files in
   `Tests/SwiftEchadaTests/` that reference cast today: `GenerateCastCommandTests` (23 refs),
   `PerLanguagePromptTests` (18), `GenerateVoxWriteBackTests` (13), `VoicePromptRoundTripTests` (8),
   `CastingLanguageResolutionTests` (6), `ModelBackedGenerationTests` (5), `CastPipelineTests` (5),
   `NonEnglishPassthroughTests` (4), `GenerateVoxCommandTests` (2), `CharacterMergerTests` (2).
2. Add `CLIWiringTests` to the migration set — `EC-21` omits it, but it asserts the subcommand tree
   that Sorties 5 and 6 change.
3. Convert every test fixture that embeds a `cast:` block in a `PROJECT.md` string into the paired
   `PROJECT.md` + `CAST.md` shape.
4. Switch to targeted `import struct SwiftEchada.CastMember` / `import enum SwiftEchada.Gender` in
   every test file that sees both modules (`CLAUDE.md` rule 3).
5. Audit the ten `EC-22` coverage items against what Sorties 1–8 added, and fill any gap.
6. Write the audit into the sortie's completion notes as a table: `EC-22` item → covering test
   function name → file.

**Exit criteria**:
- [ ] `grep -rn 'frontMatter\.cast\|withCast' Tests/` returns nothing
- [ ] All eleven test files (ten from `EC-21` plus `CLIWiringTests`) compile and pass
- [ ] The completion notes contain a ten-row table mapping every `EC-22` item to a named, passing test function
- [ ] `make test` exits 0
- [ ] The only tests reported as skipped are the three pre-existing `.enabled(if:)`-gated cases in `ModelBackedGenerationTests` (`:159`, `:221`, `:262`), which require TTS weights or Foundation Models. **No newly-added test may be conditionally gated.** (The first draft demanded "zero skipped tests", which is unachievable — those three gates predate this mission.)

---

## WU-4 — Documentation & Skills

Requirements `EC-19`, `EC-20`. No code changes. **Sorties 10 and 11 are parallel-safe** — disjoint
file sets, neither builds.

### Sortie 10: Repository documentation (`EC-19`)

**Entry criteria**:
- [ ] Sortie 9 exit criteria met (full suite green against CAST.md)

**Tasks**:
1. Update `AGENTS.md`, `CLAUDE.md`, and `README.md` for the ownership split: `PROJECT.md` is
   SwiftProyecto's config, `CAST.md` is SwiftEchada's.
2. **Rewrite `CLAUDE.md` rule 4.** It currently reads "Library depends only on SwiftProyecto." That is
   false once Sortie 2 lands. New wording must name both `SwiftProyecto` and `marcprux/universal` and
   keep the real invariant: no ML/voice dependencies in the library target.
3. Update `Docs/dependencies.md` — not in `EC-19`'s list, but it is the dependency table of record and
   `universal` is a new library-target dependency.
4. Update `Docs/architecture.md` with the `CastDocument` / `CastMarkdownParser` layer and the
   `SwiftEchada → SwiftProyecto` boundary.
5. Update `Docs/api.md` with `CastMember`, `Gender`, `CastDocument`, `CastMarkdownParser`, the new
   `portrait` field, and the note that `CharacterProfile.gender` is now `SwiftEchada.Gender`.
6. Update `Docs/vox-pipeline.md` — `.vox` paths now recorded in `CAST.md`'s `voices.voxalta`.
7. Update `Docs/gotchas.md` with the transition-window `CastMember`/`Gender` ambiguity and the
   required targeted-import style.
8. Add a `CHANGELOG.md` entry under the new version heading describing the CAST.md extraction, both
   new commands, and that `PROJECT.md`'s `cast:` is now read-only legacy.

**Exit criteria**:
- [ ] All nine files (the eight in `EC-19` plus `Docs/dependencies.md`) appear in `git diff --stat`
- [ ] `grep -n 'depends only on SwiftProyecto' CLAUDE.md AGENTS.md` returns nothing
- [ ] `grep -rn 'PROJECT\.md' README.md AGENTS.md CLAUDE.md Docs/architecture.md Docs/api.md Docs/vox-pipeline.md` yields no line that instructs writing cast into `PROJECT.md` — reviewed line by line, with the reviewed line count stated in the completion notes
- [ ] `CHANGELOG.md` has a new entry naming both OQ-2 command verbs
- [ ] `git diff --name-only` in this sortie contains no `.swift` path

---

### Sortie 11: Global agent skills (`EC-20`)

**Entry criteria**:
- [ ] Sortie 9 exit criteria met (full suite green against CAST.md) — **not** gated on Sortie 10
- [ ] OQ-5 (EC-20 timing vs. the embedded signed `echada` binary) resolved

**Tasks**:
1. Update `~/.claude/skills/cast-voices/SKILL.md` — it currently instructs agents to read
   `voicePrompt`/`voiceDescription` out of `PROJECT.md`. Repoint to `CAST.md`.
2. Update `~/.claude/skills/podcast-audio-plan/SKILL.md` — it currently writes the cast list into
   `PROJECT.md`. Repoint to `CAST.md`.
3. Apply whatever version-gating OQ-5's decision requires, so the skills do not instruct agents to use
   a `CAST.md` path against an `echada` binary that predates it.
4. Grep both skill trees for any other `PROJECT.md`-cast reference (helper scripts, examples,
   reference files) and repoint those too.

**Exit criteria**:
- [ ] Both `SKILL.md` files name `CAST.md` as the cast source
- [ ] Every remaining `PROJECT.md` mention in `~/.claude/skills/cast-voices` and `~/.claude/skills/podcast-audio-plan` is enumerated in the completion notes with a one-line justification for why it is not a cast read/write
- [ ] If OQ-5 selects capability detection, both skills contain an explicit `echada --version` (or subcommand-probe) branch with a documented `PROJECT.md` fallback
- [ ] `git -C <this repo> status --porcelain` is empty — this sortie touches no file inside the repository

---

## WU-5 — Release & Pilot Rollout

Sequencing step 3's tail and step 4's pilot. `X-2` requires SwiftEchada to be a **real tagged
release** before Produciesta can build against it — there is no `sibling()` pattern in that repo and
its `Package.resolved` is gitignored.

**The §5 diamond does not block this release.** Verified: `Package.swift` pins
`SwiftProyecto .upToNextMajor(from: "4.8.1")`. This mission never raises that floor, so SwiftHablare's
`4.0.0..<5.0.0` range stays satisfiable and SwiftPM resolves. The diamond bites only at step 7, which
is out of scope. See OQ-7.

### Sortie 12: Release preparation

**Entry criteria**:
- [ ] Sortie 10 and Sortie 11 exit criteria met (docs and skills consistent)
- [ ] Working tree clean, `make test` green on the mission branch

**Tasks**:
1. Bump the package version to the target release version.
2. **Do not run `/toggle-sibling-libraries`.** Verified: `Package.swift` has no `sibling()` helper and
   no local path dependencies — it is already in the remote-only release shape. The first draft's
   task 2 was inapplicable. Instead, *assert* the release shape (task 4).
3. Run `make refresh-deps` for a clean resolve, then confirm `make verify-deps` reports the table is
   up to date. Commit any regenerated `DependencyVersions.swift`.
4. Run `make release` and confirm the built binary's `echada --version` reports the new version and a
   dependency table that includes `universal` and still shows SwiftProyecto on the `4.x` line.
5. Stop. Publication is HG-1 below.

**Exit criteria**:
- [ ] `grep -n 'sibling(' Package.swift` returns nothing and `grep -n 'path:' Package.swift` returns no local dependency
- [ ] `grep -n 'SwiftProyecto' Package.swift` shows an unchanged `4.8.1` `.upToNextMajor` floor
- [ ] `make verify-deps` prints "Dependency table is up to date."
- [ ] `make release` exits 0
- [ ] The release binary's `echada --version` prints the new version and lists `universal`
- [ ] `git status --porcelain` is empty

---

### 🚦 HG-1 — Human Gate: publish the release

**Not a sortie.** Tagging, pushing, opening the release PR, merging to `main`, and creating the GitHub
release are human actions. The supervisor must not dispatch an agent to push or merge. Sortie 13
cannot start until a human confirms:

- [ ] Mission branch merged to `development`, `development` merged to `main` per repo convention
- [ ] The version tag exists on `main` and `gh release view <tag>` exits 0
- [ ] `echada` reinstalled from the tagged release (`brew upgrade` or `make install`) and
      `echada --version` on `PATH` reports it

---

### Sortie 13: Pilot rollout on `confessions` (`PC-6`)

**Entry criteria**:
- [ ] HG-1 confirmed (tagged release exists, `echada` on `PATH` is built from it)
- [ ] OQ-6 (rollout scope) resolved
- [ ] OQ-8 (who runs the pilot against a live content repo) resolved

**Tasks**:
1. In `~/Projects/podcasts/confessions`, confirm a clean working tree and record
   `sha256 PROJECT.md` before touching anything.
2. Run `echada generate cast` to produce `CAST.md` from the existing legacy `cast:`.
3. Run the Sortie 5 verification command and confirm it exits 0.
4. Confirm every `.vox` path in `CAST.md` resolves to an existing file (`PC-5`) — expect
   `voices/NARRATOR.vox`, `voices/ESPECTRO_FAMILIAR.vox`, `voices/THE_PRACTITIONER.vox`.
5. Run `echada generate vox --dry-run` and confirm it lists the same three members as a pre-rollout
   run against the legacy `cast:`.
6. Confirm `PROJECT.md`'s SHA-256 matches the value recorded in task 1 — step 4 is generate-only.
7. Commit `CAST.md` alone as a single commit in the `confessions` repo (`PC-2`).
8. Stop. Do not run the removal command, do not push, and do not touch any other podcast repo.

**Exit criteria**:
- [ ] `~/Projects/podcasts/confessions/CAST.md` exists and contains all three characters, the `bio` on `THE PRACTITIONER`, and each member's full `voicePrompt`
- [ ] The verification command exits 0 in `confessions`
- [ ] All three `.vox` paths in `CAST.md` resolve to existing files
- [ ] `git -C ~/Projects/podcasts/confessions show --name-only --format= HEAD` lists exactly `CAST.md`
- [ ] `PROJECT.md`'s SHA-256 is unchanged from the task-1 value
- [ ] `git -C ~/Projects/podcasts/confessions status --porcelain` is empty and nothing was pushed
- [ ] No file under `~/Projects/podcasts/` outside `confessions` was modified

---

### 🚦 HG-2 — Human Gate: eyeball the pilot (`PC-6`)

`PC-6` requires a human to read the generated `CAST.md` and confirm the `PROJECT.md` diff is
cast-block-only before any further repo is touched. **This mission ends here.** The remaining 11
podcast repos, step 5 (Produciesta), step 6 (removal), and step 7 (SwiftProyecto 5.0) are follow-on
missions.

---

## Open Questions

<!-- Consumed by Pass 1 of refine (`refine-blockers`). Each entry MUST be resolved before refinement can proceed past Pass 1. -->

### OQ-1: CAST.md location — convention or declared in PROJECT.md? And may `--cast` escape the project directory?
**Affects**: Sortie 4, Sortie 7, Sortie 8
**Question**: Two coupled sub-decisions. (a) Is `CAST.md` located purely by convention (sibling of
`PROJECT.md`, overridable with `--cast`), or may `PROJECT.md` declare `castFile: CAST.md`? (b) May
`--cast` point outside the project directory, and if so, does `.vox` output follow the `CAST.md`
directory or stay with `PROJECT.md`?
**Source**: `REQUIREMENTS-cast-md-changes.md` §9 Q1 (lines 438–441); §3.3 path semantics (lines 123–126); `EC-16` (lines 215–217)
**Why blocking**: Sortie 4 cannot implement `--cast` resolution and Sortie 7 cannot mirror it without
(a). `CastVoiceGenerator` holds a single `projectDirectory` used for both screenplay discovery and
`.vox` output; (b) decides whether that field splits in two.
**Recommendation**: (a) Convention only — `--cast` defaults to `CAST.md` resolved as a sibling of
`--project` when relative; no `castFile:` key. (b) Constrain `--cast` to the project directory:
reject a resolved `--cast` whose parent differs from `--project`'s parent, with an explicit error.
**Rationale**: (a) is the requirements doc's own recommendation, and a `castFile:` key would put a
cast concern back into `PROJECT.md`, contradicting `D1`. (b) keeps §3.3's "relative to the directory
containing CAST.md" and `EC-16`'s "identical in practice — same directory" simultaneously true; the
first draft left them silently in tension.

### OQ-2: Command names for verification (`EC-9`) and removal (`EC-10`)
**Affects**: Sortie 4, Sortie 5, Sortie 6, Sortie 8, Sortie 9, Sortie 10
**Question**: What are the two command verbs? They must read as clearly separate and clearly
non-destructive vs. destructive, and must not be confused with `echada cast`, the full-pipeline
orchestrator.
**Source**: `REQUIREMENTS-cast-md-changes.md` §9 Q3 (lines 448–452)
**Why blocking**: Sorties 5 and 6 cannot name a file, register a subcommand, or write a greppable exit
criterion without the verb. Sorties 4, 8, 9, and 10 reference the names in error messages, negative
assertions, `CLIWiringTests`, and the changelog.
**Recommendation**: `echada verify cast` and `echada prune cast`, each a top-level container command
parallel to `GenerateCommand`, registered in `EchadaCLI.swift:31-33`'s subcommand array (today
`[VoiceCommand, CastCommand, GenerateCommand, TestVoiceCommand]`).
**Rationale**: The requirements doc recommends exactly this. `generate cast` / `verify cast` /
`prune cast` reads as three verbs over one noun, keeps `echada cast` unambiguously the orchestrator,
and reuses the container pattern already in `GenerateCommand.swift`.

### OQ-3: `AnyCodable` — vendor into SwiftEchada or import from SwiftProyecto?
**Affects**: Sortie 1
**Question**: `EC-5` requires `AnyCodable` in the `SwiftEchada` target. Vendor a copy or consume
SwiftProyecto's public type?
**Source**: `REQUIREMENTS-cast-md-changes.md` §9 Q4 (lines 453–456)
**Why blocking**: Sortie 1 cannot write `CastMember.extraKeys` without deciding which `AnyCodable` it
stores, and a wrong choice silently changes round-trip fidelity.
**Recommendation**: Import from SwiftProyecto. Do not vendor.
**Rationale**: `Package.swift:44-51` already makes `SwiftProyecto` the sole dependency of the
`SwiftEchada` target, and `EC-12` keeps SwiftEchada reading `PROJECT.md` indefinitely, so the
dependency cannot be dropped anyway. `AnyCodable` is public at
`SwiftProyecto/Models/AnyCodable.swift:33` — verified. Vendoring risks divergence in the exact JSON
round-trip semantics that `EC-2` and `EC-18` depend on, and `ProjectCastWriteBack`'s doc comment
records what that divergence looks like in production.

### OQ-4: `type: cast` discriminator collides with the requirements docs themselves
**Affects**: Sortie 2
**Question**: The repo-wide frontmatter policy forces `type:` onto every `.md`, so the three sibling
`REQUIREMENTS-cast-md-changes.md` files also declare `type: cast`. Narrow the discriminator to
`type: echada-cast`, or have `CastMarkdownParser` additionally require a `cast:` key?
**Source**: `REQUIREMENTS-cast-md-changes.md` §3.1 (lines 103–106) and §9 Q6 (lines 459–465)
**Why blocking**: Sortie 2's file-acceptance rule is the deliverable. A naive `type: cast` scan
currently matches this plan's own source document.
**Recommendation**: Require **both** `type: cast` and a `cast:` key in `CastMarkdownParser`, and
relabel the three requirements docs to `type: requirements`.
**Rationale**: The requirements doc recommends this, and it matches Produciesta's own convention
(`Docs/REQUIREMENTS-fcpxml-export.md` uses `type: requirements`). Note: `breakdown` deliberately left
`REQUIREMENTS-cast-md-changes.md`'s `type: cast` untouched pending this decision — relabelling is part
of resolving it, and the sibling docs in `pkg/SwiftProyecto` and `apps/Produciesta` need the same
treatment, which is a cross-repo edit this mission is otherwise forbidden from making.

### OQ-5: `EC-20` skill update timing vs. the embedded signed `echada` binary
**Affects**: Sortie 11
**Question**: `X-4` states the `echada` binary is embedded and code-signed inside `Produciesta.app`,
so an `EC-20` skill update depends on a Produciesta *release*, not just a doc edit. Do the skills get
updated now, or held until Produciesta ships (step 5, out of this mission's scope)?
**Source**: `REQUIREMENTS-cast-md-changes.md` §5 `X-4` (lines 351–352) and `EC-20` (lines 223–224)
**Why blocking**: Sortie 11 either runs or is cut. If it runs unconditionally it points `cast-voices`
at a `CAST.md` path that the signed binary inside the currently-shipped `Produciesta.app` cannot
produce, breaking every agent that invokes the skill.
**Recommendation**: Update both skills now, with runtime capability detection — probe
`echada --version` or the presence of the OQ-2 verification subcommand, and fall back to the
`PROJECT.md` path when the available binary predates the HG-1 release.
**Rationale**: The skills are global and run against Homebrew-installed `echada` as well as the
embedded copy. A hard cut breaks the Homebrew path needlessly; an unconditional edit breaks the
embedded path. Capability detection is the only branch correct for both, and it costs one shell check.

### OQ-6: Rollout scope — pilot only, or all 12 podcast repos?
**Affects**: Sortie 13
**Question**: Does this mission stop after the `confessions` pilot, or roll `CAST.md` generation out
to all 12 podcast repos carrying a `cast:` block?
**Source**: `REQUIREMENTS-cast-md-changes.md` §6 step 4 (line 380), §7 `PC-3`/`PC-4`/`PC-6` (lines 403–410)
**Why blocking**: Sortie 13's exit criteria assert that no repo outside `confessions` was modified. If
the full rollout is in scope, WU-5 needs eleven more sorties and a decision on `common-voices`
(`PC-4` — confirmed present under `~/Projects/podcasts/` and not a git repo).
**Recommendation**: Pilot only. This mission ends at HG-2. Track the remaining 11 repos as a follow-on
mission.
**Rationale**: `PC-6` forbids rolling out further until the pilot's `CAST.md` is eyeballed by a human —
a gate this mission cannot pass on its own. `PC-3` forbids cross-repo batching, so the remainder is
eleven independent commits with no shared context: a poor fit for one mission.

### OQ-7: SwiftHablare step 0 — do it now, out of band, or defer to step 7?
**Affects**: Sortie 12, and every follow-on mission that reaches step 7
**Question**: The §5 diamond (`SwiftEchada → SwiftVoxAlta → SwiftHablare → SwiftProyecto 4.x` vs.
`SwiftEchada → SwiftProyecto 5.x`) makes SwiftPM resolution fail outright at step 7. Deleting
SwiftHablare's phantom `SwiftProyecto` dependency dissolves it. Do we do that now as a separate
patch release, or leave it for whoever runs step 7?
**Source**: `REQUIREMENTS-cast-md-changes.md` §5 "Diamond dependency" (lines 282–300) and §9 Q10 (lines 484–486)
**Why blocking**: It is **not** blocking for Sortie 12 — verified: `Package.swift` keeps the
SwiftProyecto floor at `4.8.1`, so nothing this mission ships can trip the diamond, and Sortie 12's
exit criteria now assert that. It **is** blocking for planning: if the answer is "defer", the step-7
follow-on mission needs five sequenced releases across four repos instead of one, and that has to be
budgeted now rather than discovered later.
**Recommendation**: Do it now, out of band, as an independent SwiftHablare patch release — not as a
sortie in this mission.
**Rationale**: Verified phantom: `pkg/SwiftHablare/Package.swift:65-66,74` declares the dependency and
wires the product into a target, while `grep -rn SwiftProyecto Sources Tests` returns nothing. Removal
is a manifest-only, source-zero-impact patch that shrinks every downstream graph and is worth doing
regardless. Bundling it into this mission would violate the standing constraint that no sortie touches
another repo.

### OQ-8: Who runs the pilot against the live `confessions` content repo?
**Affects**: Sortie 13
**Question**: Sortie 13 executes real commands and creates a real commit in
`~/Projects/podcasts/confessions`, a live content repo outside this worktree. Is an autonomous agent
authorised to do that, or does a human run the pilot with the agent only producing the checklist?
**Source**: `REQUIREMENTS-cast-md-changes.md` §7 `PC-1` (line 399) says the rollout is performed by the
commands, not by hand; `PC-6` (lines 408–410) requires human eyeballing. `EC-7`'s rationale (lines
171–176) spells out the silent-desync failure mode if seeding goes wrong.
**Why blocking**: The sortie is either dispatched to an agent with write access to a content repo, or
rewritten as a human runbook. The exit criteria differ, and so does the blast radius: a bad seed
silently desynchronises three characters' `.vox` files from their stated `voicePrompt`, with no error
and no diff to notice.
**Recommendation**: Agent-executed, but commit-only and push-never — exactly as Sortie 13 is written
(clean tree precondition, SHA-256 assertion on `PROJECT.md`, single-file commit, no push). HG-2 is the
human review, and `git revert` is a one-liner if it is wrong.
**Rationale**: `PC-1` explicitly wants the commands to do the rollout rather than hand-editing, and
`PC-2`'s separate-commits rule exists precisely so this is revertible. The residual risk is bounded by
the no-push rule: nothing leaves the machine before HG-2.

---

## Cross-Repo Risks Carried Into This Mission

Not open questions — decided, but each sortie owner should know them.

| Risk | Impact here | Mitigation in this plan |
|---|---|---|
| **Diamond dependency** (§5) | None. Verified: `Package.swift` pins SwiftProyecto `.upToNextMajor(from: "4.8.1")` and this mission never raises it, so SwiftHablare's `4.0.0..<5.0.0` stays satisfiable | Sortie 12 exit criteria assert the floor is unchanged. OQ-7 decides the out-of-band fix. (The first draft said "the current 4.6.1 floor" — it is 4.8.1) |
| **Transition-window type ambiguity** — both modules export `CastMember` **and `Gender`** until SwiftProyecto 5.0 | Every file importing both modules is a latent compile error. `CharacterProfile.gender` silently changes module | Targeted imports in the standing constraints; Sortie 1 task 6 pins the four in-repo `Gender` sites; Sortie 9 task 4 sweeps the suite; `Docs/gotchas.md` records it in Sortie 10 |
| **`X-1` — `CastWriter` prunes** (`apps/Produciesta`) | Not this repo's code, but `EC-8`'s additive-only guarantee is the contract Produciesta must conform to | Sortie 4 proves additive-only with an idempotency test, giving Produciesta a reference behaviour to match |
| **Issue #44/#55 class** — field-by-field front matter rebuild deletes unknown keys (`introFile`) and corrupts nested ones (`episodes_index` → `NSDictionary.description` dump; 309 lines → 103) | Directly reproducible by `EC-10` if it rebuilds instead of excising | Sortie 6 task 2 reuses the already-proven `ProjectCastWriteBack.applying(cast: [], to:)`; Sorties 4, 6, and 8 assert SHA-256 identity |
| **Dependency-table drift** — `DependencyVersions.swift` is generated and CI-drift-checked | Adding `universal` changes it; an uncommitted regeneration produces a permanent CI warning | Sortie 2 task 2 and Sortie 12 task 3 |

---

## Corrections to the First Draft

Every item below was verified against the source before changing.

| # | First draft said | Verified reality | Where fixed |
|---|---|---|---|
| 1 | No mention of `Sources/EchadaCLICore/ProjectCastWriteBack.swift` | It is the shared surgical write-back used by all three `generate` stages, and its `applying(cast: [], to:)` already implements `EC-10`'s excision | WU-2 preamble, Sortie 4 task 4, Sortie 6 task 2, Sortie 7 task 3 |
| 2 | "Remove the `parser.write(frontMatter:body:to:)` call at `GenerateCastCommand.swift:171`" | No such call exists. The write is `ProjectCastWriteBack.write(cast:to:using:)` at `:172` | Sortie 4 task 4 |
| 3 | `replacingCastBlock` at `ProjectMarkdownParser.swift:346` | It is at `:352` (`renderCast` at `:280` was correct) | Sortie 2 task 5 |
| 4 | "Sortie 12 ships against the current `4.6.1` floor" | The floor is `4.8.1` | Risk table, WU-5 preamble |
| 5 | Sortie 12 task 2: run `/toggle-sibling-libraries` | `Package.swift` has no `sibling()` helper and no local path deps — already release-shaped. The task was a no-op that could only cause churn | Sortie 12 task 2 inverted into an assertion |
| 6 | Sortie 12 included tag / PR / merge / GitHub release | Publication is a human action; an agent must not push or merge | Split: Sortie 12 = prep, HG-1 = human publish gate |
| 7 | Sortie 9: "`make test` exits 0 with zero skipped tests" | Unachievable — `ModelBackedGenerationTests:159,221,262` are `.enabled(if:)`-gated on TTS weights / Foundation Models and predate this mission | Sortie 9 exit criteria now allow exactly those three and forbid new gates |
| 8 | No task for the generated dependency table | Adding `universal` changes `Generated/DependencyVersions.swift`, which `make verify-deps` drift-checks in CI | Sortie 2 task 2, Sortie 12 task 3 |
| 9 | `EC-19`'s eight docs only | `Docs/dependencies.md` and `CLAUDE.md` rule 4 ("Library depends only on SwiftProyecto") are both invalidated by Sortie 2 | Sortie 10 tasks 2–3 |
| 10 | `EC-21`'s ten test files only | `CLIWiringTests.swift` asserts the subcommand tree that Sorties 5–6 change | Sortie 5 task 6, Sortie 6 task 7, Sortie 9 task 2 |
| 11 | Sortie 5 entry criterion: "Sortie 4 exit criteria met" | `EC-9` verification depends on the parser and the legacy reader, not on the `generate cast` rewiring. Ordering is build-serialization, not data dependency | Sortie 5 entry criteria; § Parallelism |
| 12 | WU-4: "no intra-layer parallelism identified" | Sorties 10 and 11 have disjoint file sets and neither builds — genuinely parallel-safe | Work Units table, § Parallelism |
| 13 | Sortie 1 exit: `grep -c 'import SwiftEchada' pkg/SwiftProyecto/Sources -r` returns `0` | That path does not exist inside this worktree, and `grep -c -r` prints per-file counts, not `0`. The criterion could never pass | Replaced with `git status --porcelain` lists nothing outside this repo |
| 14 | Requirements §10: "`Gender` has zero references outside `CastMember.swift`" carried forward unexamined | True within SwiftProyecto only. SwiftEchada uses `Gender` at four sites, one of which is public API (`CharacterProfile.gender`) | Sortie 1 task 6, § Decision consequences, risk table |
| 15 | Seeding fidelity described generically | `confessions` has no `actor`/`gender`/`language`/`portrait`; a naive emitter would write `null`s and change the data | Sortie 4 task 3 and its exit criterion |
| 16 | Vague doc exit criteria ("contains no instruction to…") | Not machine-verifiable | Sorties 10 and 11 now require an enumerated, justified list in the completion notes |
| 17 | Fixtures unnamed | Round-trip and `EC-11` criteria referenced "a fixture" with no path | `Fixtures/confessions-shaped-CAST.md` and `Fixtures/confessions-PROJECT.md` named and pinned |
| 18 | OQ list of 6 | Two further blockers found: SwiftHablare step-0 timing, and authorisation to write to a live content repo | OQ-7, OQ-8 |

---

## Requirement Coverage Matrix

Every in-scope requirement maps to at least one sortie. **No requirement is uncovered.**

| Req | Sortie(s) | Req | Sortie(s) |
|---|---|---|---|
| EC-1 | 1 | EC-12 | 4, 7 |
| EC-2 | 1, 2 | EC-13 | 4, 7, 8 |
| EC-3 | 2 | EC-14 | 7 |
| EC-4 | 2 | EC-15 | 8 |
| EC-5 | 1 | EC-16 | 7 |
| EC-6 | 3 | EC-17 | 7 |
| EC-7 | 4 | EC-18 | 2, 8 |
| EC-8 | 4 | EC-19 | 10 |
| EC-9 | 5 | EC-20 | 11 |
| EC-10 | 6 | EC-21 | 9 |
| EC-11 | 6 | EC-22 | 9 |
| PC-1 | 13 | PC-5 | 13 |
| PC-2 | 13 | PC-6 | 13, HG-2 |

`PC-3` and `PC-4` are out of scope (single-repo pilot). `DEF-1` … `DEF-4` are deferred by §8.

---

## Summary

| Metric | Value |
|--------|-------|
| Work units | 5 |
| Total sorties | 13 |
| Human gates | 2 (HG-1 publish, HG-2 pilot review) |
| Requirements in scope | 26 (`EC-1`…`EC-22`, `PC-1`, `PC-2`, `PC-5`, `PC-6`) |
| Requirements with no covering sortie | 0 |
| Atomic tasks | 84 |
| Open questions | 8 (6 carried forward, 2 new) |
| Dependency structure | layers 0 → 4; one parallel-safe pair (Sortie 10 ∥ Sortie 11); all other ordering is a genuine data or build dependency |
