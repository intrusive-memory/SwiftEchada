---
type: requirements
state: draft
created: 2026-09-25
updated: 2026-10-21
target_version: 2.1.0
controlling_doc: dossier-format docs/DOSSIER-FORMAT.md (https://github.com/intrusive-memory/dossier-format)
depends_on: SwiftReparto 0.2.0 (../SwiftReparto/REQUIREMENTS.md)
---

# SwiftEchada 2.1.0 — Voices Move Into the Character Record

Today every `.vox` file goes into one flat `voices/` folder next to `CAST.md`.
The file name is the character's name with spaces replaced by underscores:
`voices/THE_PRACTITIONER.vox`.

The character record, a `.dossier` bundle (dossier-format
`docs/DOSSIER-FORMAT.md`), gives each cast member their own directory, named
exactly after them, which holds all of that character's assets. This document
moves voice files into it:

```
characters/THE PRACTITIONER.dossier/voice/THE PRACTITIONER.vox
```

*Updated 2026-10-21:* retargeted from 1.1.0 to 2.1.0. SwiftEchada 2.0.0
took SwiftProyecto 5, removed `echada verify cast` and `echada prune cast`, and
made migration off a legacy `cast:` block automatic (`ProjectMigration`).
**EC-27 is withdrawn** (see its section); each of its checks has a new home.
Source line references are re-pinned to `development` at `2d67d79`.

*Updated 2026-10-19:* the record moved from SwiftSemblanzas §5 to
dossier-format; directories end in `.dossier`; sample names and variants
follow dossier-format §4 and §8.2.

It also adds the playable voice samples the character dossier needs.

**This supersedes EC-16 and D4** in
[`Docs/complete/cast-md-extraction-01/REQUIREMENTS-cast-md-changes.md`](Docs/complete/cast-md-extraction-01/REQUIREMENTS-cast-md-changes.md), which
kept `.vox` files in `voices/`. Everything else in that document stands. IDs
continue from it: EC-23 and up, with open questions as EC-Q1 and up.

**Status:** requirements only. Nothing is implemented yet.

---

## 1. Summary

| ID | Change |
|----|--------|
| EC-23 | Where a new `.vox` goes: follow the member's `manifest:` pointer |
| EC-24 | File names use the exact canonical name, with no underscore substitution |
| EC-25 | `voices.voxalta` records the new CAST-relative path |
| EC-26 | `echada migrate voices` moves existing files, dry-run by default |
| EC-27 | *Withdrawn 2026-10-21.* `echada verify cast` was removed in 2.0.0 |
| EC-28 | `echada sample` exports playable `.m4a` voice samples |
| EC-29 | Skills and docs updated |
| EC-30 | Tests |

---

## 2. Requirements

### EC-23 — Output location

When `CastVoiceGenerator` writes a `.vox`, it picks the location by the first
rule that applies. The folder is currently hard-coded at
`CastVoiceGenerator.swift:303`.

1. **The member has a `manifest:` pointer** (SwiftReparto RQ-20). Write to
   `<directory of manifest>/voice/<CHARACTER>.vox`, creating `voice/` if it
   doesn't exist.
2. **The member has no manifest but already has a `voices.voxalta` path.**
   Regenerate **in place**, at that exact path. Files are never moved
   silently; moving is EC-26's job.
3. **Neither: a new member with no voice and no manifest.** Write to
   `<charactersDir>/<CHARACTER>.dossier/voice/<CHARACTER>.vox`. `charactersDir`
   comes from PROJECT.md `personaje.charactersDir`, defaulting to
   `characters`.

   SwiftEchada does **not** create `manifest.json` and does **not** set the
   `manifest:` pointer. The folder it creates is picked up by the next
   SwiftDossier `refresh` or Personaje run, which adopts the orphan bundle,
   creates the manifest and sets the pointer through Reparto (dossier-format
   §3 adoption, §5.6).

- The destination is checked before writing. It must be inside the CAST.md
  directory, or equal to an existing `voxalta` path under rule 2. If a folder
  already exists whose name differs **only by case**
  (`characters/The Practitioner.dossier/`), the write is refused.
- **`echada voice --output` and `echada test-voice --output` are unchanged.**
  They're standalone tools that write wherever they're told.

### EC-24 — File names

- The filename is `CastMember.canonicalName(member.character) + ".vox"`
  (SwiftReparto RQ-22). Spaces and punctuation are kept exactly.
- Delete the space-to-underscore substitution at
  `CastVoiceGenerator.swift:331-332`.
- If `canonicalName` throws (the name contains `/` or `:`, or starts with
  `.`), that member fails with an error naming the character and telling the
  user to rename it in the screenplay. Other members keep generating.
- If a member's `character` isn't canonical yet (mixed case, say), generation
  **fails for that member** and points to `reparto canonicalize`. SwiftEchada
  never writes a file whose name differs from what CAST.md says.

### EC-25 — `voices.voxalta` write-back

- The paths written back (`CastVoiceGenerator.swift:350-353` and `:537`)
  are the EC-23 destination, relative to CAST.md, for example
  `"characters/THE PRACTITIONER.dossier/voice/THE PRACTITIONER.vox"`.
- Writes still go through Reparto's `CastDocument`, per D8/EC-18.
- **The duplication is deliberate.** The `.vox` path appears both in
  `voices.voxalta` (SwiftEchada's contract) and in the character's manifest
  as `kind: vox`. `voices.voxalta` is the authority for *which voice to play*;
  the manifest is the inventory of the bundle (dossier-format §8.2, D5). A
  mismatch is a dossier validation warning (`W-VOICE-ELSEWHERE`).

### EC-26 — `echada migrate voices`

SwiftEchada owns voice assets, so it owns the migration. This replaces the
`personaje migrate-voices` command proposed earlier.

```
echada migrate voices [--project PROJECT.md] [--cast CAST.md] [--apply]
```

- **It's a dry run unless `--apply` is given** (D7: nothing destructive in
  one shot). The dry run prints the plan: each member's old path, new path,
  and the pointer change.
- For each member with a `voices.voxalta` path:
  - The new path comes from EC-23 rule 1 if the member has a manifest,
    otherwise rule 3. The filename follows EC-24.
  - A path outside the project folder (absolute, or `../`, such as
    `common-voices/`) is **skipped** and reported. Shared voices are not
    per-character assets.
  - If the file is already at its new path, nothing is done.
- **Order under `--apply`:**
  1. Copy each file to its new path and confirm the SHA-256 matches.
  2. Rewrite every pointer in one `CastDocument` write.
  3. Re-parse and confirm every new pointer resolves.
  4. Only then remove the old files.

  If any step fails, stop and leave the old files and the old CAST.md
  untouched. The working copy is never half migrated.
- It refuses to run if two members would map to the same new path, if a
  destination already exists with different contents, or if any member's
  name isn't canonical. In the last case it names the members and tells the
  user to run `reparto canonicalize`; it never renames anything itself.
- It never touches `manifest.json`. The next manifest refresh classifies the
  moved files.
- **The dry run also reports a legacy `voices/` folder** that still holds
  `.vox` files no member points at. (This was EC-27's last check.)

### EC-27 — `echada verify cast` (withdrawn)

**Withdrawn 2026-10-21.** SwiftEchada 2.0.0 removed `echada verify cast`
(CHANGELOG 2.0.0). Each check this requirement added now lives elsewhere:

| Former EC-27 check | Now |
|--------------------|-----|
| Compare `role` and `manifest` as fields | **Dropped.** The only roster comparison left is `CastRosterVerifier.divergences` (`CastRosterVerifier.swift:49`, used by `ProjectMigration.swift:81`). It compares CAST.md against a legacy PROJECT.md `cast:` block, using a fixed field list (`character`, `actor`, `gender`, `language`, `voicePrompt`, …). A legacy block predates `role` and `manifest`, so there's nothing to compare them against. |
| Paths with spaces resolve, CAST-relative | An EC-30 test on the generator and `migrate voices` |
| Manifest/name mismatch is an error | Dropped from Reparto (its RQ-21 is withdrawn). dossier-format validation reports it as `E-NAME-MISMATCH` / `W-POINTER` (§3, §14) |
| A member's `.vox` outside its bundle's `voice/` | dossier-format validation, `W-VOICE-ELSEWHERE` (§8.2). The `migrate voices` dry run lists it as a planned move |
| A leftover legacy `voices/` folder | The `migrate voices` dry run (EC-26) |

### EC-28 — `echada sample`: playable voice samples

A browser can't play a `.vox`, and the character dossier has to play the
voice. SwiftEchada already stores sample audio inside the `.vox` bundle
(`VoxExporter.addSampleAudio`, `CastVoiceGenerator.swift:526`), but never
writes it out.

```
echada sample <CHARACTER> [--variant neutral|<name>]
                          [--text "…"] [--model 1.7b|0.6b] [--all-variants]
```

- **Output:** `<character dir>/voice/sample-<variant>.m4a` (AAC), where the
  character dir is the EC-23 location. A sample rendered on a model size
  other than the `.vox`'s default adds the size: `sample-neutral-0.6b.m4a`
  (dossier-format §4).
- **`neutral`, the default:** export the sample already embedded in the
  `.vox`, transcoded to `.m4a`. No new synthesis is needed.
- **Other variants:** synthesize `--text`, or the default sample line, with
  the character's `.vox`, and use the variant as the delivery instruction.
- **The default sample line** comes from CHARACTER.md (a `sampleLine:` field
  in its front matter), falling back to a fixed neutral sentence. The text
  used is printed, and in `--json` mode returned, so the manifest can record
  it as `sampleText`.
- It doesn't write the manifest. Personaje or SwiftDossier `refresh`
  registers the files as `kind: voiceSample`; `--json` returns `variant`,
  `model`, `language` and `sampleText` so the writer can record them.
- **`--all-variants`** renders every entry of `voice/samples.yaml`
  (dossier-format §10) when it exists, otherwise `neutral` on each model size
  in the `.vox`. There is no fixed range set: range variants are the
  character's own registers (dossier-format §8.2).

### EC-29 — Skills and docs

Every assumption that voices live in `voices/` gets updated:

- **`~/.claude/skills/cast-voices/`:**
  - `generate-cast-voices.sh`. This is **logic**: it globs
    `"$PROJECT_DIR"/voices/*.vox` for strays and must find `.vox` files via
    CAST.md pointers instead.
  - `SKILL.md` and `smoke.sh`. Their capability probe for the `verify` verb is
    already broken by 2.0.0 (CHANGELOG 2.0.0) and is fixed in the same pass.
- **`~/.claude/skills/podcast-audio-plan/SKILL.md`**
- **`~/.claude/skills/generate-episode-audio/SKILL.md`**
- Skill line numbers aren't pinned here; they drift with every skill edit.
  Find them with `grep -n 'voices/' <file>` at implementation time.
- **SwiftEchada:** `GenerateVoxCommand.swift:23` (help text) and
  `:215-216` (the EC-16 comment), plus `README.md`, `AGENTS.md`, `API.md`
  and `CHANGELOG.md`.
- **Produciesta** needs **no source change**, because it resolves pointers
  relative to the file (`VoiceReference.parse(_, relativeTo:)`). Add one
  fixture that has a path with spaces.

### EC-30 — Tests

- **Update** the tests that hard-code `voices/X.vox` output from the
  generator:
  - `GenerateVoxWriteBackTests.swift:35, 157`
  - `VoicePromptRoundTripTests.swift:25, 53, 78`
  - `ModelBackedGenerationTests.swift:195, 211, 256-257`
- **Keep** the tests that *read* legacy underscore pointers, because they
  test reading old data:
  - `LegacyProjectCastReaderTests.swift:47-51, 103-110`
  - `GenerateCastSeedingTests.swift:107-109, 219`
  - `CastMigrationLosslessnessTests.swift:115-118`
  - `ProjectMigrationTests.swift:23, 93, 114`

  Add character-directory (`.dossier`) variants alongside them.
- **New tests:**
  - All three EC-23 rules
  - A multi-word, punctuated name (`DR. O'NEILL`) end to end, including a
    CAST-relative path with spaces
  - A name that's invalid under canonicalization
  - Refusing to write when a folder differs only by case
  - The `migrate voices` dry run (including the leftover-`voices/` report),
    `--apply`, and rollback on an injected failure
  - A skipped `common-voices` path
  - `echada sample` exporting the neutral sample (not model-backed)
  - Variant synthesis, model-backed and local-only per suite convention

---

## 3. Rollout

1. **SwiftReparto 0.2.0** ships `role`, `manifest` and `canonicalName`.
2. **SwiftEchada 2.1.0** ships EC-23 to EC-30 (except the withdrawn EC-27).
3. **Pilot on `podcasts/granville`**, which already has a `CAST.md`:
   `reparto canonicalize`, then `echada migrate voices`, then `--apply`.
   Then check the result with dossier-format validation (SwiftDossier's
   validator, once it ships; until then, `migrate voices` dry-run reporting
   nothing left to move). Then regenerate one episode and compare its audio.
4. **The remaining CAST.md projects:** `palm-oasis`, `granville-sample`.
5. **Projects still on a PROJECT.md `cast:` block** (`confessions`,
   `the-tempest`, `meditations`, …) are migrated to `CAST.md` automatically
   the first time any `echada` stage opens them (2.0.0 `ProjectMigration`).
   Then step 3.

---

## 4. Open questions

| # | Question | Recommendation |
|---|----------|----------------|
| EC-Q1 | Is this 2.1.0 or 3.0.0? The default output location changes for **new** characters. | **2.1.0** for EC-23..EC-30 alone. Existing pointers are respected (EC-23 rule 2), so no existing project changes until someone runs `migrate voices`, and the only script that relies on the old location is our own skill, updated in the same release. **If the same release also removes `echada generate cast`** (Personaje requirements, EC-P11), that removal is breaking and the release is **3.0.0**. |
| EC-Q4 | Where does `charactersDir` (EC-23 rule 3) come from? | PROJECT.md has no `personaje.charactersDir` key today, and SwiftProyecto 5 doesn't define one. Use the fixed default `characters` in 2.1.0. Read a configured value only once the key exists in SwiftProyecto. |
| EC-Q2 | Should SwiftEchada link SwiftDossier's `Dossier` and register `.vox` and samples in the manifest directly? | Not in 2.1.0: refresh picks up the files. Revisit once SwiftDossier ships (Foundation + Reparto, no image stack). It removes the refresh step; `voices.voxalta` stays, as the which-voice-to-play authority (dossier-format D5). |
| EC-Q3 | Should `voice/` also hold the reference audio and the voice-design prompt history? | Only if dossier-format adds a kind for it; the voice prompt is already `provenance.voicePrompt` on the `vox` asset. Out of scope for 2.1.0. |
