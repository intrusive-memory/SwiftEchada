# Graph Report - .  (2026-10-21)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 843 nodes · 1411 edges · 59 communities (45 shown, 14 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 138 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `68942b0c`
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
- [[_COMMUNITY_Community 55|Community 55]]
- [[_COMMUNITY_Community 56|Community 56]]
- [[_COMMUNITY_Community 57|Community 57]]

## God Nodes (most connected - your core abstractions)
1. `PerLanguagePromptTests` - 24 edges
2. `castableLanguages()` - 17 edges
3. `CastVoiceGenerator struct` - 16 edges
4. `CharacterProfile` - 16 edges
5. `GenerateCastCommandTests` - 16 edges
6. `CharacterProfile` - 15 edges
7. `CLIWiringTests` - 15 edges
8. `CastCommand` - 14 edges
9. `decideVoxGeneration()` - 14 edges
10. `AuditionSentenceTests` - 14 edges

## Surprising Connections (you probably didn't know these)
- `Gemini-specific rules` --semantically_similar_to--> `Claude-specific rules`  [INFERRED] [semantically similar]
  GEMINI.md → CLAUDE.md
- `Docs/vox-pipeline.md` --semantically_similar_to--> `Curated audition sentences replace Foundation Model (reliability/reproducibility/portability)`  [INFERRED] [semantically similar]
  Docs/vox-pipeline.md → CHANGELOG.md
- `Produciesta compatibility (CAST.md-aware build needed)` --conceptually_related_to--> `ProjectMigration`  [INFERRED]
  CHANGELOG.md → Docs/api.md
- `Transition-window CastMember/Gender ambiguity` --conceptually_related_to--> `verify cast / prune cast removed (2.0.0)`  [AMBIGUOUS]
  Docs/gotchas.md → CHANGELOG.md
- `AccentOptionTests` --references--> `CastCommand.resolvedAccent`  [EXTRACTED]
  Tests/SwiftEchadaTests/AccentOptionTests.swift → Sources/EchadaCLICore/CastCommand.swift

## Import Cycles
- None detected.

## Communities (59 total, 14 thin omitted)

### Community 0 - "Cast Voice Generation"
Cohesion: 0.07
Nodes (32): CharacterProfile, Codable, CastDivergence, CastRosterVerifier, Kind, danglingVoicePath, fieldMismatch, membership (+24 more)

### Community 1 - "CLI Command Layer"
Cohesion: 0.07
Nodes (28): CandidateResult, castingLanguages(), CastVoiceGenerator, CastVoiceGeneratorError, existingVoxUnreadable, unsupportedTTSModel, GenerateResult, logLanguageAudit() (+20 more)

### Community 2 - "Character Types & Voice Design"
Cohesion: 0.06
Nodes (24): AsyncParsableCommand, EchadaCLIEntry, CastCommand, EchadaCLI, GenerateCastCommand, GenerateCommand, GeneratePromptCommand, GenerateVoxCommand (+16 more)

### Community 3 - "Project Documentation"
Cohesion: 0.08
Nodes (19): FilePattern, ProjectFrontMatter, ProyectoCastMember, CastPipelineTests, CastCommandBootstrapTests, GenerateCastCommandTests, Fixtures, makeIsolatedProject() (+11 more)

### Community 4 - "Character Info & Fixtures"
Cohesion: 0.08
Nodes (10): CharacterDialogueEvidence, VoicePromptSynthesizer, VoicePromptSynthesizerError, appleIntelligenceUnavailable, generationFailed, Bool, Gender, String (+2 more)

### Community 5 - "Screenplay Characters"
Cohesion: 0.10
Nodes (26): castableLanguages pure function, composeVoicePrompt free function, Accent Tower eval matrix, Non-English .vox neutralize gotcha, Operation Accent Tower mission, Piece 1 --accent directive, Piece 2 per-language prompt selection, Accent Tower supervisor state (+18 more)

### Community 6 - "Vox File Integration Tests"
Cohesion: 0.13
Nodes (19): CustomStringConvertible, ReferenceAudioError, conversionFailed, sayFailed, ReferenceAudioGenerator, VoiceDesigner, VoiceDesignerError, modelCastFailed (+11 more)

### Community 7 - "Dependencies & Distribution"
Cohesion: 0.24
Nodes (14): Double, ensureParent(), makeVoxFile(), syntheticClonePrompt(), syntheticWAV(), tempVoxURL(), VoxFileIntegrationTests, VoxPaths (+6 more)

### Community 8 - "Vox Generation Decisions"
Cohesion: 0.16
Nodes (4): castableLanguages(), localizedVoicePrompt(), PerLanguagePromptTests, String

