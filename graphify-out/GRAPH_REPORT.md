# Graph Report - .  (2026-11-05)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 1363 nodes · 2637 edges · 73 communities (57 shown, 16 thin omitted)
- Extraction: 92% EXTRACTED · 7% INFERRED · 0% AMBIGUOUS · INFERRED: 194 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `56b389f4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- [[_COMMUNITY_Cast Voice Generation|Cast Voice Generation]]
- [[_COMMUNITY_CLI Command Layer|CLI Command Layer]]
- [[_COMMUNITY_Character Types & Voice Design|Character Types & Voice Design]]
- [[_COMMUNITY_Project Documentation|Project Documentation]]
- [[_COMMUNITY_Character Info & Fixtures|Character Info & Fixtures]]
- [[_COMMUNITY_Screenplay Characters|Screenplay Characters]]
- [[_COMMUNITY_Vox File Integration Tests|Vox File Integration Tests]]
- [[_COMMUNITY_Dependencies & Distribution|Dependencies & Distribution]]
- [[_COMMUNITY_Vox Generation Decisions|Vox Generation Decisions]]
- [[_COMMUNITY_Accent Option Tests|Accent Option Tests]]
- [[_COMMUNITY_Foundation Model Sentence|Foundation Model Sentence]]
- [[_COMMUNITY_Reference Audio Generation|Reference Audio Generation]]
- [[_COMMUNITY_Cover Artwork|Cover Artwork]]
- [[_COMMUNITY_Cast Command Tests|Cast Command Tests]]
- [[_COMMUNITY_App Icon Artwork|App Icon Artwork]]
- [[_COMMUNITY_Accent Tower Mission|Accent Tower Mission]]
- [[_COMMUNITY_Per-Language Voice Casting|Per-Language Voice Casting]]
- [[_COMMUNITY_CLI Core Extraction|CLI Core Extraction]]
- [[_COMMUNITY_Vox System Integrations|Vox System Integrations]]
- [[_COMMUNITY_Local Settings|Local Settings]]
- [[_COMMUNITY_Outline Fixture|Outline Fixture]]
- [[_COMMUNITY_Package Manifest|Package Manifest]]
- [[_COMMUNITY_CharacterProfile Type|CharacterProfile Type]]
- [[_COMMUNITY_BPE Tokenization Note|BPE Tokenization Note]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]
- [[_COMMUNITY_Community 52|Community 52]]
- [[_COMMUNITY_Community 53|Community 53]]
- [[_COMMUNITY_Community 54|Community 54]]
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]
- [[_COMMUNITY_Community 58|Community 58]]
- [[_COMMUNITY_Community 59|Community 59]]
- [[_COMMUNITY_Community 60|Community 60]]
- [[_COMMUNITY_Community 61|Community 61]]
- [[_COMMUNITY_Community 62|Community 62]]
- [[_COMMUNITY_Community 63|Community 63]]
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 66|Community 66]]
- [[_COMMUNITY_Community 67|Community 67]]
- [[_COMMUNITY_Community 68|Community 68]]
- [[_COMMUNITY_Community 69|Community 69]]
- [[_COMMUNITY_Community 71|Community 71]]
- [[_COMMUNITY_Community 72|Community 72]]

## God Nodes (most connected - your core abstractions)
1. `FakeElevenLabsBackend` - 34 edges
2. `CastVoiceGenerator struct` - 29 edges
3. `VoiceBuilder` - 22 edges
4. `PerLanguagePromptTests` - 21 edges
5. `VoxFile` - 21 edges
6. `VoicesDesignError` - 20 edges
7. `VoicesDesignTests` - 20 edges
8. `CharacterProfile` - 19 edges
9. `ProjectMigration` - 18 edges
10. `VoicesDesignRunner` - 18 edges

## Surprising Connections (you probably didn't know these)
- `Docs/vox-pipeline.md` --semantically_similar_to--> `Curated audition sentences replace Foundation Model (reliability/reproducibility/portability)`  [INFERRED] [semantically similar]
  Docs/vox-pipeline.md → CHANGELOG.md
- `API Reference` --references--> `SwiftLlavero (--llm, echada auth)`  [AMBIGUOUS]
  Docs/api.md → AGENTS.md
- `Claude-specific rules` --semantically_similar_to--> `Critical Rules (All Agents)`  [INFERRED] [semantically similar]
  CLAUDE.md → AGENTS.md
- `Gemini-specific rules` --semantically_similar_to--> `Claude-specific rules`  [INFERRED] [semantically similar]
  GEMINI.md → CLAUDE.md
- `API Reference` --references--> `SwiftLlavero (--llm, echada auth)`  [AMBIGUOUS]
  Docs/api.md → AGENTS.md

## Import Cycles
- None detected.

## Communities (73 total, 16 thin omitted)

### Community 0 - "Cast Voice Generation"
Cohesion: 0.05
Nodes (26): FilePattern, ProjectFrontMatter, CastBodyPreservationTests, CastCommandBootstrapTests, CastFileTests, CastPipelineTests, LegacyProjectFixture, SwiftReparto.CastMember (+18 more)

### Community 1 - "CLI Command Layer"
Cohesion: 0.06
Nodes (24): CharacterProfile, Codable, TestVoiceCommand, QwenVoiceDesigner, VoiceDesigner, Qwen3TTSModelRepo, String, Bool (+16 more)

### Community 2 - "Character Types & Voice Design"
Cohesion: 0.05
Nodes (27): AsyncParsableCommand, EchadaCLIEntry, CastCommand, EchadaCLI, GenerateCommand, GenerateVoxCommand, MigrateCommand, MigrateVoicesCommand (+19 more)

### Community 3 - "Project Documentation"
Cohesion: 0.08
Nodes (42): Outcome, ProjectMigration, ProjectMigrationError, charactersMissingAfterTransfer, Blocker, MigrationError, blocked, checksumMismatch (+34 more)

### Community 4 - "Character Info & Fixtures"
Cohesion: 0.08
Nodes (39): CodingKey, CodingKeys, character, designModel, generatedVoiceId, previewFile, promptSent, sampleText (+31 more)

### Community 5 - "Screenplay Characters"
Cohesion: 0.11
Nodes (18): ElevenLabsBackend, FakeDesigner, FakeElevenLabsBackend, VoicesDesignTests, Bool, CastMember, Data, Int (+10 more)

### Community 6 - "Vox File Integration Tests"
Cohesion: 0.09
Nodes (33): CaseIterable, VoiceAudition, VoiceBuilder, VoiceBuilderError, encodingFailed, modelMissing, noVoicePrompt, noVox (+25 more)

### Community 7 - "Dependencies & Distribution"
Cohesion: 0.06
Nodes (18): CharacterDialogueEvidence, GeneratePromptCommand, VoicePromptSynthesizer, VoicePromptSynthesizerError, appleIntelligenceUnavailable, generationFailed, modelUnavailable, Gender (+10 more)

### Community 8 - "Vox Generation Decisions"
Cohesion: 0.08
Nodes (38): CastMarkdownParser, CastMember (SwiftReparto), CharacterInfo struct, CharacterMerger struct, ProjectMigration, CastCommand (echada cast), CastRosterVerifier, GenerateCastCommand (+30 more)

### Community 9 - "Accent Option Tests"
Cohesion: 0.07
Nodes (24): CustomStringConvertible, FoundationModelRetry, ReferenceAudioError, conversionFailed, sayFailed, ReferenceAudioGenerator, VoiceDesignerError, modelCastFailed (+16 more)

### Community 10 - "Foundation Model Sentence"
Cohesion: 0.11
Nodes (26): ElevenLabsSampleBackend, ElevenLabsSampleResult, ElevenLabsSampleRunner, ElevenLabsVoice, LiveElevenLabsSampleBackend, SampleElevenLabsError, emptyVoiceId, noDesignPreview (+18 more)

### Community 11 - "Reference Audio Generation"
Cohesion: 0.09
Nodes (26): Queryable graphify codemap, Makefile build/test, API Reference, Docs/api.md, SwiftEchada library, Architecture Doc, Docs/architecture.md, Two-phase vox pipeline avoids GPU OOM (+18 more)

### Community 12 - "Cover Artwork"
Cohesion: 0.18
Nodes (21): CastVoiceGenerator struct, EchadaCLICore, ReferenceAudioGenerator enum, VoiceDesigner enum, Two-phase vox pipeline (Phase A VoiceDesign / Phase B Base lock), make integration-test, mlx-audio-swift, Qwen3TTSModel (+13 more)

### Community 13 - "Cast Command Tests"
Cohesion: 0.16
Nodes (11): ElevenLabsSampleRunner, FakeSampleBackend, SampleElevenLabsTests, Bool, Data, Double, Int, SpeechRequest (+3 more)

### Community 14 - "App Icon Artwork"
Cohesion: 0.10
Nodes (25): CharacterProfile, Critical Rules (All Agents), echada CLI executable, Makefile build/test rule, SwiftEchada (library + CLI), Targeted imports (module/type name collision), CharacterEvidence struct, CharacterProfile struct (+17 more)

### Community 15 - "Accent Tower Mission"
Cohesion: 0.09
Nodes (28): castableLanguages pure function, composeVoicePrompt free function, Accent Tower eval matrix, Non-English .vox neutralize gotcha, Operation Accent Tower mission, Piece 1 --accent directive, Piece 2 per-language prompt selection, Accent Tower supervisor state (+20 more)

### Community 16 - "Per-Language Voice Casting"
Cohesion: 0.18
Nodes (19): Double, syntheticClonePrompt(), syntheticWAV(), ensureParent(), makeVoxFile(), syntheticClonePrompt(), syntheticWAV(), tempVoxURL() (+11 more)

### Community 17 - "CLI Core Extraction"
Cohesion: 0.10
Nodes (37): echada cast, CAST.md Cast Roster, CastDocument, CastMember, Character record (characters/<NAME>.dossier/voice/), EchadaCLICore / echada CLI, EchadaVoice Library, ElevenLabs provider (+29 more)

### Community 18 - "Vox System Integrations"
Cohesion: 0.12
Nodes (24): VoiceLocation, PersonajeSettings (charactersDir), VoiceMigration, Yams, echada migrate voices, cast-voices skill, REQUIREMENTS.md (2.1.0 Voices into Character Record), .dossier character bundle (dossier-format) (+16 more)

### Community 19 - "Local Settings"
Cohesion: 0.19
Nodes (9): SyntheticVox, VoiceMigrationTests, VoiceSampleTests, CastMember, Data, Int, String, URL (+1 more)

### Community 20 - "Outline Fixture"
Cohesion: 0.17
Nodes (12): Decodable, Envelope, PersonajeSettings, Job, SampleCommand, SampleSpec, String, URL (+4 more)

### Community 21 - "Package Manifest"
Cohesion: 0.14
Nodes (4): castableLanguages(), localizedVoicePrompt(), PerLanguagePromptTests, String

### Community 22 - "CharacterProfile Type"
Cohesion: 0.13
Nodes (21): CastDocument, CastMarkdownGenerator, DependencyVersions.swift (generated), One writer for CAST.md (D8), Single writer for CAST.md decision, One writer for CAST.md (prevents #44/#55 data loss), Issues #44/#55 PROJECT.md write-back corruption, Legacy cast: block (NARRATOR, ESPECTRO FAMILIAR, THE PRACTITIONER) (+13 more)

### Community 23 - "BPE Tokenization Note"
Cohesion: 0.16
Nodes (14): CastDivergence, CastRosterVerifier, Kind, danglingVoicePath, fieldMismatch, membership, DependencyVersions, Direct (+6 more)

### Community 24 - "Community 24"
Cohesion: 0.22
Nodes (16): CandidateResult, CastVoiceGenerator, CastVoiceGeneratorError, existingVoxUnreadable, unsupportedTTSModel, GenerateResult, logLanguageAudit(), Bool (+8 more)

### Community 25 - "Community 25"
Cohesion: 0.14
Nodes (10): APIKeyStoring, ElevenLabsBackend, LiveElevenLabsBackend, VoiceSlots, Data, ElevenLabsPlugin, Int, String (+2 more)

### Community 26 - "Community 26"
Cohesion: 0.11
Nodes (3): ParsableCommand, CLIWiringTests, String

### Community 27 - "Community 27"
Cohesion: 0.19
Nodes (19): AGENTS.md — Project Documentation, API Reference, Architecture (referenced), Build, Test, and Release, CHANGELOG, CLAUDE.md — Claude Rules, Completed Work — SwiftEchada, Dependencies (+11 more)

### Community 28 - "Community 28"
Cohesion: 0.20
Nodes (6): Substring, GenerateVoxWriteBackTests, CastMember, String, URL, Void

### Community 29 - "Community 29"
Cohesion: 0.16
Nodes (18): CastVoiceGenerator, AuditionSentence, TestVoiceCommand, VoiceCommand (echada voice), Build, Test, and Release Doc, AuditionSentence, Curated audition sentences replace Foundation Model (reliability/reproducibility/portability), Build-time dependency version table (echada --version) (+10 more)

### Community 30 - "Community 30"
Cohesion: 0.13
Nodes (5): CastCommand.resolvedAccent, CastCommand.resolvedLanguages, CastCommand.run, composeVoicePrompt(), AccentOptionTests

### Community 31 - "Community 31"
Cohesion: 0.20
Nodes (5): GenerateVoxCommandTests, Bool, String, SwiftReparto, URL

### Community 32 - "Community 32"
Cohesion: 0.15
Nodes (3): AuditionSentenceTests, String, TTSLanguage

### Community 33 - "Community 33"
Cohesion: 0.26
Nodes (13): echada auth, SwiftLlavero (--llm, echada auth), DialogueExtractor, FoundationModelRetry, GeneratePromptCommand, VoicePromptSynthesizer, FoundationModelRetry, Release 2.1.0 (+5 more)

### Community 34 - "Community 34"
Cohesion: 0.17
Nodes (13): VoicesAssignError, castNotFound, emptyVoiceId, unknownCharacter, unsupportedProvider, voiceNotFound, VoicesAssignRunner, Bool (+5 more)

### Community 35 - "Community 35"
Cohesion: 0.33
Nodes (7): decideVoxGeneration(), CastVoiceGeneratorDecisionTests, tempVoxURL(), writeVoxOnDisk(), String, URL, VoxFile

### Community 36 - "Community 36"
Cohesion: 0.29
Nodes (7): FakeElevenLabsBackend, VoicesAssignTests, Bool, CastMember, String, URL, VoicesAssignRunner

### Community 37 - "Community 37"
Cohesion: 0.34
Nodes (4): ProjectMigrationTests, String, SwiftReparto, URL

### Community 38 - "Community 38"
Cohesion: 0.20
Nodes (3): VoiceLocationTests, String, URL

### Community 39 - "Community 39"
Cohesion: 0.32
Nodes (6): CharacterDialogueEvidence, Cue, DialogueExtractor, Bool, Int, String

### Community 40 - "Community 40"
Cohesion: 0.30
Nodes (6): SourceMaterialLocator, Set, Bool, ProjectFrontMatter, String, URL

### Community 41 - "Community 41"
Cohesion: 0.36
Nodes (3): MigrationSeedingTests, String, URL

### Community 42 - "Community 42"
Cohesion: 0.31
Nodes (5): Range, CastMigrationLosslessnessTests, Int, String, URL

### Community 45 - "Community 45"
Cohesion: 0.31
Nodes (3): GeneratePromptCommandTests, SwiftReparto, URL

### Community 47 - "Community 47"
Cohesion: 0.44
Nodes (5): AuditionSentence, AuditionSentenceError, unsupportedLanguage, Int, String

### Community 48 - "Community 48"
Cohesion: 0.36
Nodes (8): main(), next_major(), next_minor(), parse_declared(), parse_resolved(), Map lowercased package identity -> resolved version (or short revision)., Extract (repo_name, requirement_description) for each direct dependency.      On, swift_string()

### Community 50 - "Community 50"
Cohesion: 0.29
Nodes (5): LanguageModelResolver, Llavero, Bool, LanguageModel, ModelReference

### Community 52 - "Community 52"
Cohesion: 0.33
Nodes (4): VoiceCommand, Bool, Qwen3TTSModelRepo, String

### Community 54 - "Community 54"
Cohesion: 0.40
Nodes (3): CastFile, String, URL

### Community 55 - "Community 55"
Cohesion: 0.33
Nodes (4): LegacyProjectCastReader, CastMember, String, URL

### Community 56 - "Community 56"
Cohesion: 0.60
Nodes (3): fetch(), prime_one(), acervo-ci-prime.sh script

### Community 58 - "Community 58"
Cohesion: 0.50
Nodes (4): Phase B: Voice Locking, VoiceLockManager, .vox Bundle, VoxExporter

### Community 59 - "Community 59"
Cohesion: 0.50
Nodes (4): VoxGenerationDecision, generate, skipExistingHasVariant, skipExistingUnreadable

### Community 60 - "Community 60"
Cohesion: 0.67
Nodes (3): CastCommand, VoiceCommand, Test Analysis Report

### Community 72 - "Community 72"
Cohesion: 0.28
Nodes (9): VoiceBuilder, SampleCommand, echada sample, EC-28 echada sample playable m4a, Part B: Linkable Voice Builder EC-P5..EC-P10, Phase B: Voice Locking (Base model), VoiceLockManager, VoxExporter (+1 more)

## Ambiguous Edges - Review These
- `CHANGELOG` → `SwiftEchada README`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to
- `Tests Workflow` → `Execution Plan — GENERAL MUSTER`  [AMBIGUOUS]
  Docs/complete/general-muster-01/EXECUTION_PLAN.md · relation: references
- `API Reference` → `SwiftLlavero (--llm, echada auth)`  [AMBIGUOUS]
  Docs/api.md · relation: references
- `API Reference` → `Dependencies Doc`  [AMBIGUOUS]
  Docs/dependencies.md · relation: semantically_similar_to
- `Transition-window CastMember/Gender ambiguity` → `Release 2.0.0`  [AMBIGUOUS]
  Docs/gotchas.md · relation: conceptually_related_to
- `Transition-window CastMember/Gender ambiguity` → `verify cast / prune cast removed (2.0.0)`  [AMBIGUOUS]
  Docs/gotchas.md · relation: conceptually_related_to
- `Release Binary workflow` → `Homebrew distribution`  [AMBIGUOUS]
  Docs/build-and-test.md · relation: conceptually_related_to
- `Dependencies Doc` → `API Reference`  [AMBIGUOUS]
  Docs/dependencies.md · relation: semantically_similar_to
- `SwiftLlavero (--llm, echada auth)` → `API Reference`  [AMBIGUOUS]
  Docs/api.md · relation: references

## Knowledge Gaps
- **184 isolated node(s):** `generate-coverage-badge.sh script`, `setup-mlx.sh script`, `URL`, `Data`, `String` (+179 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `CHANGELOG` and `SwiftEchada README`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Tests Workflow` and `Execution Plan — GENERAL MUSTER`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `API Reference` and `SwiftLlavero (--llm, echada auth)`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `API Reference` and `Dependencies Doc`?**
  _Edge tagged AMBIGUOUS (relation: semantically_similar_to) - confidence is low._
- **What is the exact relationship between `Transition-window CastMember/Gender ambiguity` and `Release 2.0.0`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Transition-window CastMember/Gender ambiguity` and `verify cast / prune cast removed (2.0.0)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Release Binary workflow` and `Homebrew distribution`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._