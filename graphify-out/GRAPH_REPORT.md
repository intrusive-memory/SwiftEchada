# Graph Report - .  (2026-06-14)

## Corpus Check
- 79 files · ~471,167 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 410 nodes · 621 edges · 29 communities (22 shown, 7 thin omitted)
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 86 edges (avg confidence: 0.82)
- Token cost: 145,453 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Accent Tower Mission|Accent Tower Mission]]
- [[_COMMUNITY_Accent Option Tests|Accent Option Tests]]
- [[_COMMUNITY_CLI Command Layer|CLI Command Layer]]
- [[_COMMUNITY_Cast Voice Generation|Cast Voice Generation]]
- [[_COMMUNITY_Character Info & Fixtures|Character Info & Fixtures]]
- [[_COMMUNITY_Screenplay Characters|Screenplay Characters]]
- [[_COMMUNITY_Character Data Types|Character Data Types]]
- [[_COMMUNITY_Voice Design & Profiles|Voice Design & Profiles]]
- [[_COMMUNITY_Voice Casting Flow|Voice Casting Flow]]
- [[_COMMUNITY_Vox File Integration Tests|Vox File Integration Tests]]
- [[_COMMUNITY_Vox Generation Decisions|Vox Generation Decisions]]
- [[_COMMUNITY_Reference Audio Generation|Reference Audio Generation]]
- [[_COMMUNITY_Project Overview|Project Overview]]
- [[_COMMUNITY_Build & Distribution|Build & Distribution]]
- [[_COMMUNITY_Cover Artwork|Cover Artwork]]
- [[_COMMUNITY_App Icon Artwork|App Icon Artwork]]
- [[_COMMUNITY_Dependency Stack|Dependency Stack]]
- [[_COMMUNITY_Vox Pipeline|Vox Pipeline]]
- [[_COMMUNITY_Character Studio Proposal|Character Studio Proposal]]
- [[_COMMUNITY_API Redirect Doc|API Redirect Doc]]
- [[_COMMUNITY_Swift 6 Concurrency|Swift 6 Concurrency]]
- [[_COMMUNITY_Local Settings|Local Settings]]
- [[_COMMUNITY_MLX Audio Dependency|MLX Audio Dependency]]
- [[_COMMUNITY_SwiftProyecto Dependency|SwiftProyecto Dependency]]
- [[_COMMUNITY_Outline Fixture|Outline Fixture]]

## God Nodes (most connected - your core abstractions)
1. `PerLanguagePromptTests` - 23 edges
2. `castableLanguages()` - 14 edges
3. `decideVoxGeneration()` - 14 edges
4. `SampleSentenceGeneratorTests` - 13 edges
5. `test.textbundle (Highland 2 Screenplay Bundle)` - 13 edges
6. `CastVoiceGeneratorDecisionTests` - 12 edges
7. `composeVoicePrompt()` - 11 edges
8. `CastVoiceGenerator` - 11 edges
9. `SampleSentenceGenerator` - 11 edges
10. `AccentOptionTests` - 11 edges

## Surprising Connections (you probably didn't know these)
- `Gemini-specific rules` --semantically_similar_to--> `Claude-specific rules`  [INFERRED] [semantically similar]
  GEMINI.md → CLAUDE.md
- `AccentOptionTests` --references--> `CastCommand.resolvedAccent`  [EXTRACTED]
  Tests/SwiftEchadaTests/AccentOptionTests.swift → Sources/EchadaCLICore/CastCommand.swift
- `VoxFile` --shares_data_with--> `VoxManifest`  [INFERRED]
  Tests/SwiftEchadaTests/VoxFileIntegrationTests.swift → /Users/stovak/Projects/SwiftEchada/Tests/SwiftEchadaTests/VoxFileIntegrationTests.swift
- `outline.json (scene/section structure)` --shares_data_with--> `text.md (Fountain screenplay: CRISS CROSS / Bernard & Killian)`  [INFERRED]
  /Users/stovak/Projects/SwiftEchada/Fixtures/test.textbundle/resources/outline.json → /Users/stovak/Projects/SwiftEchada/Fixtures/test.textbundle/text.md
- `revisions/current.json (base64 archived screenplay)` --shares_data_with--> `text.md (Fountain screenplay: CRISS CROSS / Bernard & Killian)`  [INFERRED]
  /Users/stovak/Projects/SwiftEchada/Fixtures/test.textbundle/revisions/current.json → /Users/stovak/Projects/SwiftEchada/Fixtures/test.textbundle/text.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Highland 2 textbundle resource group** — test_textbundle, test_textbundle_text, resources_characters, resources_outline [EXTRACTED 1.00]
