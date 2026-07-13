# Graph Report - .  (2026-07-12)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 565 nodes · 886 edges · 38 communities (26 shown, 12 thin omitted)
- Extraction: 89% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 93 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `c61826f5`
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
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]

## God Nodes (most connected - your core abstractions)
1. `PerLanguagePromptTests` - 24 edges
2. `castableLanguages()` - 17 edges
3. `CharacterProfile` - 16 edges
4. `decideVoxGeneration()` - 14 edges
5. `SampleSentenceGeneratorTests` - 13 edges
6. `CastCommand` - 12 edges
7. `String` - 12 edges
8. `CastVoiceGenerator` - 12 edges
9. `GenerateCastCommandTests` - 12 edges
10. `composeVoicePrompt()` - 11 edges

## Surprising Connections (you probably didn't know these)
- `Gemini-specific rules` --semantically_similar_to--> `Claude-specific rules`  [INFERRED] [semantically similar]
  GEMINI.md → CLAUDE.md
- `Cast pipeline data flow` --implements--> `Two-phase voice generation pipeline`  [INFERRED]
  Docs/architecture.md → AGENTS.md
- `echada cast command` --references--> `CastVoiceGenerator struct`  [INFERRED]
  README.md → Docs/api.md
- `SwiftEchada README` --conceptually_related_to--> `CHANGELOG`  [AMBIGUOUS]
  README.md → CHANGELOG.md
- `Release Binary Workflow` --conceptually_related_to--> `Build, Test, and Release`  [INFERRED]
  .github/workflows/release.yml → Docs/build-and-test.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Per-language voice casting stack** — todo_language_option, todo_samplesentencegenerator_lang, todo_voxformat_v040, todo_swiftvoxalta_v0130 [EXTRACTED 1.00]
- **echada CLI dependency stack** — concept_echada_cli, concept_swiftvoxalta, concept_mlx_swift, concept_vox_format [INFERRED 0.85]
- **Operation Accent Tower mission artifacts** — accent_tower_01_operation, accent_tower_01_eval_matrix, accent_tower_01_supervisor_state, accent_tower_01_test_cleanup [EXTRACTED 1.00]
- **Two-phase voice generation flow** — concept_cast_voice_generator, concept_phase_a_candidate, concept_phase_b_voice_locking, concept_vox_bundle [INFERRED 0.85]
- **Principal characters of the screenplay** — char_bernard, char_killian, char_mason [EXTRACTED 1.00]

## Communities (38 total, 12 thin omitted)

### Community 0 - "Cast Voice Generation"
Cohesion: 0.06
Nodes (20): CastCommand.resolvedAccent, CastCommand.resolvedLanguages, CastCommand.run, castableLanguages, composeVoicePrompt, decideVoxGeneration, CastVoiceGenerator.generate, CastVoiceGenerator.generateCandidateWithPrompt (+12 more)

### Community 1 - "CLI Command Layer"
Cohesion: 0.06
Nodes (20): AsyncParsableCommand, EchadaCLIEntry, CastCommand, EchadaCLI, GenerateCastCommand, GenerateCommand, GeneratePromptCommand, GenerateVoxCommand (+12 more)

### Community 2 - "Character Types & Voice Design"
Cohesion: 0.08
Nodes (22): CharacterInfo, CharacterProfile, Codable, VoxGenerationDecision, generate, skipExistingHasVariant, skipExistingUnreadable, Equatable (+14 more)

### Community 3 - "Project Documentation"
Cohesion: 0.10
Nodes (25): CandidateResult, castingLanguages(), CastVoiceGenerator, CastVoiceGeneratorError, existingVoxUnreadable, unsupportedTTSModel, GenerateResult, logLanguageAudit() (+17 more)

### Community 4 - "Character Info & Fixtures"
Cohesion: 0.08
Nodes (37): castableLanguages pure function, composeVoicePrompt free function, Accent Tower eval matrix, Non-English .vox neutralize gotcha, Operation Accent Tower mission, Piece 1 --accent directive, Piece 2 per-language prompt selection, Accent Tower supervisor state (+29 more)

### Community 5 - "Screenplay Characters"
Cohesion: 0.11
Nodes (9): FilePattern, CastPipelineTests, CastCommandBootstrapTests, GenerateCastCommandTests, String, URL, CastMember, String (+1 more)

### Community 6 - "Vox File Integration Tests"
Cohesion: 0.13
Nodes (19): CustomStringConvertible, ReferenceAudioError, conversionFailed, sayFailed, ReferenceAudioGenerator, VoiceDesigner, VoiceDesignerError, modelCastFailed (+11 more)

### Community 7 - "Dependencies & Distribution"
Cohesion: 0.09
Nodes (5): TestVoiceCommand, Qwen3TTSModelRepo, String, SwiftEchada, SampleSentenceGeneratorTests

### Community 8 - "Vox Generation Decisions"
Cohesion: 0.13
Nodes (4): voxLanguageTag(), LanguageOptionTests, NonEnglishPassthroughTests, String

