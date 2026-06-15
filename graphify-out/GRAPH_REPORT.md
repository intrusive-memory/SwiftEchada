# Graph Report - .  (2026-06-14)

## Corpus Check
- 81 files · ~472,720 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 406 nodes · 642 edges · 24 communities (19 shown, 5 thin omitted)
- Extraction: 86% EXTRACTED · 14% INFERRED · 0% AMBIGUOUS · INFERRED: 93 edges (avg confidence: 0.8)
- Token cost: 116,958 input · 0 output

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
- [[_COMMUNITY_CharacterProfile Type|CharacterProfile Type]]
- [[_COMMUNITY_BPE Tokenization Note|BPE Tokenization Note]]

## God Nodes (most connected - your core abstractions)
1. `PerLanguagePromptTests` - 22 edges
2. `CastVoiceGenerator` - 19 edges
3. `castableLanguages()` - 18 edges
4. `CharacterProfile` - 16 edges
5. `decideVoxGeneration()` - 15 edges
6. `localizedVoicePrompt()` - 14 edges
7. `composeVoicePrompt()` - 13 edges
8. `NonEnglishPassthroughTests` - 13 edges
9. `test.textbundle (Highland 2 Screenplay Bundle)` - 13 edges
10. `VoiceCommand` - 12 edges

## Surprising Connections (you probably didn't know these)
- `API.md (redirect)` --semantically_similar_to--> `API Reference`  [INFERRED] [semantically similar]
  /Users/stovak/Projects/SwiftEchada/API.md → Docs/api.md
- `CastCommandTests` --references--> `CastVoiceGenerator`  [INFERRED]
  Tests/SwiftEchadaTests/CastCommandTests.swift → Sources/EchadaCLICore/CastVoiceGenerator.swift
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
- **Per-language voice casting stack** — todo_language_option, todo_samplesentencegenerator_lang, todo_voxformat_v040, todo_swiftvoxalta_v0130 [EXTRACTED 1.00]
- **Operation Accent Tower mission artifacts** — accent_tower_01_operation, accent_tower_01_eval_matrix, accent_tower_01_supervisor_state, accent_tower_01_test_cleanup [EXTRACTED 1.00]
- **Principal characters of the screenplay** — char_bernard, char_killian, char_mason [EXTRACTED 1.00]
- **Voice generation pipeline (audition sentence + design + lock + export)** — echadaclicore_foundationmodelsentence_foundationmodelsentence, echadaclicore_voicedesigner_voicedesigner, echadaclicore_castvoicegenerator_castvoicegenerator, concept_voicedesign_voicelock_pipeline [INFERRED 0.85]
- **Per-language castability resolution** — echadaclicore_castvoicegenerator_castablelanguages, echadaclicore_castvoicegenerator_localizedvoiceprompt, echadaclicore_castvoicegenerator_composevoiceprompt, echadaclicore_castvoicegenerator_voxlanguagetag [INFERRED 0.85]
- **Two-phase voice generation flow** — concept_cast_voice_generator, concept_phase_a_candidate, concept_phase_b_voice_locking, concept_vox_bundle [INFERRED 0.85]
- **echada CLI dependency stack** — concept_echada_cli, concept_swiftvoxalta, concept_mlx_swift, concept_vox_format [INFERRED 0.85]
- **Library pure data types** — concept_character_profile, concept_character_info, concept_character_merger [INFERRED 0.75]

## Communities (24 total, 5 thin omitted)

### Community 0 - "Cast Voice Generation"
Cohesion: 0.08
Nodes (23): CandidateResult, castableLanguages(), CastVoiceGenerator, CastVoiceGeneratorError, existingVoxUnreadable, unsupportedTTSModel, GenerateResult, localizedVoicePrompt() (+15 more)

### Community 1 - "CLI Command Layer"
Cohesion: 0.06
Nodes (18): AsyncParsableCommand, VoiceDesign to VoiceLock to VoxExporter pipeline, EchadaCLIEntry, CastCommand, EchadaCLI, TestVoiceCommand, VoiceCommand, voxLanguageTag (+10 more)

### Community 2 - "Character Types & Voice Design"
Cohesion: 0.08
Nodes (23): CharacterInfo, CharacterProfile, Codable, VoxGenerationDecision, generate, skipExistingHasVariant, skipExistingUnreadable, VoiceDesigner (+15 more)

### Community 3 - "Project Documentation"
Cohesion: 0.08
Nodes (29): API.md (redirect), Apple Intelligence requirement, CastCommand, CastVoiceGenerator, CharacterInfo, CharacterMerger, CharacterProfile, FoundationModelSentence (+21 more)

### Community 4 - "Character Info & Fixtures"
Cohesion: 0.07
Nodes (8): Fixtures characters.json, Fixtures PROJECT.md, Fixtures small/PROJECT.md, CharacterInfoTests, CharacterMergerTests, VoicePromptRoundTripTests, CastMember, ProjectMarkdownParser

### Community 5 - "Screenplay Characters"
Cohesion: 0.12
Nodes (24): BERNARD (protagonist, 40s M), DOG WALKER (50s M, with dog Fannie Brice), DONNIE / DONNIE LANIER (Mason's cousin), EDITOR (Killian's video editor), KILLIAN (co-conspirator, 40s M), MASON (Killian's husband, 40s M, murder victim), MICKEY BLAZE (video merchandiser), SYLVIA (Bernard's mother, 60s F) (+16 more)

### Community 6 - "Vox File Integration Tests"
Cohesion: 0.23
Nodes (15): VoxExporter path convention contract, ensureParent(), makeVoxFile(), syntheticClonePrompt(), syntheticWAV(), tempVoxURL(), VoxFileIntegrationTests, VoxPaths (+7 more)