- **Echada CLI Subcommands** — echadaclicore_echadacli_echadacli, echadaclicore_castcommand_castcommand, echadaclicore_voicecommand_voicecommand, echadaclicore_testvoicecommand_testvoicecommand [EXTRACTED 1.00]
- **Character data model: CharacterInfo merged via CharacterMerger into CastMember** — swiftechada_characterinfo, swiftechada_charactermerger, swiftproyecto_castmember [INFERRED 0.85]
- **Synthetic .vox build/read flow against VoxExporter path contract** — swiftechadatests_voxfileintegrationtests_suite, swiftechadatests_castvoicegeneratordecisiontests_suite, voxformat_voxfile, concept_voxexporter_path_contract, concept_qwen3_tts_embedding_layout [INFERRED 0.85]
- **Release CI/CD flow to Homebrew** — workflows_release, concept_metal_bundle, concept_homebrew_distribution, concept_echada_cli [EXTRACTED 0.85]
- **Docs describing the .vox creation pipeline** — docs_vox_pipeline, docs_architecture, concept_two_phase_pipeline, concept_qwen3_tts, concept_vox_file [EXTRACTED 0.85]
- **Principal characters of the screenplay** — char_bernard, char_killian, char_mason [EXTRACTED 1.00]
- **Two-Phase Cast Voice Generation Pipeline** — castvoicegenerator_generate, castvoicegenerator_generatecandidatewithprompt, foundationmodelsentence_auditionsentence, castvoicegenerator_composevoiceprompt, castvoicegenerator_localizedvoiceprompt [INFERRED 0.85]
- **Per-Language Castability and Prompt Selection** — castvoicegenerator_castablelanguages, castvoicegenerator_localizedvoiceprompt, castvoicegenerator_voxlanguagetag, castvoicegenerator_composevoiceprompt [INFERRED 0.85]
- **Operation Accent Tower mission artifacts** — accent_tower_01_operation, accent_tower_01_eval_matrix, accent_tower_01_supervisor_state, accent_tower_01_test_cleanup [EXTRACTED 1.00]
- **Two-phase voice generation pipeline components** — api_castvoicegenerator, architecture_qwen3ttsmodel, architecture_voicelockmanager, architecture_voxexporter [EXTRACTED 1.00]
- **Per-language voice casting stack** — todo_language_option, todo_samplesentencegenerator_lang, todo_voxformat_v040, todo_swiftvoxalta_v0130 [EXTRACTED 1.00]

## Communities (29 total, 7 thin omitted)

### Community 0 - "Accent Tower Mission"
Cohesion: 0.08
Nodes (37): castableLanguages pure function, composeVoicePrompt free function, Accent Tower eval matrix, Non-English .vox neutralize gotcha, Operation Accent Tower mission, Piece 1 --accent directive, Piece 2 per-language prompt selection, Accent Tower supervisor state (+29 more)

### Community 1 - "Accent Option Tests"
Cohesion: 0.09
Nodes (5): castableLanguages(), composeVoicePrompt(), localizedVoicePrompt(), AccentOptionTests, PerLanguagePromptTests

### Community 2 - "CLI Command Layer"
Cohesion: 0.09
Nodes (15): AsyncParsableCommand, EchadaCLIEntry, CastCommand, EchadaCLI, TestVoiceCommand, VoiceCommand, Bool, String (+7 more)

### Community 3 - "Cast Voice Generation"
Cohesion: 0.11
Nodes (18): CandidateResult, CastVoiceGenerator, CastVoiceGeneratorError, existingVoxUnreadable, unsupportedTTSModel, GenerateResult, voxLanguageTag(), voxLanguageTag (+10 more)

### Community 4 - "Character Info & Fixtures"
Cohesion: 0.07
Nodes (8): Fixtures characters.json, Fixtures PROJECT.md, Fixtures small/PROJECT.md, CharacterInfoTests, CharacterMergerTests, VoicePromptRoundTripTests, CastMember, ProjectMarkdownParser

### Community 5 - "Screenplay Characters"
Cohesion: 0.12
Nodes (24): BERNARD (protagonist, 40s M), DOG WALKER (50s M, with dog Fannie Brice), DONNIE / DONNIE LANIER (Mason's cousin), EDITOR (Killian's video editor), KILLIAN (co-conspirator, 40s M), MASON (Killian's husband, 40s M, murder victim), MICKEY BLAZE (video merchandiser), SYLVIA (Bernard's mother, 60s F) (+16 more)

### Community 6 - "Character Data Types"
Cohesion: 0.14
Nodes (15): CharacterInfo, Codable, Equatable, Gender, Sendable, String, CastMember, String (+7 more)

### Community 7 - "Voice Design & Profiles"
Cohesion: 0.09
Nodes (3): CharacterEvidence, CharacterProfileTests, SampleSentenceGeneratorTests