### Community 9 - "Accent Option Tests"
Cohesion: 0.19
Nodes (12): decideVoxGeneration(), VoxFile, CastVoiceGeneratorDecisionTests, syntheticClonePrompt(), syntheticWAV(), tempVoxURL(), writeVoxOnDisk(), Data (+4 more)

### Community 10 - "Foundation Model Sentence"
Cohesion: 0.12
Nodes (9): FoundationModelRetry, Error, Int, String, Void, FoundationModelRetryTests, StubError, Int (+1 more)

### Community 11 - "Reference Audio Generation"
Cohesion: 0.12
Nodes (19): echada CLI executable, Queryable graphify codemap, Makefile build/test rule, SwiftEchada (library + CLI), SwiftVoxAlta dependency, Targeted imports (module/type name collision), Two-phase voice generation pipeline, SwiftEchada module enum (+11 more)

### Community 12 - "Cover Artwork"
Cohesion: 0.19
Nodes (19): AGENTS.md — Project Documentation, API Reference, Architecture (referenced), Build, Test, and Release, CHANGELOG, CLAUDE.md — Claude Rules, Completed Work — SwiftEchada, Dependencies (+11 more)

### Community 13 - "Cast Command Tests"
Cohesion: 0.20
Nodes (6): Substring, GenerateVoxWriteBackTests, CastMember, String, URL, Void

### Community 14 - "App Icon Artwork"
Cohesion: 0.18
Nodes (18): CastMember (SwiftReparto), CharacterInfo struct, CharacterMerger struct, EchadaCLICore, SwiftEchada library, LegacyProjectCastReader, Legacy cast: block (NARRATOR, ESPECTRO FAMILIAR, THE PRACTITIONER), episodes_index appSection (+10 more)

### Community 15 - "Accent Tower Mission"
Cohesion: 0.12
Nodes (3): ParsableCommand, CLIWiringTests, String

### Community 16 - "Per-Language Voice Casting"
Cohesion: 0.18
Nodes (4): CharacterInfo, CastMember, CharacterMerger, CharacterMergerTests

### Community 17 - "CLI Core Extraction"
Cohesion: 0.15
Nodes (3): AuditionSentenceTests, String, TTSLanguage

### Community 18 - "Vox System Integrations"
Cohesion: 0.15
Nodes (14): CastMarkdownGenerator, Docs/api.md, AuditionSentence, Docs/architecture.md, One writer for CAST.md (D8), TestVoiceCommand, Two-phase vox pipeline (VoiceDesign → Base lock), VoiceCommand (echada voice) (+6 more)

### Community 19 - "Local Settings"
Cohesion: 0.23
Nodes (4): GenerateVoxCommandTests, String, SwiftReparto, URL

### Community 21 - "Package Manifest"
Cohesion: 0.35
Nodes (4): ProjectMigrationTests, String, SwiftReparto, URL

### Community 22 - "CharacterProfile Type"
Cohesion: 0.35
Nodes (4): CastBodyPreservationTests, String, URL, UInt8

### Community 23 - "BPE Tokenization Note"
Cohesion: 0.32
Nodes (6): CharacterDialogueEvidence, Cue, DialogueExtractor, Bool, Int, String

### Community 24 - "Community 24"
Cohesion: 0.36
Nodes (3): GenerateCastSeedingTests, String, URL

### Community 25 - "Community 25"
Cohesion: 0.17
Nodes (12): CharacterEvidence struct, CharacterProfile struct, Gender (SwiftReparto), ReferenceAudioGenerator enum, SampleSentenceGenerator struct, VoiceDesigner enum, FoundationModelRetry, VoicePromptSynthesizer (+4 more)

### Community 26 - "Community 26"
Cohesion: 0.20
Nodes (12): CastCommand.resolvedAccent, CastCommand.resolvedLanguages, CastCommand.run, castableLanguages, composeVoicePrompt, CastVoiceGenerator.generate, CastVoiceGenerator.generateCandidateWithPrompt, localizedVoicePrompt (+4 more)

### Community 27 - "Community 27"
Cohesion: 0.30
Nodes (6): SourceMaterialLocator, Set, Bool, ProjectFrontMatter, String, URL

### Community 29 - "Community 29"
Cohesion: 0.25
Nodes (11): SwiftProyecto dependency, CastVoiceGenerator struct, mlx-audio-swift, Qwen3TTSModel, SwiftVoxAlta, VoiceLockManager, vox-format, VoxExporter (+3 more)

### Community 30 - "Community 30"
Cohesion: 0.31
Nodes (5): Range, CastMigrationLosslessnessTests, Int, String, URL