### Community 9 - "Accent Option Tests"
Cohesion: 0.26
Nodes (13): ensureParent(), makeVoxFile(), syntheticClonePrompt(), syntheticWAV(), tempVoxURL(), VoxFileIntegrationTests, VoxPaths, Data (+5 more)

### Community 10 - "Foundation Model Sentence"
Cohesion: 0.21
Nodes (11): decideVoxGeneration(), CastVoiceGeneratorDecisionTests, syntheticClonePrompt(), syntheticWAV(), tempVoxURL(), writeVoxOnDisk(), Data, Double (+3 more)

### Community 11 - "Reference Audio Generation"
Cohesion: 0.12
Nodes (19): echada CLI executable, Queryable graphify codemap, Makefile build/test rule, SwiftEchada (library + CLI), SwiftVoxAlta dependency, Targeted imports (module/type name collision), Two-phase voice generation pipeline, SwiftEchada module enum (+11 more)

### Community 12 - "Cover Artwork"
Cohesion: 0.19
Nodes (19): AGENTS.md — Project Documentation, API Reference, Architecture (referenced), Build, Test, and Release, CHANGELOG, CLAUDE.md — Claude Rules, Completed Work — SwiftEchada, Dependencies (+11 more)

### Community 14 - "App Icon Artwork"
Cohesion: 0.23
Nodes (8): CharacterDialogueEvidence, VoicePromptSynthesizer, VoicePromptSynthesizerError, appleIntelligenceUnavailable, generationFailed, Bool, Gender, String

### Community 15 - "Accent Tower Mission"
Cohesion: 0.32
Nodes (6): CharacterDialogueEvidence, Cue, DialogueExtractor, Bool, Int, String

### Community 16 - "Per-Language Voice Casting"
Cohesion: 0.17
Nodes (3): ParsableCommand, CLIWiringTests, String

### Community 17 - "CLI Core Extraction"
Cohesion: 0.30
Nodes (6): SourceMaterialLocator, Set, Bool, ProjectFrontMatter, String, URL

### Community 18 - "Vox System Integrations"
Cohesion: 0.26
Nodes (3): GenerateVoxCommandTests, String, URL

### Community 19 - "Local Settings"
Cohesion: 0.23
Nodes (7): Fixtures, makeIsolatedProject(), ModelBackedGenerationTests, TTSWeights, Bool, String, URL

### Community 20 - "Outline Fixture"
Cohesion: 0.27
Nodes (7): Same-Language Reference Sentence Casting, FoundationModelSentence, FoundationModelSentenceError, appleIntelligenceUnavailable, generationFailed, unsupportedLanguage, String

### Community 23 - "BPE Tokenization Note"
Cohesion: 0.38
Nodes (3): NLLanguage, FoundationModelSentenceTests, String

### Community 24 - "Community 24"
Cohesion: 0.60
Nodes (3): fetch(), prime_one(), acervo-ci-prime.sh script

### Community 26 - "Community 26"
Cohesion: 0.50
Nodes (4): Phase B: Voice Locking, VoiceLockManager, .vox Bundle, VoxExporter

### Community 28 - "Community 28"
Cohesion: 0.67
Nodes (3): CastCommand, VoiceCommand, Test Analysis Report

## Ambiguous Edges - Review These
- `CHANGELOG` → `SwiftEchada README`  [AMBIGUOUS]
  README.md · relation: conceptually_related_to
- `Tests Workflow` → `Execution Plan — GENERAL MUSTER`  [AMBIGUOUS]
  Docs/complete/general-muster-01/EXECUTION_PLAN.md · relation: references

## Knowledge Gaps
- **80 isolated node(s):** `generate-coverage-badge.sh script`, `setup-mlx.sh script`, `Bool`, `existingVoxUnreadable`, `generate` (+75 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **12 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `CHANGELOG` and `SwiftEchada README`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Tests Workflow` and `Execution Plan — GENERAL MUSTER`?**
  _Edge tagged AMBIGUOUS (relation: references) - confidence is low._
- **Why does `CastVoiceGenerator` connect `Project Documentation` to `Cast Voice Generation`, `CLI Command Layer`?**
  _High betweenness centrality (0.123) - this node is a cross-community bridge._
- **Why does `FilePattern` connect `Screenplay Characters` to `CLI Command Layer`, `Local Settings`?**
  _High betweenness centrality (0.093) - this node is a cross-community bridge._
- **Why does `CharacterProfile` connect `Character Types & Voice Design` to `Vox File Integration Tests`, `Dependencies & Distribution`?**
  _High betweenness centrality (0.085) - this node is a cross-community bridge._
- **Are the 12 inferred relationships involving `castableLanguages()` (e.g. with `.baseDescriptionCastableForAllNonEnglish()` and `.localizedVoiceCastableForItsLanguage()`) actually correct?**
  _`castableLanguages()` has 12 INFERRED edges - model-reasoned connections that need verification._
- **Are the 6 inferred relationships involving `CharacterProfile` (e.g. with `.run()` and `.createsProfileWithAllFields()`) actually correct?**
  _`CharacterProfile` has 6 INFERRED edges - model-reasoned connections that need verification._