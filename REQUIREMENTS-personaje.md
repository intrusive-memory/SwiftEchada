---
type: requirements
state: draft
updated: 2026-10-22
origin: intrusive-memory/Personaje (DEPENDENCY-MISSIONS.md, docs/REQUIREMENTS*.md)
sequence: 2 — after SwiftReparto 0.2.0; parallel with SwiftDossier
---

# SwiftEchada — what Personaje needs

Voice belongs to SwiftEchada. Personaje edits `voicePrompt` through Reparto,
asks Echada for the `.vox`, and registers the result in the character's
`.dossier` bundle. Three parts: path amendments to EC-23..EC-30 (Part A, now
folded in), removing cast discovery (Part C), and a library an app can link
(Part B).

*Updated 2026-10-21:* SwiftEchada **2.0.0 shipped today** (removed `verify
cast` and `prune cast`; automatic `cast:` migration). The voice requirements
(EC-23..EC-30) are now maintained in `REQUIREMENTS.md` on `development`,
targeting 2.1.0. *2026-10-22:* moved to `development`. 2.1.0 shipped (PR #61,
SwiftLlavero + macOS 27) without them; **3.0.0** carries Parts A–C.

## Part A: amendments to EC-23..EC-30 — done

All four are folded into `REQUIREMENTS.md` on `development` (2026-10-19, 2026-10-21).

| ID | Requirement | Status |
|----|-------------|--------|
| EC-P1 | EC-23 rule 3 writes to `<charactersDir>/<CHARACTER>.dossier/voice/`. | Done: EC-23 rule 3 |
| EC-P2 | `migrate voices` uses the same `.dossier` directory. | Done: EC-26. The `verify cast` half no longer applies, because EC-27 was withdrawn when 2.0.0 removed the command |
| EC-P3 | Echada writes files, never the manifest. SwiftDossier adopts them with `refresh`. Echada does not link SwiftDossier. | Done: EC-23, EC-26, EC-28 |
| EC-P4 | EC-28 reads `voice/samples.yaml` (dossier-format §10). | Done: EC-28 `--all-variants` |

## Part C: cast discovery is removed (decided 2026-10-03)

Echada narrows to voices. Discovery moves to SwiftCompartido (parsing:
`DocumentModelActor.extractAllCharacters()`, shipped in 7.3.0) and to a
**discovery writer in SwiftPersonaje** (decided 2026-10-21, placed
2026-10-22; SwiftPersonaje `REQUIREMENTS.md` §7.1, `personaje
cast-discover`), which writes CAST.md through Reparto.

| ID | Requirement |
|----|-------------|
| EC-P11 | Remove `echada generate cast` and the `cast` stage of the `echada cast` pipeline. **Gate:** the removal ships no earlier than SwiftPersonaje's discovery writer, so there is always a supported way to build a CAST.md from scripts. `GenerateCastCommand.matchKey` is used by `CastRosterVerifier` (automatic migration), so it moves rather than being deleted. Prefer Reparto 0.2.0's canonical match key once it's available. |
| EC-P12 | Remove `CharacterInfo` and `CharacterMerger` from the `SwiftEchada` product (nothing in `EchadaCLICore` uses them; only their own tests and `VoxFileIntegrationTests` do; `CharacterInfo` also collides by name with SwiftCompartido's). **`CharacterProfile` stays, or moves to the Part B library:** `VoiceDesigner.swift:7,19` and `TestVoiceCommand.swift:8,38` use it. |
| EC-P13 | Skills and docs (EC-29) point at `personaje cast-discover` for building the cast from scripts, and at `reparto` for validating and importing it. |
| EC-P14 | Removing a command breaks the CLI. 2.0.0 is already taken, so the release that carries EC-P11 is **3.0.0**. See `REQUIREMENTS.md` EC-Q1. |

**Open (OQ-6): does `generate prompt` stay?** `2d67d79` on `development`
(2026-10-21) added `--llm on-device|pcc` to `generate prompt` and
`generate cast`, choosing Apple Private Cloud Compute on macOS 27+. That
answers the on-device-limits objection for `generate prompt`.
**Recommended: keep `generate prompt`.** It's voice work, inside Echada's
boundary. The same commit also put work into `generate cast`. Confirm that
EC-P11 still stands before that investment grows.

## Part B: a linkable voice builder

Personaje **OQ-1 is decided**: Echada grows a public library target with no
ArgumentParser dependency. At `2d67d79` the `SwiftEchada` product is models
only. The `.vox` builder is `CastVoiceGenerator`, an **internal** `struct` in
`EchadaCLICore` (`CastVoiceGenerator.swift:217`), which links ArgumentParser.
A sandboxed app can't run another app's CLI.

| ID | Requirement |
|----|-------------|
| EC-P5 | A public library target (working name `EchadaVoice`) with no ArgumentParser dependency, which `EchadaCLICore` then calls. It may link MLX, SwiftVoxAlta, vox-format and SwiftReparto. |
| EC-P6 | Build a `.vox` from a `voicePrompt` with **both** embeddings (1.7B and 0.6B) in one call, written to the EC-23 location. |
| EC-P7 | Audition: render candidate voices for a prompt without locking, so the app can play them and lock one. |
| EC-P8 | Render samples in-process to `.m4a` (the library form of EC-28). `VoiceLockManager.generateAudio` returns WAV. The m4a encoder is `AudioFileWriter` in SwiftVoxAlta's `DigaCLICore`. Either it moves to a VoxAlta library target or this target encodes with AVFoundation. |
| EC-P9 | Progress and cancellation: an async API with a progress callback that honors task cancellation, so the app can run it as a job. Models load and unload per call. |
| EC-P10 | Models come from the shared Acervo directory (`group.intrusive-memory.models`). No purchase check in the library. |

## Facts verified at `2d67d79` (`development`, 2.0.0-dev)

- Commands: `cast`, `generate {cast,prompt,vox}`, `voice`, `test-voice`.
  There is no `verify`, `prune`, `sample` or `migrate`.
- Reparto is pinned `upToNextMajor(from: "0.1.0")` (`Package.swift:28-29`),
  so 0.2.0 resolves without a manifest change. SwiftProyecto is pinned
  `from: "5.3.2"`.
- `CastMember.voices` is `[String: [String]]`: `voices.voxalta` is an array.

## Acceptance

Echada's own EC-30 tests, plus:

1. A member with `manifest: characters/SHANE.dossier/manifest.json` gets
   `characters/SHANE.dossier/voice/SHANE.vox`.
2. A member with no pointer gets `characters/<NAME>.dossier/voice/<NAME>.vox`.
3. `manifest.json` is byte-identical before and after any Echada command.
4. A test target with no ArgumentParser in its dependency closure builds a
   two-embedding `.vox` through EC-P6.
5. (Part C) `echada generate cast` is an unknown command, and `echada cast`
   runs without a discovery stage.

## Depends on

- **SwiftReparto 0.2.0** (hard): `role`, `manifest`, `canonicalName`.
- **Personaje's discovery writer** (hard, Part C only; EC-P11 gate).
- SwiftVoxAlta (only if EC-P8 moves the encoder there).

## Blocks

- **podcast-granville** voice migration (`echada migrate voices`).
- **Personaje** Voice and Samples tabs (hard, Part B).

## Open

- OQ-6: keep `generate prompt` (recommended; see Part C).
- The main checkout has uncommitted work on `development`
  (`LanguageModelResolver.swift` new, `LanguageModelChoice.swift` deleted, and
  others). It is not part of these requirements.
