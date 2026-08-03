---
type: requirements
title: CAST.md Extraction — Controlling Requirements
status: draft
created: 2026-07-26
updated: 2026-08-01
controlling_repo: SwiftEchada
target_version: 1.0.0
---

# CAST.md Extraction — Controlling Requirements

**This is the controlling document.** Sibling `REQUIREMENTS-cast-md-changes.md` files exist in
SwiftProyecto and Produciesta. They cover their own repo's work and defer to this document for
schema, ownership boundary, and sequencing. If they disagree with this file, this file wins.

| Repo | Path | Doc |
|---|---|---|
| **SwiftEchada** (controlling) | `package-collection/pkg/SwiftEchada` | this file |
| **SwiftReparto** (new) | `package-collection/pkg/SwiftReparto` | `REQUIREMENTS.md` — owns the schema |
| SwiftProyecto | `package-collection/pkg/SwiftProyecto` | `REQUIREMENTS-cast-md-changes.md` |
| SwiftSemblanzas | `package-collection/pkg/SwiftSemblanzas` | `REQUIREMENTS.md` §4.3 — second consumer |
| Produciesta | `~/Projects/apps/Produciesta` | `REQUIREMENTS-cast-md-changes.md` |
| podcasts/* (12 content repos) | `~/Projects/podcasts/*` | no doc — content rollout only, see §7 |

---

## 0. Revision note — 2026-08-01: cast becomes its own package

**The first draft put the cast model in SwiftEchada. It goes into a new leaf package,
`SwiftReparto`.** Two findings forced the change.

**1. SwiftProyecto could never delegate to SwiftEchada — only delete.** SwiftEchada's package
manifest depends on SwiftProyecto (`Package.swift:26-27`), because `EchadaCLICore` reads
`PROJECT.md` for `title`, `episodesDir`, `filePattern`, and `tts.model` and will continue to
forever (`EC-12`). A `SwiftProyecto → SwiftEchada` edge is therefore a **package-level cycle**.
SwiftPM evaluates cycles at package granularity, not target granularity, and fails at manifest load
with `cyclic dependency declaration found` — there is no target-level escape hatch. The first draft
handled this by forbidding the edge (`D6`) and accepting that SwiftProyecto could only delete its
cast surface, never hand it off.

**2. A second consumer exists.** `pkg/SwiftSemblanzas` — pre-alpha, docs-only, real repo — generates
character-consistent storyboard panels by training a per-character FLUX.2 LoRA. It needs the same
roster SwiftEchada does, to hang trained adapters off. With cast in SwiftEchada it would have to
link MLX, SwiftVoxAlta, and the whole TTS stack to read a character's name. With cast in
SwiftSemblanzas, SwiftEchada would have to link FLUX.2 to do the same.

So the cast model goes where neither consumer's weight can reach it:

```
                        SwiftReparto  ← CAST.md: schema, parse, serialize. A leaf.
                       ↗             ↖
          SwiftEchada                  SwiftSemblanzas
        voice identity                 visual identity
          → .vox files                   → LoRA adapters

          SwiftProyecto  ← PROJECT.md only. No cast, no dependency on Reparto.
```

**What survives from the first draft:** everything about non-destructive rollout (`EC-6`…`EC-11`),
command rewiring (`EC-12`…`EC-18`), the sequencing philosophy, and the podcast pilot. **What
changed:** `D1` and `D6`; `EC-1`…`EC-5` move out of this repo entirely; `§6` gains a step; the
diamond analysis in `§5` is superseded.

---

## 1. Motivation

Cast data currently lives in `PROJECT.md`'s YAML front matter as `ProjectFrontMatter.cast`, a
**SwiftProyecto** model. SwiftProyecto is a project-configuration library; cast is not project
configuration. Meanwhile the packages that actually *do* something with cast are downstream
consumers parsing and mutating a schema none of them owns.

The goal is a clean ownership boundary, enforced structurally:

- **`PROJECT.md` is SwiftProyecto's config file.** Project identity, episode discovery, variants,
  TTS config.
- **`CAST.md` is SwiftReparto's config file.** Cast list, voice prompts, voice files, appearance
  pointers, character summaries.
- **SwiftEchada is a consumer.** It creates voice assets and records where they went.

Any utility needing cast information uses SwiftReparto. Any utility needing project information uses
SwiftProyecto. Neither reaches into the other's file, and no consumer serializes either one.

---

## 2. Locked decisions

Decided; not open for re-litigation in the sibling docs.

| # | Decision |
|---|---|
| D1 | **Ownership split.** **SwiftReparto** owns `CAST.md` end to end — schema, parser, serializer. SwiftProyecto owns `PROJECT.md` and loses all cast modelling. SwiftEchada owns *voice assets* and is a consumer of both |
| D2 | **Hard cut, staged.** `cast:` is ultimately removed from `ProjectFrontMatter` entirely — no dual-read, no permanent fallback. But the rollout is **two-phase and non-destructive**: CAST.md is generated alongside an untouched PROJECT.md, verified, and only then is `cast:` removed. See §4.2 and §6 |
| D3 | **Format.** YAML front matter with the same `CastMember` shape as today, plus a free markdown body. No new serialization format |
| D4 | **File references.** `.vox` paths stay in `voices.voxalta` (relocated as-is). New optional `appearance:` block reserved for SwiftSemblanzas — see SwiftReparto `RQ-5` |
| D5 | **Body content.** Markdown body holds character summaries split into major/minor sections. Generation of that body is **deferred** (§8) — the format is reserved now, filled later |
| D6 | **SwiftReparto is a leaf.** It declares no dependency on any `intrusive-memory` package, ever. This replaces the first draft's directional rule ("SwiftEchada → SwiftProyecto, never the reverse") with a structural one: cycles become impossible by construction rather than forbidden by discipline. See SwiftReparto `RQ-INV-1` |
| D7 | **No destructive migration.** There is no one-shot "move the data" command. Generation and removal are separate, separately-triggered operations with a human verification gate between them |
| D8 | **One writer.** Only SwiftReparto serializes `CAST.md`. Consumers mutate a `CastDocument` and hand it back. No consumer builds YAML or splices text. See SwiftReparto `RQ-INV-2` |
| D9 | **`CAST.md` is canonical for character identity.** SwiftSemblanzas' SwiftData catalog is a derived index keyed by character slug, rebuildable from the markdown — never the source of truth for who exists |

---

## 3. CAST.md schema

**The schema is owned by SwiftReparto and specified in full in
`pkg/SwiftReparto/REQUIREMENTS.md` §3.** It is not restated here; that file wins on any detail.

Summary for readers of this document:

- Lives beside `PROJECT.md`, default filename `CAST.md`.
- Front matter carries `type: cast` and a `cast:` array. **Both** are required for a document to be
  accepted (`RQ-1`) — a `type:`-only check would match every markdown file in the repo, since the
  house frontmatter policy forces `type:` onto all of them.
- `CastMember` fields: `character` (required), `actor`, `gender`, `language`, `voicePrompt` (legacy
  alias `voiceDescription` still decodes), `voices` (scalar and array forms both decode),
  `appearance`, and arbitrary unknown keys preserved via `extraKeys`.
- Paths are relative to the directory containing `CAST.md`.
- The markdown body is opaque and re-emitted byte-for-byte.

**The `bio:` case is the one to remember.** `~/Projects/podcasts/confessions/PROJECT.md` carries a
per-member `bio:` that nothing in the ecosystem declares, alongside the scalar `voices:` form. Both
must survive every write by every consumer. It is the pinned fixture for exactly that reason.

---

## 4. SwiftEchada requirements

Prefix `EC-`. Sibling docs reference these IDs.

### 4.1 Model & parsing — **moved to SwiftReparto**

`EC-1` … `EC-5` are **no longer SwiftEchada's work.** They are superseded by SwiftReparto's
`RQ-1` … `RQ-18`. The IDs are retained as redirects so references from the sibling docs still
resolve.

| Was | Now |
|---|---|
| **EC-1** — define `CastMember`/`Gender` in SwiftEchada | → SwiftReparto `RQ-2`, `RQ-3`. Defined in `SwiftReparto` |
| **EC-2** — `extraKeys` lossless round-trip | → SwiftReparto `RQ-4` |
| **EC-3** — `CastDocument` | → SwiftReparto `RQ-9` |
| **EC-4** — `CastMarkdownParser`, `universal` dependency | → SwiftReparto `RQ-10`, `RQ-16` |
| **EC-5** — `AnyCodable` availability | → SwiftReparto `RQ-13`. **Vendored, not imported** — the leaf invariant forbids depending on SwiftProyecto. Reparto's copy is canonical; collapsing the twins is a follow-on |

**EC-1a — SwiftEchada's library target sheds SwiftProyecto.** The `SwiftEchada` library target
imports SwiftProyecto at exactly two sites — `Sources/SwiftEchada/CharacterProfile.swift:2` and
`Sources/SwiftEchada/CharacterMerger.swift:1` — for exactly two symbols, `Gender` and `CastMember`.
Both move to SwiftReparto. After the move the light library depends on **SwiftReparto alone**.
`EchadaCLICore` keeps its SwiftProyecto dependency for project-level fields.

**EC-1b — `CharacterProfile.gender` changes module twice over.** It is public API of the light
`SwiftEchada` library that `ProduciestaCore` already links. Keep the spelling `Gender` unqualified
at every in-repo use site so the module change is source-compatible for downstream consumers.

**EC-1c — the merge moves too.** `CharacterMerger`'s additive-merge behaviour is the reference
semantics for `EC-8`, and SwiftSemblanzas will need the same guarantee. It belongs in SwiftReparto
as `RQ-14`. What stays in SwiftEchada is the *screenplay-discovery* half — turning `[CharacterInfo]`
into candidate members — which is voice-pipeline work and depends on `CastExtractor`.

### 4.2 Non-destructive rollout

The two operations below are **separate commands** and must never be fused. Generation writes only
`CAST.md`; removal touches only `PROJECT.md`. A human verification gate sits between them.

- **EC-6** — A **legacy read path** reads `cast:` out of a `PROJECT.md` front matter *as raw YAML*,
  without depending on `ProjectFrontMatter.cast` (which is being deleted). It powers EC-7's seeding
  and EC-9's verification, and is removed once SwiftProyecto 5.0 ships (§6, step 7). It decodes into
  SwiftReparto's `CastMember`.

- **EC-7 — Generate CAST.md, seeded, never destructive.** `echada generate cast` writes `CAST.md`.
  When `CAST.md` is absent and `PROJECT.md` carries a legacy `cast:`, that existing cast is
  **seeded into CAST.md verbatim** — every field, including `voicePrompt`, `bio` and other
  `extraKeys`, `language`, and `voices.voxalta` paths — and then newly-discovered characters are
  merged in on top using the additive merge (`RQ-14`). **`PROJECT.md` is not modified.**

  > **Why seeding, not fresh generation.** Regenerating cast from screenplays alone would discard
  > every hand-tuned `voicePrompt` and `bio`. Worse, existing `.vox` files were generated *from*
  > those prompts — replacing the prompts silently desynchronizes each character's recorded voice
  > from its stated description, with no error and no diff to notice. Seeding is what makes
  > "generate CAST.md in their directories" safe to run against live podcast projects.

- **EC-8** — EC-7 is idempotent and non-clobbering. If `CAST.md` already exists it is merged into
  additively, never overwritten. `--force` re-syncs to discovered characters (matching today's
  `generate cast --force` semantics). `--dry-run` prints the resulting cast without writing.

- **EC-9 — Verification.** `echada verify cast` compares a project's `CAST.md` against the legacy
  `cast:` still present in its `PROJECT.md` and reports any divergence: characters present in one
  and not the other, differing field values, and `.vox` paths that do not resolve to an existing
  file. Exits non-zero on divergence so it can gate step 6 in CI or a loop. This is the human gate —
  it reports, it does not fix.

- **EC-10 — Removal, separately triggered.** `echada prune cast` strips the `cast:` block from
  `PROJECT.md`, preserving all other front matter and the body byte-for-byte where possible.
  `appSections` (`episodes_index`, `tts`, …) must survive. Requirements:
  - Refuses to run unless a `CAST.md` exists **and** EC-9 verification passes.
  - Supports `--dry-run`; prints the exact diff it would apply.
  - Is idempotent: a `PROJECT.md` with no `cast:` is a no-op with a clear message.
  - Never invoked implicitly by any other command.

- **EC-11 — Losslessness test.** Round-trip against a real podcast `PROJECT.md`: seed to `CAST.md`,
  assert every cast field including `bio`/`extraKeys` is present, run EC-9 clean, run EC-10, then
  assert the residual `PROJECT.md` differs from the original **only** by removal of the `cast:`
  block.

### 4.3 Command rewiring

- **EC-12** — `GenerateCastCommand`, `GeneratePromptCommand`, and `GenerateVoxCommand` read and
  write `CAST.md` instead of `PROJECT.md`'s `cast:`. They continue to read `PROJECT.md` for
  project-level data (`title`, `episodesDir`, `filePattern`, `tts.model`) via SwiftProyecto.
- **EC-13** — All three gain a `--cast` option (default `CAST.md`). **Filename override only** —
  `CAST.md` always lives in the project directory. A `--cast` value containing a path separator, or
  resolving outside `--project`'s directory, is rejected with an explicit error. This keeps
  SwiftReparto `RQ-6` ("relative to the directory containing CAST.md") and `EC-16` ("same directory
  in practice") simultaneously true, and means `CastVoiceGenerator.projectDirectory` never has to
  split in two.
- **EC-14** — When `CAST.md` is absent, `generate cast` creates it (EC-7). `generate prompt` and
  `generate vox` fail with an actionable error naming `echada generate cast`.
- **EC-15** — `CastCommand` (the `echada cast` orchestrator) ensures `CAST.md` alongside its
  existing `PROJECT.md` bootstrap, and cascades `--cast` to every stage. It must **not** invoke
  EC-10 removal.
- **EC-16** — `CastVoiceGenerator` continues to write `.vox` files to `voices/` and record paths in
  `voices.voxalta`. Paths become CAST.md-relative (identical in practice — same directory).
- **EC-17** — The screenplay-discovery half of `CharacterMerger` stays here and is updated for
  `CastMember`'s new module; the additive-merge half moves to SwiftReparto (`EC-1c`, `RQ-14`).
- **EC-18** — Body preservation: every write-back goes through SwiftReparto's writer (`D8`), which
  preserves the markdown body verbatim. Regression test required on the SwiftEchada side
  independently — a green round-trip test in SwiftReparto proves the *parser* is lossless, not that
  this repo's call sequence is. This is the same class of bug as issue #44, where a field-by-field
  front matter rebuild silently destroyed `appSections`.

### 4.4 Documentation

- **EC-19** — Update `AGENTS.md`, `CLAUDE.md`, `README.md`, `Docs/architecture.md`,
  `Docs/api.md`, `Docs/vox-pipeline.md`, `Docs/gotchas.md`, `Docs/dependencies.md`, and
  `CHANGELOG.md`.

  `CLAUDE.md` rule 4 currently reads *"Library depends only on SwiftProyecto."* After `EC-1a` it
  becomes *"Library depends only on SwiftReparto."* — a smaller and better-defended claim, since
  SwiftReparto is a leaf.

- **EC-20** — Update the `cast-voices` and `podcast-audio-plan` skills in `~/.claude/skills/`,
  which instruct agents to read/write cast in `PROJECT.md`. Use runtime capability detection so the
  skills work against both a Homebrew `echada` and the older signed binary embedded in a shipped
  `Produciesta.app` (see Produciesta `X-4`) — probe for the `verify cast` subcommand and fall back
  to the `PROJECT.md` path when absent.

### 4.5 Tests

- **EC-21** — Update the affected test files: `CastPipelineTests`, `GenerateCastCommandTests`,
  `GenerateVoxCommandTests`, `GenerateVoxWriteBackTests`, `VoicePromptRoundTripTests`,
  `PerLanguagePromptTests`, `ModelBackedGenerationTests`, `CastingLanguageResolutionTests`,
  `NonEnglishPassthroughTests`, `CharacterMergerTests`, `CLIWiringTests`.
- **EC-22** — New coverage: **seeding fidelity (EC-7)**; EC-7 idempotency; EC-9 divergence
  detection; EC-10 idempotency and PROJECT.md preservation; missing-CAST.md error paths;
  `--cast` rejection of out-of-directory paths (EC-13). Parser-level round-trip, `extraKeys`, body
  preservation, and legacy-form decoding are **SwiftReparto's** tests, not duplicated here — except
  `EC-18`'s call-sequence regression, which is genuinely this repo's.

---

## 5. Cross-repo scope summary

Detail lives in each repo's own doc. This is the boundary contract.

### SwiftReparto (new, 1.0.0)

Full detail in `pkg/SwiftReparto/REQUIREMENTS.md` (`RQ-1` … `RQ-18`). Greenfield: the repo
`intrusive-memory/SwiftReparto` **does not exist yet** and must be created, then added to
`collection.json`.

Receives, from SwiftProyecto: `CastMember`, `Gender`, `AnyCodable` (vendored), and the
`renderCast` / `replacingCastBlock` emit logic from `ProjectMarkdownParser`. Receives, from
SwiftEchada: the additive-merge half of `CharacterMerger`.

### SwiftProyecto (breaking, 5.0)

Full detail in `pkg/SwiftProyecto/REQUIREMENTS-cast-md-changes.md` (`PR-0` … `PR-31`). Verified
2026-07-26 against source.

| Deletion | Validation |
|---|---|
| `ProjectFrontMatter.cast`, `withCast(_:)`, `mergeCast`, `mergingCast(_:forProvider:)` | Moves to SwiftReparto. The symbol is `mergingCast(_:forProvider:)` (`:645`), not `mergingCastVoices`. This is the API Produciesta actually calls |
| `Models/CastMember.swift` (`CastMember`, `Gender`) | `Gender` has **zero** references outside this file *within SwiftProyecto* — but four inside SwiftEchada, one of them public API (`EC-1b`) |
| `proyecto roles` (`Sources/proyecto/RolesCommand.swift`) | Duplicate of `echada generate cast`. **The cycle argument no longer applies** — with cast in a leaf package, `proyecto roles` *could* survive by depending on SwiftReparto. It is deleted by choice (`D1`: Proyecto exits the cast business), not by constraint. See §9 Q5, Q8 |
| `ProjectService.discoverCastList` / `mergeCastLists` | Public API returning `[CastMember]`. Orphans the private `extractCharacters(from:)` (`:648`) — a **second, independent** character parser that does *not* use `CastExtractor` |
| `ProjectDiscovery.readCast(from:providerID:)` | Public API returning `[CastMember]` |
| `SeasonDefinition.cast`, `VariantResolver.resolveCast` | **No podcast project uses `seasons:` or `variants:`** — verified across all 16 dirs. `resolveCast` is `private static` (`:199`); `resolve(...)` returns `ProjectFrontMatter` before and after |
| `ProjectMarkdownParser.renderCast` (`:280`) / `replacingCastBlock` (`:352`) | Ports to SwiftReparto. **`replacingCastBlock` is needed twice** — for CAST.md write-back *and* for EC-10's `cast:` excision, where "delete exactly this line span" is the entire requirement |
| `proyecto validate --verbose` cast count (`ProyectoCLI.swift:192-194`) | An unlisted compile-error site |

**Struck — these describe work that does not exist:** ~~cast display in `ProjectBrowser`~~ (the
target declares `dependencies: []` and does not link SwiftProyecto at all); ~~cast write-out in
`ProjectGeneratorService`~~ (no `CastMemberData` → `CastMember` conversion exists anywhere in
`Sources/`; `GeneratedProjectMetadata.cast` is populated by all three LLM backends and read by
nothing — see §9 Q9).

**Retained (confirmed):** `CastExtractor` — returns `[String]`, no `CastMember` coupling, live
consumer at `ProjectService.swift:1182`. `LLMBackendProtocol.CastMemberData` — generation-time DTO.

**On deprecation shims.** The first draft argued no shim was *possible*, because a shim for
`ProjectFrontMatter.cast` would need `CastMember`, which would live in SwiftEchada and could not be
imported. **That argument is void** — SwiftReparto is a leaf, so SwiftProyecto could import it and
write a perfectly good deprecated shim. The decision not to is now a **choice**: `D1` puts
SwiftProyecto out of the cast business entirely, and a shim would keep a cast concern alive in a
file that no longer has one. The staged rollout in §6 is the migration.

### ⛔ The diamond — superseded, but not gone

The first draft flagged a hard release blocker:

```
SwiftEchada → SwiftVoxAlta 0.14.1 → SwiftHablare 6.2.0 → SwiftProyecto 4.0.0..<5.0.0
SwiftEchada ────────────────────────────────────────────→ SwiftProyecto 5.0.0..<6.0.0
```

**SwiftReparto does not participate** — it depends on no `intrusive-memory` package, so introducing
it adds no edges to this graph and cannot make resolution worse.

The diamond still bites at **step 7** when SwiftEchada raises its SwiftProyecto floor to 5.0.0.
The fix is unchanged and independently worth doing: **SwiftHablare's SwiftProyecto dependency is a
phantom.** `Package.swift:65-66,74` declares it and wires the product into a target, while
`grep -rn SwiftProyecto SwiftHablare/{Sources,Tests}` returns nothing. Deleting it dissolves the
diamond permanently, is a non-breaking patch release, and shrinks every downstream graph. Verified
still present 2026-08-01. It is step 0 in §6.

Two further SwiftProyecto consumers: `apps/Proyecto` (macOS GUI, Xcode remote package ref,
`minimumVersion = 4.6.2`, no cast usage) and SwiftHablare above.

### SwiftSemblanzas (second consumer, pre-alpha)

`pkg/SwiftSemblanzas/REQUIREMENTS.md` §4.3 (added 2026-08-01). Pre-alpha, docs only, no `Sources/`.
Consumes SwiftReparto for the roster; writes `appearance.lora` and `appearance.triggerWord` back
through SwiftReparto's writer. Its SwiftData catalog is a derived index (`D9`).

Its §4.2 composition type, previously named `Reparto`, was renamed **`Convocatoria`** to free the
package name.

**This package is not scheduled by this effort** and nothing here blocks on it. It is documented
because it is the reason the split is shaped this way, and because `RQ-Q2` — whether one LoRA per
character is enough or `Appearance` needs `[LoRAAsset]` — should be answered by its author before
SwiftReparto tags 1.0.0. Adding a field later is routine; changing its shape is not.

### Produciesta (consumer)

Full detail in `~/Projects/apps/Produciesta/REQUIREMENTS-cast-md-changes.md` (`PD-1` … `PD-40`),
revised 2026-08-01 for the split.

**Scope is 6 source files**, not 2: `ProduciestaCLICore/CastSupport.swift` (the critical one — every
cast read funnels through `:168-179`, and it owns both PROJECT.md path-construction sites),
`ProduciestaCore/ProjectMd/ProjectMdSyncService.swift` (two public functions existing purely to push
cast into `ProjectFrontMatter`), `ProjectMd/CastResolver.swift`, `ProduciestaCLICore/CastCommand.swift`,
plus `ProjectMd/ProjectMdCast.swift` and `ProjectMd/CastWriter.swift`. Plus 8 test files, 6
fixtures, 2 package manifests, and the Xcode project.

**The split simplifies this repo.** Reading a cast list now needs only the light SwiftReparto
library — not SwiftEchada, and certainly not `EchadaCLICore`. But it also inverts `PD-1`: the first
draft leaned on an already-declared-but-dormant SwiftEchada edge, and **SwiftReparto is a genuinely
new declaration** in both manifests.

Standing corrections from that repo: the `EchadaCLICore` link on the `echada` Xcode tool target is
deliberate and must stay (it builds the signed embedded binary). Sandbox risk is **LOW** — the app's
grant is directory-scoped (bookmark on the folder, `canChooseDirectories = true`), so a sibling
`CAST.md` is already covered for read and write; no entitlement changes needed.

**Blocking issues raised by that repo:**

- **X-1 — `CastWriter` prunes; `EC-8` says writes are additive.** `CastWriter.swift:91-98` deletes
  every cast entry absent from the *current screenplay's* roster. `CAST.md` is project-wide but
  `produciesta cast/export` runs per-episode — exporting episode 01 of a 12-episode podcast would
  delete every other character, taking their hand-authored `bio` and `voicePrompt` with them and
  orphaning the `.vox` files those prompts generated. **`RQ-14`'s additive-only guarantee wins;
  `CastWriter` changes behaviour.** See §9 Q7.
- **X-2 — No `sibling()` pattern, and `Package.resolved` is gitignored.** There is no supported way
  to build Produciesta against an unreleased local dependency. Sharper now than before:
  SwiftReparto must be a **real tagged 1.0.0** before Produciesta work starts — there is no
  existing floor to quietly resolve against.
- **X-3 — Two manifests pin independently.** A one-sided bump makes `make build` and
  `make install-gui` resolve different versions.
- **X-4 — The `echada` binary is embedded and code-signed inside `Produciesta.app`.** EC-20's skill
  update therefore depends on a Produciesta *release*, not just a doc edit — hence the capability
  detection.
- **X-5 — `Docs/PROJECT_MD.md`** is a written contract mostly describing a file Produciesta no
  longer owns, including a normative §4 rule 4 this change must retire.

**Transition-window type ambiguity** stands, with the colliding module now `SwiftReparto`: both it
and SwiftProyecto export `CastMember` and `Gender` until 5.0 lands. Use targeted imports
(`import struct SwiftReparto.CastMember`), the house style in SwiftEchada's `CLAUDE.md` rule 3.

`apps/produciesta-old/` is legacy and out of scope.

---

## 6. Sequencing

Ordered to avoid a flag day. Each step ships independently; nothing downstream breaks until step 7.

**Step 1 is new** — SwiftReparto must exist and be tagged before anything can consume it, and X-2
means a local checkout will not do.

**Step 6 before step 7** is load-bearing. The first draft had the podcast `cast:` removal before the
Produciesta repoint, which is a silent-data-loss flag day: once `cast:` is stripped, a shipped
Produciesta gets `frontMatter.cast == nil` → empty `ProjectMdCast` → `CastResolver` returns an empty
map → **every character unassigned, with no throw and no warning.**

| Step | Repo | Work | Gate |
|---|---|---|---|
| **0** | SwiftHablare | Delete the **phantom** SwiftProyecto dependency (zero source references). Patch release. Dissolves the diamond. Independently worth doing | `make test` green; downstream graphs resolve |
| **1** | **SwiftReparto** | Create the repo. `RQ-1` … `RQ-18`. **Tag and ship 1.0.0** — a real release, not a local checkout (X-2). Add to `collection.json` | `make test` green; round-trip SHA-256 identity on the `confessions` fixture; zero `intrusive-memory` deps in `Package.swift` |
| **2** | SwiftEchada | `EC-1a` … `EC-1c`. Depend on SwiftReparto; drop SwiftProyecto from the light library target; move the additive merge out. No behaviour change yet — SwiftProyecto still owns `cast:` | `make test` green |
| **3** | SwiftEchada | `EC-6` … `EC-11`. Seeded generation, verification, and the separate removal command | EC-11 round-trip test green against a copy of a real podcast `PROJECT.md` |
| **4** | SwiftEchada | `EC-12` … `EC-22`. Rewire the commands, docs, tests. **Tag and ship 1.0.0** | `make test` green; manual `echada cast` run against a scratch project |
| **5** | podcasts/* | **Generate only.** Run EC-7 across the 12 projects with `cast:`. `CAST.md` appears; `PROJECT.md` untouched. Commit per repo | EC-9 clean in each; `echada generate vox --dry-run` lists the same members as before |
| **6** | Produciesta | Declare SwiftReparto in both manifests; repoint the 6 source files; fix `CastWriter` pruning (X-1); bump together (X-3). **Ship** | App builds; audio generation works end to end against a step-5 project (both `CAST.md` and legacy `cast:` present) |
| **7** | podcasts/* | **Remove only, after verification.** Run EC-10 per repo. Separate commit per repo | EC-9 clean; residual `PROJECT.md` diff is cast-block-only |
| **8** | SwiftProyecto | Delete everything in §5. **Ship 5.0.** Bump echada + Produciesta + `apps/Proyecto`. Remove EC-6's legacy read path | `make test` green in all repos |

Steps 0–5 are strictly additive from the outside — SwiftProyecto and Produciesta keep working
untouched throughout, and step 5 leaves every `PROJECT.md` byte-identical. Step 6 must land before
step 7. Step 7 is reversible per repo via git. Step 8 is the only breaking release and can be
deferred indefinitely: after step 7, `cast:` in `PROJECT.md` is dead weight, not a blocker.

**Step 6 requires a live dual state.** At that point every migrated project has both a `CAST.md`
*and* a `PROJECT.md` still containing `cast:`. Produciesta must read `CAST.md` and ignore the legacy
block. EC-9 having passed is what guarantees they agree.

---

## 7. Podcast content repos

12 of the 16 podcast repos under `~/Projects/podcasts/` have a `cast:` block. They need **content
rollout only** — no code, no requirements doc. Each is an independent git repo.

- **PC-1** — Rollout is performed by the EC-7 and EC-10 commands, not by hand.
- **PC-2** — Generation (step 5) and removal (step 7) are **separate commits** in each repo, so
  either can be reverted independently.
- **PC-3** — No cross-repo batching. One repo, one commit, per phase.
- **PC-4** — `~/Projects/podcasts/common-voices` is not a git repo — handle or skip explicitly.
- **PC-5** — Per-repo gate before step 6: EC-9 verification clean, and every `.vox` path in
  `CAST.md` resolves to an existing file.
- **PC-6** — Pilot on `confessions` first — richest cast (`bio`, multi-line `voicePrompt`, scalar
  `voices` form, 309-line `PROJECT.md` with a large `episodes_index`). Do not roll out further
  until its `CAST.md` is eyeballed and its `PROJECT.md` diff is confirmed cast-block-only.

---

## 8. Deferred — explicitly out of scope

Real work, tracked separately. **Not** part of the CAST.md extraction.

- **DEF-1 — Major/minor character summaries.** The reserved body structure has no generator. Needs
  (a) a major/minor classifier — dialogue line count from `DialogueExtractor` is the natural signal,
  plus a threshold — and (b) a summary generator, i.e. a fourth Foundation Model stage comparable in
  size to `GeneratePromptCommand`. Land after step 4. **Belongs in SwiftEchada, not SwiftReparto** —
  `RQ-INV-3` keeps inference out of the parser.
- **DEF-2 — Generic cast panel.** Extracting the cast panel from
  `apps/produciesta-old/Produciesta/CastingView.swift` into a reusable UI component. **The
  architectural objection is now gone** — the first draft noted it could not live in SwiftProyecto's
  `ProjectBrowser` without recreating the cycle. With cast in a leaf package there is no cycle, so a
  `RepartoUI` product (or a `ProjectBrowser` panel consuming SwiftReparto) is viable. Needs its own
  spec.
- **DEF-3 — Portrait generation.** `appearance.portrait` is a manually-populated field. Generation
  is SwiftSemblanzas' business, not this effort's.
- **DEF-4 — Reference audio / dialogue extract persistence.** Considered and rejected for this
  round; `ReferenceAudioGenerator` output and `DialogueExtractor` results stay transient.
- **DEF-5 — `AnyCodable` reunification.** SwiftReparto vendors its own copy (`RQ-13`). Collapsing
  the twins means SwiftProyecto consuming it from SwiftReparto — legal and acyclic, but a follow-on.
  See `RQ-Q1`.

---

## 9. Open questions

### Resolved 2026-08-01

| # | Question | Resolution |
|---|---|---|
| **Q1** | CAST.md location — convention, or declared in `PROJECT.md`? | **Convention only.** No `castFile:` key. `CAST.md` always sits in the project directory; `--cast` is a filename override and rejects anything with a path separator or outside `--project`'s directory (`EC-13`) |
| **Q3** | Command names for EC-9 and EC-10 | **`echada verify cast`** and **`echada prune cast`**, top-level containers parallel to `GenerateCommand`, registered in `EchadaCLI.swift:31-33` |
| **Q4** | `AnyCodable` — vendor or import? | **Vendor into SwiftReparto**, forced by `D6`. Reparto's copy is canonical; SwiftProyecto may consume it back later (`DEF-5`) |
| **Q6** | `type: cast` collides with the requirements docs themselves | **Require both `type: cast` and a `cast:` key** in the parser (`RQ-1`); the requirements docs are relabelled `type: requirements` — done in all three repos |
| **Q11** | Where does the cast model live? | **SwiftReparto**, a new leaf package. See §0 |
| **Q12** | Does SwiftProyecto depend on SwiftReparto? | **No.** It exits the cast business entirely — no dependency, no retained cast surface (`D1`) |
| **Q13** | `CAST.md` vs. SwiftSemblanzas' SwiftData catalog — which is canonical? | **`CAST.md`.** The catalog is a derived index keyed by character slug (`D9`) |

### Still open

- **Q2 — Legacy `cast:` after step 8.** A stale `cast:` swept into `appSections` is re-emitted
  **last, alphabetically sorted, through the generic JSON→YAML path** — so it *moves position and
  reformats* (member key order changes, the scalar `voices` form is rewritten). Not a silent
  passthrough: a visible, confusing diff. `ProjectValidator` has zero cast code today, so a warning
  is **new code**. Warn, strip, or ignore? *Recommendation: `proyecto validate` warns; nothing
  strips automatically.*
- **Q5 — Is `proyecto roles` truly unused?** No callers found anywhere under `~/Projects`, but shell
  history and CI outside this collection were not searched. Confirm before deleting. Note the
  calculus changed: it *could* now survive on a SwiftReparto dependency, so this is a product
  decision rather than a forced deletion.
- **Q7 — `CastWriter` pruning vs. `RQ-14` (X-1).** Confirm the additive-only guarantee wins and
  Produciesta's `Docs/PROJECT_MD.md` §4 rule 4 is retired. If per-project pruning is still wanted,
  `echada generate cast --force` already does exactly this, correctly scoped. *Recommendation:
  additive-only wins; pruning stays with `--force` in echada.*
- **Q8 — Salvage from `proyecto roles` before deleting it.** It contains `discoverScreenplays(in:)`
  and `expandGlob(_:)` — ~35 lines, and the collection's only `glob(3)` usage. SwiftEchada's
  `SourceMaterialLocator` may already cover this; confirm before the code is lost.
- **Q9 — The dead `CastMemberData` pipeline.** All three LLM backends populate
  `GeneratedProjectMetadata.cast` during `proyecto generate`, and **nothing reads it** — an LLM
  extracts cast metadata that is then discarded. Out of scope here, but someone should decide
  whether to wire it up, delete it, or file it.
- **Q10 — SwiftHablare step 0.** Removing the phantom dependency is zero-risk and independently
  valuable. Do it now, decoupled from this effort? *Recommendation: yes, this week.*
- **Q14 — `Appearance` shape (`RQ-Q2`).** One LoRA per character, or `[LoRAAsset]` with per-adapter
  rank/scale/engine compatibility? SwiftSemblanzas' own `REQUIREMENTS.md` §4.1 suggests the latter.
  **Answer before SwiftReparto tags 1.0.0** — adding a field later is routine, changing its shape is
  not.

---

## 10. Validation evidence

Findings behind the decisions above. Established 2026-07-26 by reading the source; re-verified
2026-08-01 where marked.

**Established 2026-08-01 (the split):**

- SwiftPM detects dependency cycles at **package** granularity. `SwiftProyecto → SwiftEchada` while
  `SwiftEchada → SwiftProyecto` fails at manifest load; no target-level arrangement avoids it.
- The `SwiftEchada` **library** target imports SwiftProyecto at exactly two sites
  (`CharacterProfile.swift:2`, `CharacterMerger.swift:1`) for exactly two symbols, `Gender` and
  `CastMember`. After the move it depends on SwiftReparto alone.
- `intrusive-memory/SwiftReparto` **does not exist** — confirmed 404.
- `pkg/SwiftSemblanzas` exists, is pre-alpha with no `Sources/`, and reserved the name `Reparto` for
  its §4.2 per-scene composition type. Renamed to `Convocatoria`.
- SwiftHablare's phantom SwiftProyecto dependency is **still present** at `Package.swift:65-66,74`.
- SwiftEchada's SwiftProyecto floor is `4.8.1` (`Package.swift:27`), not 4.6.1 as first stated.

**Established 2026-07-26:**

- `Gender` is referenced **only** in `SwiftProyecto/Models/CastMember.swift` within that repo.
- **No** podcast `PROJECT.md` contains `seasons:` or `variants:`. The layered cast model in
  `VariantResolver`/`SeasonDefinition` is unused in production.
- 12 of 16 podcast repos contain `cast:`; 2 have no `PROJECT.md` at all.
- Produciesta's real cast surface is **6 source files**, 8 test files, 6 fixtures, 2 manifests, and
  the Xcode project — not the 2 files first claimed.
- ~~`ProjectBrowser` displays cast.~~ **Corrected:** the target declares `dependencies: []` and does
  not link SwiftProyecto — it cannot reference `CastMember`.
- ~~`proyecto generate` writes cast into PROJECT.md.~~ **Corrected:** no `CastMemberData` →
  `CastMember` conversion exists anywhere in `Sources/`.
- ~~`mergingCastVoices`~~ **Corrected:** the symbol is `mergingCast(_:forProvider:)` (`:645`).
- `VariantResolver.resolveCast` is `private static`, not public API.
- Produciesta's file access is **directory-scoped** (bookmark on the folder, not the file), so a
  sibling `CAST.md` is already readable and writable. No entitlement changes needed.
- `CastExtractor` returns `[String]` — no `CastMember` coupling, safe to leave in SwiftProyecto.
- `AnyCodable` is a public SwiftProyecto type (`Models/AnyCodable.swift:33`).
- YAML comes from `marcprux/universal` — pure Swift, no heavy transitive deps.
- `confessions/PROJECT.md` uses the **scalar** `voices: voxalta: voices/NARRATOR.vox` form and
  carries a per-member `bio:` key — both must survive seeding (EC-7) untouched.