### Community 8 - "Voice Casting Flow"
Cohesion: 0.10
Nodes (21): CastCommand.resolvedAccent, CastCommand.resolvedLanguages, CastCommand.run, castableLanguages, composeVoicePrompt, decideVoxGeneration, CastVoiceGenerator.generate, CastVoiceGenerator.generateCandidateWithPrompt (+13 more)

### Community 9 - "Vox File Integration Tests"
Cohesion: 0.22
Nodes (15): VoxExporter path convention contract, ensureParent(), makeVoxFile(), syntheticClonePrompt(), syntheticWAV(), tempVoxURL(), VoxFileIntegrationTests, VoxPaths (+7 more)

### Community 10 - "Vox Generation Decisions"
Cohesion: 0.17
Nodes (14): Qwen3-TTS .vox embedding layout (clone-prompt + sample-audio per model variant), decideVoxGeneration(), decideVoxGeneration, VoxFile, CastVoiceGeneratorDecisionTests, syntheticClonePrompt(), syntheticWAV(), tempVoxURL() (+6 more)

### Community 11 - "Reference Audio Generation"
Cohesion: 0.15
Nodes (17): CustomStringConvertible, ReferenceAudioError, conversionFailed, sayFailed, ReferenceAudioGenerator, VoiceDesigner, VoiceDesignerError, modelCastFailed (+9 more)

### Community 12 - "Project Overview"
Cohesion: 0.12
Nodes (20): echada CLI executable, Queryable graphify codemap, Makefile build/test rule, SwiftEchada (library + CLI), SwiftEchada library target, SwiftVoxAlta dependency, Targeted imports (module/type name collision), Two-phase voice generation pipeline (+12 more)

### Community 13 - "Build & Distribution"
Cohesion: 0.18
Nodes (11): Homebrew distribution (echada formula), Makefile / xcodebuild build requirement, MLX Metal bundle / metallib requirement, mlx-swift, Module/type name collision (SwiftEchada), Docs/build-and-test.md, Docs/gotchas.md, generate-coverage-badge.sh script (+3 more)

### Community 14 - "Cover Artwork"
Cohesion: 0.17
Nodes (13): Voice Audition Scene, SwiftEchada Branding Illustration, SWIFT ECHADA Nameplate, Three Wooden Mannequin Judges at Desk, Mid-Century Modern Atomic Aesthetic, Wooden Mannequin Performer at Microphone, SwiftEchada Cover Artwork (PNG), Wooden Mannequin Audition/Casting Scene (+5 more)

### Community 15 - "App Icon Artwork"
Cohesion: 0.24
Nodes (11): Voice casting / audition concept, SwiftEchada app icon (wooden mannequins audition scene), Standing microphone (voice/audio performance), Mid-century modern retro illustration style (atomic starburst, terrazzo floor), SwiftEchada Project Icon (small), Retro mid-century atomic-age design (starburst motifs, orange/teal palette), Row of seated mannequin figures behind desk (panel/casting audience), Wooden mannequin singing into microphone (+3 more)

### Community 16 - "Dependency Stack"
Cohesion: 0.50
Nodes (4): SwiftAcervo, SwiftVoxAlta, vox-format, Docs/dependencies.md

### Community 17 - "Vox Pipeline"
Cohesion: 0.50
Nodes (4): Qwen3-TTS, Two-phase voice pipeline, VoxFile (.vox bundle), Docs/vox-pipeline.md

## Knowledge Gaps
- **75 isolated node(s):** `generate-coverage-badge.sh script`, `setup-mlx.sh script`, `Bool`, `existingVoxUnreadable`, `generate` (+70 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **7 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `decideVoxGeneration()` connect `Vox Generation Decisions` to `Voice Casting Flow`, `Cast Voice Generation`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Why does `CharacterInfo` connect `Character Data Types` to `Character Info & Fixtures`?**
  _High betweenness centrality (0.062) - this node is a cross-community bridge._
- **Why does `CharacterProfile` connect `Character Data Types` to `CLI Command Layer`, `Reference Audio Generation`, `Voice Design & Profiles`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **Are the 9 inferred relationships involving `castableLanguages()` (e.g. with `.emptyRequestedLanguagesReturnsEmpty()` and `.localizedOnlyMemberIsCastableForRegionalTagViaBaseSubtag()`) actually correct?**
  _`castableLanguages()` has 9 INFERRED edges - model-reasoned connections that need verification._
- **Are the 8 inferred relationships involving `decideVoxGeneration()` (e.g. with `.corruptExistingVox_isSkippedNotOverwritten()` and `.existing06b_request06b_skips()`) actually correct?**
  _`decideVoxGeneration()` has 8 INFERRED edges - model-reasoned connections that need verification._
- **What connects `generate-coverage-badge.sh script`, `setup-mlx.sh script`, `Bool` to the rest of the system?**
  _83 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Accent Tower Mission` be split into smaller, more focused modules?**
  _Cohesion score 0.07657657657657657 - nodes in this community are weakly interconnected._