---
type: cast
title: CAST.md Extraction — Controlling Requirements
status: draft
created: 2026-07-26
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
| SwiftProyecto | `package-collection/pkg/SwiftProyecto` | `REQUIREMENTS-cast-md-changes.md` |
| Produciesta | `apps/Produciesta` | `REQUIREMENTS-cast-md-changes.md` |
| podcasts/* (12 content repos) | `~/Projects/podcasts/*` | no doc — content rollout only, see §7 |

---

## 1. Motivation

Cast data currently lives in `PROJECT.md`'s YAML front matter as `ProjectFrontMatter.cast`, a
**SwiftProyecto** model. SwiftEchada — whose entire purpose is casting and voice generation — is a
downstream consumer that parses, mutates, and writes back a schema it does not own.

The goal is a clean ownership boundary:

- **`PROJECT.md` is SwiftProyecto's config file.** Project identity, episode discovery, variants, TTS config.
- **`CAST.md` is SwiftEchada's config file.** Cast list, voice prompts, voice files, character summaries.

Any utility needing cast information uses SwiftEchada's processor. Any utility needing project
information uses SwiftProyecto's processor. Neither reaches into the other's file.

---

## 2. Locked decisions

Decided; not open for re-litigation in the sibling docs.

| # | Decision |
|---|---|
| D1 | **Ownership split.** SwiftEchada owns `CAST.md` end to end. SwiftProyecto owns `PROJECT.md` and loses all cast modelling. |
| D2 | **Hard cut, staged.** `cast:` is ultimately removed from `ProjectFrontMatter` entirely — no dual-read, no permanent fallback. But the rollout is **two-phase and non-destructive**: CAST.md is generated alongside an untouched PROJECT.md, verified, and only then is `cast:` removed. See §4.2 and §6. |
| D3 | **Format.** YAML front matter with the same `CastMember` shape as today, plus a free markdown body. No new serialization format. |
| D4 | **File references.** `.vox` paths stay in `voices.voxalta` (relocated as-is). One new optional field: `portrait`. |
| D5 | **Body content.** Markdown body holds character summaries split into major/minor sections. Generation of that body is **deferred** (§8) — the format is reserved now, filled later. |
| D6 | **Dependency direction.** SwiftEchada → SwiftProyecto, never the reverse. Nothing in SwiftProyecto may import SwiftEchada. |
| D7 | **No destructive migration.** There is no one-shot "move the data" command. Generation and removal are separate, separately-triggered operations with a human verification gate between them. |

---

## 3. CAST.md schema

Lives beside `PROJECT.md`. Default filename `CAST.md`.

```markdown
---
type: cast
cast:
  - character: NARRATOR
    actor: Tom Stovall
    gender: M
    voicePrompt: "Deep authoritative British baritone. Warm, commanding documentary narrator."
    language: en
    portrait: art/narrator.png
    voices:
      voxalta:
        - voices/NARRATOR.vox
  - character: THE PRACTITIONER
    voicePrompt: "Younger adult male voice. Conversational, sometimes anxious, occasionally wry."
    bio: "Neurodivergent (ADHD), gay Gen X developer in his late forties…"
    voices:
      voxalta:
        - voices/THE_PRACTITIONER.vox
---

# Cast

## Major Characters

### NARRATOR

Summary prose here.

## Minor Characters

### …
```

### 3.1 Front matter

- `type: cast` — document discriminator, lowercase, matching the existing `type: project`
  convention in PROJECT.md.
- `cast:` — array of cast members. Field-for-field identical to today's `CastMember`, with the
  additions and rules below.

> **Snag to resolve (see §9 Q6):** the repo-wide markdown frontmatter policy requires every `.md`
> file to declare `type:`. These `REQUIREMENTS-cast-md-changes.md` docs therefore also carry
> `type: cast`, which means a naive "find all cast documents" scan would match them. Either the
> discriminator needs to be more specific (`type: echada-cast`), or `CastMarkdownParser` must
> additionally require a `cast:` key before accepting a file.

### 3.2 `CastMember` fields

| Field | Type | Notes |
|---|---|---|
| `character` | String, required | Character name as it appears in CHARACTER cues |
| `actor` | String? | Credits/reference only |
| `gender` | `Gender`? | `M` / `F` / `NB` / `NS` |
| `voicePrompt` | String? | Preferred key. Legacy alias `voiceDescription` must still decode |
| `voices` | `[String: [String]]` | Provider → file paths/IDs. Scalar form (`voxalta: path.vox`) must still decode |
| `language` | String? | BCP-47 |
| `portrait` | String? | **New.** Project-relative path to a character image. Manually populated |
| *(unknown keys)* | — | Preserved verbatim via `extraKeys` (this is how `bio:` survives) |

### 3.3 Path semantics

All file references (`voices.*`, `portrait`) are **relative to the directory containing CAST.md**,
which is the project directory. This matches current `.vox` behaviour exactly. Absolute paths are
permitted but not emitted.

### 3.4 Body

Free markdown. Reserved structure is `## Major Characters` / `## Minor Characters` with an `###`
heading per character. Nothing generates this yet (§8). Hand-authored content in the body **must
survive** every write-back.

---

## 4. SwiftEchada requirements

Prefix `EC-`. Sibling docs reference these IDs.

### 4.1 Model & parsing

- **EC-1** — `CastMember` and `Gender` are defined in the `SwiftEchada` library target, moved from
  SwiftProyecto. Public API, `Codable`, `Sendable`, `Equatable`, `Hashable`, `Identifiable`.
  Decoding must accept every form currently in the wild: `voicePrompt` and legacy
  `voiceDescription`; `voices` as scalar and as array.
- **EC-2** — `CastMember.extraKeys` lossless round-trip is preserved. Unknown per-member keys
  (`bio:` and anything else a user hand-writes) decode into `extraKeys` and re-emit verbatim.
- **EC-3** — New type `CastDocument` holding `(cast: [CastMember], body: String)` plus any
  front-matter-level fields (`type`).
- **EC-4** — New type `CastMarkdownParser` with `parse(fileURL:)`, `parse(content:)`,
  `generate(document:)`, and `write(document:to:)`. Ports `renderCast` and the YAML emit/escape
  logic from SwiftProyecto's `ProjectMarkdownParser`. Requires adding the
  `marcprux/universal` dependency to the `SwiftEchada` library target.
- **EC-5** — `AnyCodable` is available to the `SwiftEchada` target (either vendored or consumed
  from SwiftProyecto, which exports it publicly). See §9 Q4.

### 4.2 Non-destructive rollout

The two operations below are **separate commands** and must never be fused. Generation writes only
`CAST.md`; removal touches only `PROJECT.md`. A human verification gate sits between them.

- **EC-6** — A **legacy read path** reads `cast:` out of a `PROJECT.md` front matter *as raw YAML*,
  without depending on `ProjectFrontMatter.cast` (which is being deleted). It powers EC-7's seeding
  and EC-9's verification, and is removed once SwiftProyecto 5.0 ships (§6, step 6).

- **EC-7 — Generate CAST.md, seeded, never destructive.** `echada generate cast` writes `CAST.md`.
  When `CAST.md` is absent and `PROJECT.md` carries a legacy `cast:`, that existing cast is
  **seeded into CAST.md verbatim** — every field, including `voicePrompt`, `bio` and other
  `extraKeys`, `language`, and `voices.voxalta` paths — and then newly-discovered characters are
  merged in on top using the existing additive merge. **`PROJECT.md` is not modified.**

  > **Why seeding, not fresh generation.** Regenerating cast from screenplays alone would discard
  > every hand-tuned `voicePrompt` and `bio`. Worse, existing `.vox` files were generated *from*
  > those prompts — replacing the prompts silently desynchronizes each character's recorded voice
  > from its stated description, with no error and no diff to notice. Seeding is what makes
  > "generate CAST.md in their directories" safe to run against live podcast projects.

- **EC-8** — EC-7 is idempotent and non-clobbering. If `CAST.md` already exists it is merged into
  additively, never overwritten. `--force` re-syncs to discovered characters (matching today's
  `generate cast --force` semantics). `--dry-run` prints the resulting cast without writing.

- **EC-9 — Verification.** A command (name TBD, §9 Q3) that compares a project's `CAST.md` against
  the legacy `cast:` still present in its `PROJECT.md` and reports any divergence: characters
  present in one and not the other, differing field values, and `.vox` paths that do not resolve to
  an existing file. Exits non-zero on divergence so it can gate step 5 in CI or a loop. This is the
  human gate — it reports, it does not fix.

- **EC-10 — Removal, separately triggered.** A distinct command (§9 Q3) strips the `cast:` block
  from `PROJECT.md`, preserving all other front matter and the body byte-for-byte where possible.
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
- **EC-13** — All three gain a `--cast` option (default `CAST.md`), resolved as a sibling of
  `--project` when relative. See §9 Q1.
- **EC-14** — When `CAST.md` is absent, `generate cast` creates it (EC-7). `generate prompt` and
  `generate vox` fail with an actionable error naming `echada generate cast`.
- **EC-15** — `CastCommand` (the `echada cast` orchestrator) ensures `CAST.md` alongside its
  existing `PROJECT.md` bootstrap, and cascades `--cast` to every stage. It must **not** invoke
  EC-10 removal.
- **EC-16** — `CastVoiceGenerator` continues to write `.vox` files to `voices/` and record paths in
  `voices.voxalta`. Paths become CAST.md-relative (identical in practice — same directory).
- **EC-17** — `CharacterMerger` is updated for the new `CastMember` location. Behaviour unchanged.
- **EC-18** — Body preservation: every write-back through `CastMarkdownParser` preserves the
  markdown body verbatim. Regression test required — this is the same class of bug as issue #44,
  where a field-by-field front matter rebuild silently destroyed `appSections`.

### 4.4 Documentation

- **EC-19** — Update `AGENTS.md`, `CLAUDE.md`, `README.md`, `Docs/architecture.md`,
  `Docs/api.md`, `Docs/vox-pipeline.md`, `Docs/gotchas.md`, and `CHANGELOG.md`.
- **EC-20** — Update the `cast-voices` and `podcast-audio-plan` skills in `~/.claude/skills/`,
  which instruct agents to read/write cast in `PROJECT.md`.

### 4.5 Tests

- **EC-21** — Update the affected test files: `CastPipelineTests`, `GenerateCastCommandTests`,
  `GenerateVoxCommandTests`, `GenerateVoxWriteBackTests`, `VoicePromptRoundTripTests`,
  `PerLanguagePromptTests`, `ModelBackedGenerationTests`, `CastingLanguageResolutionTests`,
  `NonEnglishPassthroughTests`, `CharacterMergerTests`.
- **EC-22** — New coverage: CAST.md parse/generate round-trip; `extraKeys` preservation; body
  preservation; legacy `voiceDescription` and scalar-`voices` decoding; **seeding fidelity (EC-7)**;
  EC-7 idempotency; EC-9 divergence detection; EC-10 idempotency and PROJECT.md preservation;
  missing-CAST.md error paths.

---

## 5. Cross-repo scope summary

Detail lives in each repo's own doc. This is the boundary contract.

### SwiftProyecto (breaking, 5.0)

Full detail in `pkg/SwiftProyecto/REQUIREMENTS-cast-md-changes.md` (`PR-0` … `PR-31`). Verified
2026-07-26 against source; corrections to the first draft are marked.

| Deletion | Validation |
|---|---|
| `ProjectFrontMatter.cast`, `withCast(_:)`, `mergeCast`, `mergingCast(_:forProvider:)` | Moves to SwiftEchada. **Correction:** the symbol is `mergingCast(_:forProvider:)` (`:645`), not `mergingCastVoices`. This is the API Produciesta actually calls |
| `Models/CastMember.swift` (`CastMember`, `Gender`) | `Gender` has **zero** references outside this file — confirmed |
| `proyecto roles` (`Sources/proyecto/RolesCommand.swift`) | Duplicate of `echada generate cast`. Cannot be kept — it writes cast, so it would need SwiftEchada, which is a **cycle**. Confirmed it writes `frontMatter.cast` |
| `ProjectService.discoverCastList` / `mergeCastLists` | Public API returning `[CastMember]`. Orphans the private `extractCharacters(from:)` (`:648`) — note this is a **second, independent** character parser that does *not* use `CastExtractor`, so it is not equivalent to EC-7 |
| `ProjectDiscovery.readCast(from:providerID:)` | Public API returning `[CastMember]` |
| `SeasonDefinition.cast`, `VariantResolver.resolveCast` | **No podcast project uses `seasons:` or `variants:`** — re-verified across all 16 dirs. **Correction:** `resolveCast` is `private static` (`:199`), not public. `resolve(...)` returns `ProjectFrontMatter` before and after — nothing to redesign |
| `ProjectMarkdownParser.renderCast` / `replacingCastBlock` | Ports to `CastMarkdownParser`. **`replacingCastBlock` is needed twice by SwiftEchada** — for CAST.md write-back *and* for EC-10's `cast:` excision, where "delete exactly this line span" is the entire requirement. Port deliberately |
| `proyecto validate --verbose` cast count (`ProyectoCLI.swift:192-194`) | **Newly found** — an unlisted compile-error site |

**Struck from the first draft — these deletions describe work that does not exist:**

- ~~Cast display in `ProjectBrowser`~~ — the `ProjectBrowser` target declares `dependencies: []`
  and does not link SwiftProyecto at all, so it *cannot* reference `CastMember`. The only match was
  the word "podcast" in a SwiftUI preview string. (DEF-2's architectural note remains valid.)
- ~~Cast write-out in `ProjectGeneratorService`~~ — there is no `CastMemberData` → `CastMember`
  conversion anywhere in `Sources/`. `GeneratedProjectMetadata.cast` is populated by all three LLM
  backends and read by **nothing**. `proyecto generate` never wrote cast into PROJECT.md. See §9 Q9.

**Retained (confirmed):** `CastExtractor` — returns `[String]`, no `CastMember` coupling, live
consumer at `ProjectService.swift:1182`. `LLMBackendProtocol.CastMemberData` — generation-time DTO.
`AnyCodable` — public.

**Test blast radius is smaller than first stated.** `ProjectValidatorTests`, `IntroOutroAssetsTests`,
and `DocumentationExamplesTests` have **zero** cast references (matches were `broadcast`/`podcast`).
The five LLM-backend test files use the retained `CastMemberData`. `DirectoryAnalysisTests` tests
the retained `CastExtractor`.

**No deprecation shims** (PR-28). A shim for `ProjectFrontMatter.cast` would need `CastMember`,
which by then lives in SwiftEchada and cannot be imported (D6). The only way to write one is to keep
a duplicate `CastMember` in SwiftProyecto, which is worse than the problem. The staged rollout in §6
*is* the migration.

### ⛔ Diamond dependency — hard release blocker

```
SwiftEchada → SwiftVoxAlta 0.14.1 → SwiftHablare 6.2.0 → SwiftProyecto 4.0.0..<5.0.0
SwiftEchada ────────────────────────────────────────────→ SwiftProyecto 5.0.0..<6.0.0
```

When SwiftEchada raises its SwiftProyecto floor to 5.0.0, those ranges are **disjoint and SwiftPM
resolution fails outright**. Step 7's "bump echada + Produciesta" is insufficient — as written it
needs five sequenced releases across four repos.

**Resolution: SwiftHablare's SwiftProyecto dependency is a phantom.**
`grep -rn SwiftProyecto SwiftHablare/{Sources,Tests}` returns nothing. Deleting it dissolves the
diamond permanently, is a non-breaking patch release for SwiftHablare, shrinks every downstream
dependency graph, and is worth doing **regardless of this effort**. It becomes step 0 in §6.

Two further consumers found: `apps/Proyecto` (macOS GUI, Xcode remote package ref,
`minimumVersion = 4.6.2`, no cast usage) and SwiftHablare above.

### Produciesta (consumer)

Full detail in `apps/Produciesta/REQUIREMENTS-cast-md-changes.md` (`PD-1` … `PD-40`). Verified
2026-07-26 against source; several claims in the first draft of this document were **wrong** and are
corrected here.

**Scope is 6 source files, not 2.** The four missed by the first draft:

| File | Why |
|---|---|
| `ProduciestaCLICore/CastSupport.swift` | **The critical one.** Every cast read in the product funnels through `:168-179`, and it owns *both* PROJECT.md path-construction sites (`:148-156`, `:159-165`) |
| `ProduciestaCore/ProjectMd/ProjectMdSyncService.swift` | Two **public** functions (`merge(_:into:)` `:102-107`, `makeMinimalFrontMatter(title:cast:)` `:153-165`) exist purely to push cast into `ProjectFrontMatter` |
| `ProduciestaCore/ProjectMd/CastResolver.swift` | Consumes `CastMember` structurally (`:39`, `:61`) |
| `ProduciestaCLICore/CastCommand.swift` | The `produciesta cast --export` verb |

Plus the two already known (`ProjectMd/ProjectMdCast.swift`, `ProjectMd/CastWriter.swift`),
8 test files, 6 fixtures, 2 package manifests, and the Xcode project.

**Corrections to earlier claims in this document:**

- **SwiftEchada is already a dependency.** Declared in both manifests; the light `SwiftEchada`
  product is already linked into `ProduciestaCore` (`Package.swift:36`), merely never imported.
  No new dependency is needed — only imports and a version bump.
- **"Avoid `EchadaCLICore`" is wrong for one target.** `EchadaCLICore` is already linked
  *deliberately* to the `echada` Xcode tool target that ships the signed binary inside
  `Produciesta.app`. Avoid it in `ProduciestaCore`; keep it in the tool target.
- **Sandbox risk is LOW**, contrary to the concern raised when dispatching. The app's grant is
  **directory-scoped**, not file-scoped: `NSOpenPanel` with `canChooseDirectories = true`,
  bookmark taken on the *directory*, `startAccessingSecurityScopedResource()` held on the
  directory for the window's lifetime. A newly-created sibling `CAST.md` is already covered for
  read *and* write. The three embedded CLIs are deliberately unsandboxed, and that is where all
  cast I/O happens. **No entitlement, bookmark, or picker changes needed.**
- **Not affected:** `Gender`, `mergeCast`, `readCast`, `discoverCastList`, `voicePrompt`,
  `voiceDescription` have zero Swift references in this repo. `GenerateScreenplayUseCaseTests` is
  unaffected.

**New blocking issues raised by this repo:**

- **X-1 — `CastWriter` prunes; EC-8 says writes are additive.** `CastWriter.swift:91-98` deletes
  every cast entry absent from the *current screenplay's* roster. `CAST.md` is project-wide but
  `produciesta cast/export` runs per-episode — so exporting episode 01 of a 12-episode podcast
  would delete every other character, taking their hand-authored `bio` and `voicePrompt` with them
  and orphaning the `.vox` files those prompts generated. **EC-8's additive guarantee must win;
  `CastWriter` changes behaviour.** See §9 Q7.
- **X-2 — No `sibling()` pattern, and `Package.resolved` is gitignored.** There is no supported way
  to build Produciesta against an unreleased local SwiftEchada. Mitigated by the §6 reorder, which
  places Produciesta's work after SwiftEchada 1.0.0 is tagged — but SwiftEchada **must** be a real
  tagged release by then, not a local checkout.
- **X-3 — Two manifests pin independently.** A one-sided bump makes `make build` and
  `make install-gui` resolve different SwiftEchada versions.
- **X-4 — The `echada` binary is embedded and code-signed inside `Produciesta.app`.** EC-20's skill
  update therefore depends on a Produciesta *release*, not just a doc edit.
- **X-5 — `Docs/PROJECT_MD.md`** is a written contract now mostly describing a file Produciesta no
  longer owns, including a normative §4 rule 4 this change must retire.

**Transition-window type ambiguity** stands: both modules export `CastMember` until SwiftProyecto
5.0 lands. Use targeted imports (`import struct SwiftEchada.CastMember`), the house style in
SwiftEchada's `CLAUDE.md` rule 3.

`apps/produciesta-old/` is legacy and out of scope.

---

## 6. Sequencing

Ordered to avoid a flag day. Each step ships independently; nothing downstream breaks until step 6.

**Reordered 2026-07-26.** The original order put Produciesta *after* the podcast `cast:` removal.
That is a silent-data-loss flag day: once step 5 strips `cast:`, the shipped Produciesta gets
`frontMatter.cast == nil` → empty `ProjectMdCast` → `CastResolver` returns an empty map → **every
character unassigned, with no throw and no warning.** Produciesta must be repointed *before* any
`cast:` is removed. The reorder is free.

| Step | Repo | Work | Gate |
|---|---|---|---|
| **0** | SwiftHablare | Delete the **phantom** SwiftProyecto dependency (zero source references). Patch release. Dissolves the §5 diamond | `make test` green; downstream graphs resolve |
| **1** | SwiftEchada | EC-1 … EC-5. Add `CastMember`/`Gender`/`CastDocument`/`CastMarkdownParser`. No behaviour change yet — SwiftProyecto still owns `cast:` | Unit tests green |
| **2** | SwiftEchada | EC-6 … EC-11. Seeded generation, verification, and the separate removal command | EC-11 round-trip test green against a copy of a real podcast `PROJECT.md` |
| **3** | SwiftEchada | EC-12 … EC-22. Rewire the commands, docs, tests. **Tag and ship 1.0.0** — a real release, not a local checkout (X-2) | `make test` green; manual `echada cast` run against a scratch project |
| **4** | podcasts/* | **Generate only.** Run EC-7 across the 12 projects with `cast:`. `CAST.md` appears; `PROJECT.md` untouched. Commit per repo | EC-9 clean in each; `echada generate vox --dry-run` lists the same members as before |
| **5** | Produciesta | Repoint the 6 source files to SwiftEchada; fix `CastWriter` pruning (X-1); bump both manifests together (X-3). **Ship** | App builds; audio generation works end to end against a step-4 project (both `CAST.md` and legacy `cast:` present) |
| **6** | podcasts/* | **Remove only, after verification.** Run EC-10 per repo. Separate commit per repo | EC-9 clean; residual `PROJECT.md` diff is cast-block-only |
| **7** | SwiftProyecto | Delete everything in §5. **Ship 5.0.** Bump echada + Produciesta + `apps/Proyecto`. Remove EC-6's legacy read path | `make test` green in all repos |

Steps 0–4 are strictly additive from the outside — SwiftProyecto and Produciesta keep working
untouched throughout, and step 4 leaves every `PROJECT.md` byte-identical. Step 5 must land before
step 6. Step 6 is reversible per repo via git. Step 7 is the only breaking release and can be
deferred indefinitely: after step 6, `cast:` in `PROJECT.md` is dead weight, not a blocker.

**Step 5 requires a live dual state.** At that point every migrated project has both a `CAST.md`
*and* a `PROJECT.md` still containing `cast:`. Produciesta must read `CAST.md` and ignore the legacy
block. EC-9 having passed is what guarantees they agree.

---

## 7. Podcast content repos

12 of the 16 podcast repos under `~/Projects/podcasts/` have a `cast:` block. They need **content
rollout only** — no code, no requirements doc. Each is an independent git repo.

- **PC-1** — Rollout is performed by the EC-7 and EC-10 commands, not by hand.
- **PC-2** — Generation (step 4) and removal (step 5) are **separate commits** in each repo, so
  either can be reverted independently.
- **PC-3** — No cross-repo batching. One repo, one commit, per phase.
- **PC-4** — `~/Projects/podcasts/common-voices` is not a git repo — handle or skip explicitly.
- **PC-5** — Per-repo gate before step 5: EC-9 verification clean, and every `.vox` path in
  `CAST.md` resolves to an existing file.
- **PC-6** — Pilot on `confessions` first — richest cast (`bio`, multi-line `voicePrompt`, scalar
  `voices` form, 309-line `PROJECT.md` with a large `episodes_index`). Do not roll out further
  until its `CAST.md` is eyeballed and its `PROJECT.md` diff is confirmed cast-block-only.

---

## 8. Deferred — explicitly out of scope

Real work, tracked separately. **Not** part of the CAST.md extraction.

- **DEF-1 — Major/minor character summaries.** The §3.4 body structure is reserved but nothing
  generates it. Needs (a) a major/minor classifier — dialogue line count from `DialogueExtractor`
  is the natural signal, plus a threshold — and (b) a summary generator, i.e. a fourth Foundation
  Model stage comparable in size to `GeneratePromptCommand`. Land after step 3.
- **DEF-2 — Generic cast panel.** Extracting the cast panel from
  `apps/produciesta-old/Produciesta/CastingView.swift` into a reusable UI component.
  **Architectural note:** it cannot live in SwiftProyecto's `ProjectBrowser` — that would recreate
  the dependency cycle (D6). It would be a new SwiftUI product in SwiftEchada (e.g. `EchadaUI`)
  that apps compose alongside `ProjectBrowser`. Needs its own spec.
- **DEF-3 — Portrait generation.** `portrait` (D4) is a manually-populated field. Nothing generates
  character art.
- **DEF-4 — Reference audio / dialogue extract persistence.** Considered and rejected for this
  round; `ReferenceAudioGenerator` output and `DialogueExtractor` results stay transient.

---

## 9. Open questions

Blocking implementation, not requirements. Resolve before step 1.

- **Q1 — CAST.md location.** Convention-only (sibling of `PROJECT.md`, `--cast` to override), or may
  `PROJECT.md` declare `castFile: CAST.md`? The latter works without SwiftProyecto knowing about
  cast — unknown keys land in `appSections` and round-trip losslessly — but it puts a cast concern
  back in the project file. *Recommendation: convention only.*
- **Q2 — Legacy `cast:` after step 7. Worse than first stated.** A stale `cast:` swept into
  `appSections` is re-emitted **last, alphabetically sorted, through the generic JSON→YAML path** —
  so it *moves position and reformats* (member key order changes, the scalar `voices` form is
  rewritten). Not a silent passthrough: a visible, confusing diff. Also, `ProjectValidator` has zero
  cast code today, so the recommended warning is **new code**, not a modification. Warn, strip, or
  ignore? *Recommendation: `proyecto validate` warns; nothing strips automatically.*
- **Q3 — Command names for EC-9 and EC-10.** Needs two verbs that read as clearly separate and
  clearly non-destructive/destructive. Candidates: `echada cast verify` + `echada cast prune`;
  `echada verify cast` + `echada strip cast`. Must not collide conceptually with `echada cast`, the
  full-pipeline orchestrator. *Recommendation: `echada verify cast` and `echada prune cast`,
  parallel to the existing `generate` namespace.*
- **Q4 — `AnyCodable` (EC-5).** Vendor into SwiftEchada or import from SwiftProyecto?
  *Recommendation from SwiftProyecto: **import, not vendor**. Its exact JSON round-trip semantics
  are what make `extraKeys`/`appSections` lossless, and SwiftEchada cannot drop the SwiftProyecto
  dependency anyway (EC-12 still reads PROJECT.md). Zero work in SwiftProyecto either way.*
- **Q5 — Is `proyecto roles` truly unused?** No callers found anywhere under `~/Projects`, but shell
  history and CI outside this collection were not searched. Confirm before deleting.
- **Q6 — `type: cast` collision (§3.1).** The repo markdown policy forces `type:` onto every `.md`,
  so these requirements docs also declare `type: cast`. Made concrete by Produciesta, whose own
  convention for this kind of document is `type: requirements`
  (`Docs/REQUIREMENTS-fcpxml-export.md`) — so the three sibling docs are currently mislabelled to
  satisfy a hook. Either narrow the discriminator (`type: echada-cast`) or have
  `CastMarkdownParser` require a `cast:` key as well, and relabel these docs `type: requirements`.
  *Recommendation: require both `type` and `cast:` in the parser; relabel the requirements docs.*

- **Q7 — `CastWriter` pruning vs. EC-8 (X-1).** `CastWriter.swift:91-98` deletes cast members absent
  from the current screenplay's roster. `CAST.md` is project-wide; `produciesta cast/export` is
  per-episode. Confirm EC-8's additive-only guarantee wins and Produciesta's `Docs/PROJECT_MD.md`
  §4 rule 4 is retired. If per-project pruning is still wanted, who owns it — `echada generate cast
  --force` already does exactly this, correctly scoped. *Recommendation: additive-only wins;
  pruning stays with `--force` in echada.*

- **Q8 — Salvage from `proyecto roles` before deleting it.** It contains
  `discoverScreenplays(in:)` and `expandGlob(_:)` — ~35 lines, and the collection's only `glob(3)`
  usage. SwiftEchada's `SourceMaterialLocator` may already cover this; confirm before the code is
  lost.

- **Q9 — The dead `CastMemberData` pipeline.** All three LLM backends populate
  `GeneratedProjectMetadata.cast` during `proyecto generate`, and **nothing reads it** — an LLM
  extracts cast metadata that is then discarded. Out of scope here, but someone should decide
  whether to wire it up, delete it, or file it.

- **Q10 — SwiftHablare phantom dependency (step 0).** Removing it is zero-risk, independently
  valuable, and collapses step 7 from five sequenced releases across four repos back to the shape
  this document assumes. Do it now, decoupled from this effort? *Recommendation: yes, this week.*

---

## 10. Validation evidence

Findings behind the decisions above, established 2026-07-26 by reading the source.

- `Gender` is referenced **only** in `SwiftProyecto/Models/CastMember.swift`. Zero other usages.
- **No** podcast `PROJECT.md` contains `seasons:` or `variants:`. The layered cast model in
  `VariantResolver`/`SeasonDefinition` is unused in production.
- `VariantResolver` and `SeasonDefinition` have no consumers outside SwiftProyecto's own sources
  and tests.
- 12 of 16 podcast repos contain `cast:`; 2 have no `PROJECT.md` at all.
- ~~Produciesta's real cast surface is exactly 2 files.~~ **Corrected:** 6 source files, 8 test
  files, 6 fixtures, 2 manifests, and the Xcode project. `apps/produciesta-old/` is legacy.
- ~~`ProjectBrowser` displays cast.~~ **Corrected:** the target declares `dependencies: []` and
  does not link SwiftProyecto — it cannot reference `CastMember`.
- ~~`proyecto generate` writes cast into PROJECT.md.~~ **Corrected:** no
  `CastMemberData` → `CastMember` conversion exists anywhere in `Sources/`.
- ~~`mergingCastVoices`~~ **Corrected:** the symbol is `mergingCast(_:forProvider:)` (`:645`).
- `VariantResolver.resolveCast` is `private static`, not public API.
- Produciesta's file access is **directory-scoped** (bookmark on the folder, not the file), so a
  sibling `CAST.md` is already readable and writable. No entitlement changes needed.
- A diamond dependency (`SwiftEchada → SwiftVoxAlta → SwiftHablare → SwiftProyecto 4.x`) would
  break SwiftPM resolution at step 7. SwiftHablare's SwiftProyecto dependency is a phantom with
  zero source references.
- `CastExtractor` returns `[String]` — no `CastMember` coupling, safe to leave in SwiftProyecto.
- `AnyCodable` is a public SwiftProyecto type (`Models/AnyCodable.swift`).
- YAML comes from `marcprux/universal` — pure Swift, no heavy transitive deps.
- `.vox` paths are already project-relative file references in `voices.voxalta`; the "file
  references in CAST.md" requirement is largely satisfied by relocation.
- SwiftEchada's `SwiftEchada` library target depends only on SwiftProyecto (no ML/voice deps —
  those are `EchadaCLICore`), so it is a viable home for a cast processor that GUIs can import.
- `confessions/PROJECT.md` uses the **scalar** `voices: voxalta: voices/NARRATOR.vox` form and
  carries a per-member `bio:` key — both must survive seeding (EC-7) untouched.