### Community 33 - "Community 33"
Cohesion: 0.29
Nodes (10): CastMarkdownParser, ProjectMigration, CastCommand (echada cast), CastRosterVerifier, DialogueExtractor, GenerateCastCommand, GeneratePromptCommand, GenerateVoxCommand (+2 more)

### Community 34 - "Community 34"
Cohesion: 0.36
Nodes (7): Outcome, ProjectMigration, ProjectMigrationError, charactersMissingAfterTransfer, Bool, String, URL

### Community 35 - "Community 35"
Cohesion: 0.31
Nodes (3): GeneratePromptCommandTests, SwiftReparto, URL

### Community 36 - "Community 36"
Cohesion: 0.44
Nodes (5): AuditionSentence, AuditionSentenceError, unsupportedLanguage, Int, String

### Community 37 - "Community 37"
Cohesion: 0.36
Nodes (8): main(), next_major(), next_minor(), parse_declared(), parse_resolved(), Map lowercased package identity -> resolved version (or short revision)., Extract (repo_name, requirement_description) for each direct dependency.      On, swift_string()

### Community 39 - "Community 39"
Cohesion: 0.32
Nodes (5): LegacyProjectFixture, SwiftReparto.CastMember, String, SwiftReparto, URL

### Community 40 - "Community 40"
Cohesion: 0.33
Nodes (5): Ownership split: PROJECT.md (Proyecto) vs CAST.md (Reparto), SwiftProyecto, Transition-window CastMember/Gender ambiguity, Docs/gotchas.md, Module/type name collision (targeted imports)

### Community 42 - "Community 42"
Cohesion: 0.40
Nodes (6): DependencyVersions.swift (generated), Docs/build-and-test.md, Never use swift build/test (Metal shaders), Release Binary workflow, verify-deps job (Dependency Table Drift), Tests workflow

### Community 43 - "Community 43"
Cohesion: 0.33
Nodes (4): LegacyProjectCastReader, CastMember, String, URL

### Community 44 - "Community 44"
Cohesion: 0.50
Nodes (5): CastDocument, REQUIREMENTS.md (2.1.0 Voices into Character Record), dossier-format .dossier character bundle, EC-23 .vox output location via manifest pointer, EC-26 echada migrate voices

### Community 45 - "Community 45"
Cohesion: 0.40
Nodes (5): decideVoxGeneration, VoxGenerationDecision, generate, skipExistingHasVariant, skipExistingUnreadable

### Community 46 - "Community 46"
Cohesion: 0.60
Nodes (3): fetch(), prime_one(), acervo-ci-prime.sh script

### Community 48 - "Community 48"
Cohesion: 0.50
Nodes (4): Phase B: Voice Locking, VoiceLockManager, .vox Bundle, VoxExporter

### Community 49 - "Community 49"
Cohesion: 0.67
Nodes (3): CastCommand, VoiceCommand, Test Analysis Report

## Ambiguous Edges - Review These
- `CHANGELOG` → `SwiftEchada README`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to
- `Tests Workflow` → `Execution Plan — GENERAL MUSTER`  [AMBIGUOUS]
  Docs/complete/general-muster-01/EXECUTION_PLAN.md · relation: references
- `Transition-window CastMember/Gender ambiguity` → `verify cast / prune cast removed (2.0.0)`  [AMBIGUOUS]
  Docs/gotchas.md · relation: conceptually_related_to

## Knowledge Gaps
- **105 isolated node(s):** `generate-coverage-badge.sh script`, `setup-mlx.sh script`, `Bool`, `existingVoxUnreadable`, `generate` (+100 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `CHANGELOG` and `SwiftEchada README`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Tests Workflow` and `Execution Plan — GENERAL MUSTER`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **What is the exact relationship between `Transition-window CastMember/Gender ambiguity` and `verify cast / prune cast removed (2.0.0)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `CastVoiceGenerator` connect `CLI Command Layer` to `Community 26`, `Character Types & Voice Design`?**
  _High betweenness centrality (0.101) - this node is a cross-community bridge._
- **Why does `ProjectFrontMatter` connect `Project Documentation` to `Character Types & Voice Design`, `CharacterProfile Type`, `Community 39`?**
  _High betweenness centrality (0.080) - this node is a cross-community bridge._
- **Why does `GenerateResult` connect `CLI Command Layer` to `Cast Voice Generation`?**
  _High betweenness centrality (0.037) - this node is a cross-community bridge._
- **Are the 12 inferred relationships involving `castableLanguages()` (e.g. with `.baseDescriptionCastableForAllNonEnglish()` and `.localizedVoiceCastableForItsLanguage()`) actually correct?**
  _`castableLanguages()` has 12 INFERRED edges - model-reasoned connections that need verification._