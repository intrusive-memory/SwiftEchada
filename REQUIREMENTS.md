---
type: requirements
state: draft
created: 2026-09-25
updated: 2026-10-19
target_version: 1.1.0
controlling_doc: dossier-format docs/DOSSIER-FORMAT.md (https://github.com/intrusive-memory/dossier-format)
depends_on: SwiftReparto 0.2.0 (../SwiftReparto/REQUIREMENTS.md)
---

# SwiftEchada 1.1.0 — Voices Move Into the Character Record

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
| EC-27 | `echada verify cast` learns about the character directory |
| EC-28 | `echada sample` exports playable `.m4a` voice samples |
| EC-29 | Skills and docs updated |
| EC-30 | Tests |

---

## 2. Requirements

### EC-23 — Output location

When `CastVoiceGenerator` writes a `.vox`, it picks the location by the first
rule that applies. The folder is currently hard-coded at
`CastVoiceGenerator.swift:297-298`.

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
  `CastVoiceGenerator.swift:325-327`.
- If `canonicalName` throws (the name contains `/` or `:`, or starts with
  `.`), that member fails with an error naming the character and telling the
  user to rename it in the screenplay. Other members keep generating.
- If a member's `character` isn't canonical yet (mixed case, say), generation
  **fails for that member** and points to `reparto canonicalize`. SwiftEchada
  never writes a file whose name differs from what CAST.md says.

### EC-25 — `voices.voxalta` write-back

- The paths written back (`CastVoiceGenerator.swift:344-349` and `:528-532`)
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
  name isn't canonical (in which case it runs `reparto canonicalize` first).
- It never touches `manifest.json`. The next manifest refresh classifies the
  moved files.

### EC-27 — `echada verify cast`

`VerifyCastCommand.swift:90-148` gains:

- **Field comparison** now includes `role` and `manifest`, which Reparto 0.2.0
  declares.
- **Paths with spaces** resolve correctly, CAST-relative. (Test explicitly;
  today's fixtures are all single-word names.)
- **A manifest/name mismatch** (Reparto `manifestNameMismatch`) is an error,
  exit 1.
- **An unmigrated voice**, meaning a member with `manifest:` whose `.vox` is
  outside `<manifest dir>/voice/`, is a warning: "run `echada migrate
  voices`". Exit 0.
- **A legacy `voices/` folder** that still contains `.vox` files after
  migration is a warning.

It remains read-only (`:306-333`).

### EC-28 — `echada sample`: playable voice samples

A browser can't play a `.vox`, and the character dossier has to play the
voice. SwiftEchada already stores sample audio inside the `.vox` bundle
(`VoxExporter.addSampleAudio`, `CastVoiceGenerator.swift:519`), but never
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
  - `generate-cast-voices.sh:5, 107, 110, 123, 127, 131, 139`. This is
    **logic**: it globs `"$PROJECT_DIR"/voices/*.vox` for strays and must
    find `.vox` files via CAST.md pointers instead.
  - `SKILL.md:12, 21, 72, 79, 146, 193`
  - `smoke.sh:39`
- **`~/.claude/skills/podcast-audio-plan/SKILL.md:167, 212`**
- **`~/.claude/skills/generate-episode-audio/SKILL.md:244, 260-261, 395, 412`**
- **SwiftEchada:** `GenerateVoxCommand.swift:23-24` (help text) and
  `:203-212` (the EC-16 comment), plus `README.md`, `AGENTS.md`, `API.md`
  and `CHANGELOG.md`.
- **Produciesta** needs **no source change**, because it resolves pointers
  relative to the file (`VoiceReference.parse(_, relativeTo:)`). Add one
  fixture that has a path with spaces.

### EC-30 — Tests

- **Update** the tests that hard-code `voices/X.vox` output from the
  generator:
  - `GenerateVoxWriteBackTests.swift:35, 82, 137, 157`
  - `VoicePromptRoundTripTests.swift:25, 53, 78`
  - `ModelBackedGenerationTests.swift:195, 211, 256-257`
- **Keep** the tests that *read* legacy underscore pointers, because they
  test reading old data:
  - `LegacyProjectCastReaderTests.swift:50-51`
  - `GenerateCastSeedingTests.swift:108-109`
  - `CastMigrationLosslessnessTests.swift:57, 115`

  `VerifyCastCommandTests` and `PruneCastCommandTests` fixtures stay valid
  as legacy layouts. Add character-directory variants.
- **New tests:**
  - All three EC-23 rules
  - A multi-word, punctuated name (`DR. O'NEILL`) end to end
  - A name that's invalid under canonicalization
  - Refusing to write when a folder differs only by case
  - The `migrate voices` dry run, `--apply`, and rollback on an injected
    failure
  - A skipped `common-voices` path
  - The EC-27 checks
  - `echada sample` exporting the neutral sample (not model-backed)
  - Variant synthesis, model-backed and local-only per suite convention

---

## 3. Rollout

1. **SwiftReparto 0.2.0** ships `role`, `manifest` and `canonicalName`.
2. **SwiftEchada 1.1.0** ships EC-23 to EC-30.
3. **Pilot on `podcasts/granville`**, which already has a `CAST.md`:
   `reparto canonicalize`, then `echada migrate voices`, `--apply`, and
   `echada verify cast`. Then regenerate one episode and compare its audio.
4. **The remaining CAST.md projects:** `palm-oasis`, `granville-sample`.
5. **Projects still on a PROJECT.md `cast:` block** (`confessions`,
   `the-tempest`, `meditations`, …) run `proyecto migrate` first, then step 3.

---

## 4. Open questions

| # | Question | Recommendation |
|---|----------|----------------|
| EC-Q1 | Is this 1.1.0 or 2.0.0? The default output location changes for **new** characters. | **1.1.0.** Existing pointers are respected (EC-23 rule 2), so no existing project changes until someone runs `migrate voices`. The only script that relies on the old location is our own skill, which is updated in the same release. Choose 2.0.0 instead if you count a changed default path as breaking for the CLI. |
| EC-Q2 | Should SwiftEchada link SwiftDossier's `Dossier` and register `.vox` and samples in the manifest directly? | Not in 1.1.0: refresh picks up the files. Revisit once SwiftDossier ships (Foundation + Reparto, no image stack). It removes the refresh step; `voices.voxalta` stays, as the which-voice-to-play authority (dossier-format D5). |
| EC-Q3 | Should `voice/` also hold the reference audio and the voice-design prompt history? | Only if dossier-format adds a kind for it; the voice prompt is already `provenance.voicePrompt` on the `vox` asset. Out of scope for 1.1.0. |
