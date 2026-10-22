# Graph Report - .  (2026-10-22)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 922 nodes · 1573 edges · 68 communities (52 shown, 16 thin omitted)
- Extraction: 91% EXTRACTED · 9% INFERRED · 0% AMBIGUOUS · INFERRED: 144 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c84341c5`
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
- [[_COMMUNITY_Community 64|Community 64]]
- [[_COMMUNITY_Community 65|Community 65]]
- [[_COMMUNITY_Community 66|Community 66]]

## God Nodes (most connected - your core abstractions)
1. `PerLanguagePromptTests` - 24 edges
2. `CastVoiceGenerator struct` - 24 edges
3. `ProjectMigration` - 18 edges
4. `castableLanguages()` - 17 edges
5. `GenerateCastCommandTests` - 17 edges
6. `CharacterProfile` - 16 edges
7. `CastCommand` - 15 edges
8. `CharacterProfile` - 15 edges
9. `CLIWiringTests` - 15 edges
10. `decideVoxGeneration()` - 14 edges

## Surprising Connections (you probably didn't know these)
- `Claude-specific rules` --semantically_similar_to--> `Critical Rules (All Agents)`  [INFERRED] [semantically similar]
  CLAUDE.md → AGENTS.md
- `Gemini-specific rules` --semantically_similar_to--> `Claude-specific rules`  [INFERRED] [semantically similar]
  GEMINI.md → CLAUDE.md
- `echada cast command` --references--> `CastVoiceGenerator struct`  [INFERRED]
  README.md → Docs/api.md
- `Docs/vox-pipeline.md` --semantically_similar_to--> `Curated audition sentences replace Foundation Model (reliability/reproducibility/portability)`  [INFERRED] [semantically similar]
  Docs/vox-pipeline.md → CHANGELOG.md
- `Produciesta compatibility (CAST.md-aware build needed)` --conceptually_related_to--> `ProjectMigration`  [INFERRED]
  CHANGELOG.md → Docs/api.md

## Import Cycles
- None detected.

## Communities (68 total, 16 thin omitted)

### Community 0 - "Cast Voice Generation"
Cohesion: 0.06
Nodes (27): CharacterProfile, Codable, TestVoiceCommand, VoiceDesigner, Equatable, Sendable, Qwen3TTSModelRepo, String (+19 more)

### Community 1 - "CLI Command Layer"
Cohesion: 0.06
Nodes (26): AsyncParsableCommand, EchadaCLIEntry, CastCommand, EchadaCLI, GenerateCastCommand, GenerateCommand, GeneratePromptCommand, GenerateVoxCommand (+18 more)

### Community 2 - "Character Types & Voice Design"
Cohesion: 0.08
Nodes (19): FilePattern, ProjectFrontMatter, ProyectoCastMember, CastPipelineTests, CastCommandBootstrapTests, GenerateCastCommandTests, Fixtures, makeIsolatedProject() (+11 more)

### Community 3 - "Project Documentation"
Cohesion: 0.07
Nodes (14): CharacterDialogueEvidence, VoicePromptSynthesizer, VoicePromptSynthesizerError, appleIntelligenceUnavailable, generationFailed, modelUnavailable, Gender, Bool (+6 more)

### Community 4 - "Character Info & Fixtures"
Cohesion: 0.07
Nodes (22): CustomStringConvertible, FoundationModelRetry, ReferenceAudioError, conversionFailed, sayFailed, ReferenceAudioGenerator, VoiceDesignerError, modelCastFailed (+14 more)

### Community 5 - "Screenplay Characters"
Cohesion: 0.18
Nodes (19): CandidateResult, CastVoiceGenerator, CastVoiceGeneratorError, existingVoxUnreadable, unsupportedTTSModel, GenerateResult, logLanguageAudit(), LocalizedError (+11 more)

### Community 6 - "Vox File Integration Tests"
Cohesion: 0.24
Nodes (14): Double, ensureParent(), makeVoxFile(), syntheticClonePrompt(), syntheticWAV(), tempVoxURL(), VoxFileIntegrationTests, VoxPaths (+6 more)

### Community 7 - "Dependencies & Distribution"
Cohesion: 0.16
Nodes (14): CastDivergence, CastRosterVerifier, Kind, danglingVoicePath, fieldMismatch, membership, DependencyVersions, Direct (+6 more)

### Community 8 - "Vox Generation Decisions"
Cohesion: 0.16
Nodes (4): castableLanguages(), localizedVoicePrompt(), PerLanguagePromptTests, String

### Community 9 - "Accent Option Tests"
Cohesion: 0.21
Nodes (11): decideVoxGeneration(), CastVoiceGeneratorDecisionTests, syntheticClonePrompt(), syntheticWAV(), tempVoxURL(), writeVoxOnDisk(), Data, Double (+3 more)

### Community 10 - "Foundation Model Sentence"
Cohesion: 0.19
Nodes (19): AGENTS.md — Project Documentation, API Reference, Architecture (referenced), Build, Test, and Release, CHANGELOG, CLAUDE.md — Claude Rules, Completed Work — SwiftEchada, Dependencies (+11 more)

### Community 11 - "Reference Audio Generation"
Cohesion: 0.16
Nodes (19): CastMember (SwiftReparto), EchadaCLICore, SwiftEchada library, LegacyProjectCastReader, Legacy cast: block (NARRATOR, ESPECTRO FAMILIAR, THE PRACTITIONER), episodes_index appSection, confessions-PROJECT.md fixture, ProjectCastImporter (+11 more)

### Community 12 - "Cover Artwork"
Cohesion: 0.20
Nodes (6): Substring, GenerateVoxWriteBackTests, CastMember, String, URL, Void

### Community 13 - "Cast Command Tests"
Cohesion: 0.12
Nodes (3): ParsableCommand, CLIWiringTests, String

### Community 14 - "App Icon Artwork"
Cohesion: 0.17
Nodes (17): Gender (SwiftReparto), FoundationModelRetry, VoicePromptSynthesizer, FoundationModelRetry, Release 0.16.0 (OPERATION GENERAL MUSTER), Release 2.1.0, SwiftLlavero, echada auth (+9 more)

### Community 15 - "Accent Tower Mission"
Cohesion: 0.13
Nodes (17): CastCommand.resolvedAccent, CastCommand.resolvedLanguages, CastCommand.run, castableLanguages, composeVoicePrompt, decideVoxGeneration, CastVoiceGenerator.generate, CastVoiceGenerator.generateCandidateWithPrompt (+9 more)

### Community 16 - "Per-Language Voice Casting"
Cohesion: 0.18
Nodes (4): CharacterInfo, CastMember, CharacterMerger, CharacterMergerTests

### Community 17 - "CLI Core Extraction"
Cohesion: 0.15
Nodes (3): AuditionSentenceTests, String, TTSLanguage

### Community 18 - "Vox System Integrations"
Cohesion: 0.26
Nodes (16): CastVoiceGenerator struct, ReferenceAudioGenerator enum, VoiceDesigner enum, Two-phase vox pipeline (Phase A VoiceDesign / Phase B Base lock), make integration-test, mlx-audio-swift, Qwen3TTSModel, SwiftVoxAlta (+8 more)

### Community 19 - "Local Settings"
Cohesion: 0.23
Nodes (4): GenerateVoxCommandTests, String, SwiftReparto, URL

### Community 20 - "Outline Fixture"
Cohesion: 0.16
Nodes (15): echada CLI executable, Queryable graphify codemap, SwiftEchada (library + CLI), SwiftVoxAlta dependency, Two-phase voice generation pipeline, echada executable (@main shim), EchadaCLICore, Module dependency graph (+7 more)

### Community 22 - "CharacterProfile Type"
Cohesion: 0.35
Nodes (4): ProjectMigrationTests, String, SwiftReparto, URL

### Community 23 - "BPE Tokenization Note"
Cohesion: 0.35
Nodes (4): CastBodyPreservationTests, String, URL, UInt8

### Community 24 - "Community 24"
Cohesion: 0.19
Nodes (13): Critical Rules (All Agents), Makefile build/test rule, Targeted imports (module/type name collision), SwiftEchada module enum, Module/type name collision (SwiftEchada enum), Homebrew distribution, Makefile targets, mlx-swift_Cmlx.bundle Metal bundle (+5 more)

### Community 25 - "Community 25"
Cohesion: 0.21
Nodes (11): CastMarkdownGenerator, Docs/api.md, Docs/architecture.md, One writer for CAST.md (D8), Single writer for CAST.md decision, Two-phase vox pipeline (VoiceDesign → Base lock), Curated audition sentences replace Foundation Model (reliability/reproducibility/portability), Issues #44/#55 PROJECT.md write-back corruption (+3 more)

### Community 26 - "Community 26"
Cohesion: 0.24
Nodes (12): CharacterInfo struct, CharacterMerger struct, ProjectMigration, CastCommand (echada cast), CastRosterVerifier, DialogueExtractor, GenerateCastCommand, GeneratePromptCommand (+4 more)

### Community 27 - "Community 27"
Cohesion: 0.32
Nodes (6): CharacterDialogueEvidence, Cue, DialogueExtractor, Bool, Int, String

### Community 28 - "Community 28"
Cohesion: 0.36
Nodes (3): GenerateCastSeedingTests, String, URL

### Community 29 - "Community 29"
Cohesion: 0.17
Nodes (12): PROJECT.md / CAST.md Ownership Split, --audition-variant N, ProjectCastWriteBack (removed), Release 1.0.0 (CAST.md extraction), Release 2.0.0, echada verify cast / prune cast (removed), --cast <filename> flag, Migrating older projects (automatic) (+4 more)

### Community 30 - "Community 30"
Cohesion: 0.30
Nodes (6): SourceMaterialLocator, Set, Bool, ProjectFrontMatter, String, URL

### Community 31 - "Community 31"
Cohesion: 0.20
Nodes (11): Non-English .vox neutralize gotcha, SampleSentenceGenerator struct, .vox bundle structure (zip archive), .vox Automator Quick Action, .vox Quick Look plugin, decideVoxGeneration per-language limitation, Per-language embedding path scheme, Optional --language voice casting (+3 more)

### Community 32 - "Community 32"
Cohesion: 0.24
Nodes (11): AuditionSentence, DependencyVersions.swift (generated), TestVoiceCommand, VoiceCommand (echada voice), Build-time dependency version table (echada --version), FoundationModelSentence (replaced), Release 0.17.0, Apple Intelligence unavailable on hosted CI (R-CI-1) (+3 more)

### Community 33 - "Community 33"
Cohesion: 0.20
Nodes (9): Docs/build-and-test.md, Ownership split: PROJECT.md (Proyecto) vs CAST.md (Reparto), ProjectMarkdownParser, ProjectService, SwiftProyecto, Docs/gotchas.md, Module/type name collision (targeted imports), Never use swift build/test (Metal shaders) (+1 more)

### Community 34 - "Community 34"
Cohesion: 0.31
Nodes (5): Range, CastMigrationLosslessnessTests, Int, String, URL

### Community 37 - "Community 37"
Cohesion: 0.31
Nodes (10): castableLanguages pure function, composeVoicePrompt free function, Accent Tower eval matrix, Operation Accent Tower mission, Piece 1 --accent directive, Piece 2 per-language prompt selection, Accent Tower supervisor state, Accent Tower test cleanup report (+2 more)

### Community 39 - "Community 39"
Cohesion: 0.36
Nodes (7): Outcome, ProjectMigration, ProjectMigrationError, charactersMissingAfterTransfer, Bool, String, URL

### Community 40 - "Community 40"
Cohesion: 0.31
Nodes (3): GeneratePromptCommandTests, SwiftReparto, URL

### Community 41 - "Community 41"
Cohesion: 0.44
Nodes (5): AuditionSentence, AuditionSentenceError, unsupportedLanguage, Int, String

### Community 42 - "Community 42"
Cohesion: 0.36
Nodes (8): main(), next_major(), next_minor(), parse_declared(), parse_resolved(), Map lowercased package identity -> resolved version (or short revision)., Extract (repo_name, requirement_description) for each direct dependency.      On, swift_string()

### Community 45 - "Community 45"
Cohesion: 0.33
Nodes (9): CastDocument, CastMarkdownParser, .dossier character bundle (dossier-format), EC-26 echada migrate voices, EC-23 Output location, EC-24 Canonical file names, EC-25 voices.voxalta write-back, EC-28 echada sample (+1 more)

### Community 47 - "Community 47"
Cohesion: 0.29
Nodes (5): LanguageModelResolver, Llavero, Bool, LanguageModel, ModelReference

### Community 48 - "Community 48"
Cohesion: 0.29
Nodes (5): VoiceCommand, Bool, Qwen3TTSModelRepo, String, VoxAltaModelManager

### Community 49 - "Community 49"
Cohesion: 0.32
Nodes (5): LegacyProjectFixture, SwiftReparto.CastMember, String, SwiftReparto, URL

### Community 50 - "Community 50"
Cohesion: 0.33
Nodes (7): Cast pipeline data flow, Qwen3TTSModel, VoiceLockManager.createLock, VoxExporter (addClonePrompt/addSampleAudio), VoxFile mutable container, No IPA/phoneme front-end (BPE only), SwiftVoxAlta v0.13.0 (createLock language)

### Community 52 - "Community 52"
Cohesion: 0.33
Nodes (4): LegacyProjectCastReader, CastMember, String, URL

### Community 53 - "Community 53"
Cohesion: 0.60
Nodes (3): fetch(), prime_one(), acervo-ci-prime.sh script

### Community 55 - "Community 55"
Cohesion: 0.50
Nodes (4): SwiftProyecto dependency, CharacterEvidence struct, CharacterProfile struct, echada cast command

### Community 56 - "Community 56"
Cohesion: 0.50
Nodes (4): Phase B: Voice Locking, VoiceLockManager, .vox Bundle, VoxExporter

### Community 57 - "Community 57"
Cohesion: 0.67
Nodes (4): REQUIREMENTS.md (2.1.0 Voices into Character Record), dossier-format .dossier character bundle, EC-23 .vox output location via manifest pointer, EC-28 echada sample (.m4a voice samples)

### Community 58 - "Community 58"
Cohesion: 0.67
Nodes (3): CastCommand, VoiceCommand, Test Analysis Report

## Ambiguous Edges - Review These
- `CHANGELOG` → `SwiftEchada README`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to
- `Tests Workflow` → `Execution Plan — GENERAL MUSTER`  [AMBIGUOUS]
  Docs/complete/general-muster-01/EXECUTION_PLAN.md · relation: references
- `Transition-window CastMember/Gender ambiguity` → `verify cast / prune cast removed (2.0.0)`  [AMBIGUOUS]
  Docs/gotchas.md · relation: conceptually_related_to
- `Release Binary workflow` → `Homebrew distribution`  [AMBIGUOUS]
  Docs/build-and-test.md · relation: conceptually_related_to

## Knowledge Gaps
- **115 isolated node(s):** `generate-coverage-badge.sh script`, `setup-mlx.sh script`, `Bool`, `existingVoxUnreadable`, `generate` (+110 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `CHANGELOG` and `SwiftEchada README`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Tests Workflow` and `Execution Plan — GENERAL MUSTER`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Transition-window CastMember/Gender ambiguity` and `verify cast / prune cast removed (2.0.0)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Release Binary workflow` and `Homebrew distribution`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `CastVoiceGenerator` connect `Screenplay Characters` to `Community 48`, `CLI Command Layer`, `Accent Tower Mission`?**
  _High betweenness centrality (0.075) - this node is a cross-community bridge._
- **Why does `ProjectFrontMatter` connect `Character Types & Voice Design` to `CLI Command Layer`, `Community 49`, `BPE Tokenization Note`?**
  _High betweenness centrality (0.055) - this node is a cross-community bridge._
- **Why does `CharacterProfile` connect `Cast Voice Generation` to `Project Documentation`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._