### Community 7 - "Dependencies & Distribution"
Cohesion: 0.11
Nodes (17): Character Studio (proposal), echada CLI, Homebrew Distribution, Makefile build system, mlx-audio-swift, mlx-swift, Qwen3-TTS, SwiftAcervo (+9 more)

### Community 8 - "Vox Generation Decisions"
Cohesion: 0.18
Nodes (13): Qwen3-TTS .vox embedding layout (clone-prompt + sample-audio per model variant), decideVoxGeneration(), decideVoxGeneration, CastVoiceGeneratorDecisionTests, syntheticClonePrompt(), syntheticWAV(), tempVoxURL(), writeVoxOnDisk() (+5 more)

### Community 9 - "Accent Option Tests"
Cohesion: 0.13
Nodes (5): CastCommand.resolvedAccent, CastCommand.resolvedLanguages, CastCommand.run, composeVoicePrompt(), AccentOptionTests

### Community 10 - "Foundation Model Sentence"
Cohesion: 0.17
Nodes (9): FoundationModelSentence, FoundationModelSentenceError, appleIntelligenceUnavailable, generationFailed, unsupportedLanguage, NLLanguage, String, FoundationModelSentenceTests (+1 more)

### Community 11 - "Reference Audio Generation"
Cohesion: 0.21
Nodes (11): CustomStringConvertible, ReferenceAudioError, conversionFailed, sayFailed, ReferenceAudioGenerator, VoiceDesignerError, modelCastFailed, Error (+3 more)

### Community 12 - "Cover Artwork"
Cohesion: 0.17
Nodes (13): Voice Audition Scene, SwiftEchada Branding Illustration, SWIFT ECHADA Nameplate, Three Wooden Mannequin Judges at Desk, Mid-Century Modern Atomic Aesthetic, Wooden Mannequin Performer at Microphone, SwiftEchada Cover Artwork (PNG), Wooden Mannequin Audition/Casting Scene (+5 more)

### Community 13 - "Cast Command Tests"
Cohesion: 0.26
Nodes (3): CastCommandTests, String, URL

### Community 14 - "App Icon Artwork"
Cohesion: 0.24
Nodes (11): Voice casting / audition concept, SwiftEchada app icon (wooden mannequins audition scene), Standing microphone (voice/audio performance), Mid-century modern retro illustration style (atomic starburst, terrazzo floor), SwiftEchada Project Icon (small), Retro mid-century atomic-age design (starburst motifs, orange/teal palette), Row of seated mannequin figures behind desk (panel/casting audience), Wooden mannequin singing into microphone (+3 more)

### Community 15 - "Accent Tower Mission"
Cohesion: 0.31
Nodes (10): castableLanguages pure function, composeVoicePrompt free function, Accent Tower eval matrix, Operation Accent Tower mission, Piece 1 --accent directive, Piece 2 per-language prompt selection, Accent Tower supervisor state, Accent Tower test cleanup report (+2 more)

### Community 16 - "Per-Language Voice Casting"
Cohesion: 0.25
Nodes (8): Non-English .vox neutralize gotcha, decideVoxGeneration per-language limitation, Per-language embedding path scheme, Optional --language voice casting, Language-aware SampleSentenceGenerator, SwiftVoxAlta v0.13.0 (createLock language), vox-format v0.4.0 (EmbeddingEntry.language), voxLanguageTag mapping

### Community 17 - "CLI Core Extraction"
Cohesion: 0.67
Nodes (3): EchadaCLICore library extraction, Thin echada executable re-host, VinetasCLICore embedding pattern

## Knowledge Gaps
- **73 isolated node(s):** `generate-coverage-badge.sh script`, `setup-mlx.sh script`, `Bool`, `existingVoxUnreadable`, `generate` (+68 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **5 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `CastVoiceGenerator` connect `Cast Voice Generation` to `CLI Command Layer`, `Character Types & Voice Design`, `Vox Generation Decisions`, `Accent Option Tests`, `Foundation Model Sentence`, `Cast Command Tests`?**
  _High betweenness centrality (0.165) - this node is a cross-community bridge._
- **Why does `decideVoxGeneration()` connect `Vox Generation Decisions` to `Cast Voice Generation`, `Character Types & Voice Design`?**
  _High betweenness centrality (0.084) - this node is a cross-community bridge._
- **Why does `VoiceDesigner` connect `Character Types & Voice Design` to `Cast Voice Generation`, `CLI Command Layer`, `Reference Audio Generation`?**
  _High betweenness centrality (0.071) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `CastVoiceGenerator` (e.g. with `.run()` and `VoiceDesign to VoiceLock to VoxExporter pipeline`) actually correct?**
  _`CastVoiceGenerator` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 10 inferred relationships involving `castableLanguages()` (e.g. with `.baseDescriptionCastableForAllNonEnglish()` and `.localizedVoiceCastableForItsLanguage()`) actually correct?**
  _`castableLanguages()` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 6 inferred relationships involving `CharacterProfile` (e.g. with `.run()` and `.createsProfileWithAllFields()`) actually correct?**
  _`CharacterProfile` has 6 INFERRED edges - model-reasoned connections that need verification._
- **Are the 8 inferred relationships involving `decideVoxGeneration()` (e.g. with `.corruptExistingVox_isSkippedNotOverwritten()` and `.existing06b_request06b_skips()`) actually correct?**
  _`decideVoxGeneration()` has 8 INFERRED edges - model-reasoned connections that need verification._