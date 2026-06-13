# Graph Report - .  (2026-06-12)

## Corpus Check
- 69 files · ~460,985 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 322 nodes · 524 edges · 14 communities (13 shown, 1 thin omitted)
- Extraction: 90% EXTRACTED · 10% INFERRED · 0% AMBIGUOUS · INFERRED: 55 edges (avg confidence: 0.81)
- Token cost: 272,464 input · 116,768 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Project Docs & Distribution|Project Docs & Distribution]]
- [[_COMMUNITY_CLI Command Interface|CLI Command Interface]]
- [[_COMMUNITY_Character Data Model|Character Data Model]]
- [[_COMMUNITY_Character Model Tests & Fixtures|Character Model Tests & Fixtures]]
- [[_COMMUNITY_Screenplay Fixture (Textbundle)|Screenplay Fixture (Textbundle)]]
- [[_COMMUNITY_Cast Voice Generation|Cast Voice Generation]]
- [[_COMMUNITY_Vox File Format Integration|Vox File Format Integration]]
- [[_COMMUNITY_Voice Design & Reference Audio|Voice Design & Reference Audio]]
- [[_COMMUNITY_Profile & Sentence Generation Tests|Profile & Sentence Generation Tests]]
- [[_COMMUNITY_Vox Generation Decision Logic|Vox Generation Decision Logic]]
- [[_COMMUNITY_Cover Art & Branding|Cover Art & Branding]]
- [[_COMMUNITY_App Icon Imagery|App Icon Imagery]]
- [[_COMMUNITY_Package & Dependency Setup|Package & Dependency Setup]]
- [[_COMMUNITY_Outline Fixture|Outline Fixture]]

## God Nodes (most connected - your core abstractions)
1. `decideVoxGeneration()` - 15 edges
2. `CastVoiceGenerator` - 15 edges
3. `SampleSentenceGenerator` - 13 edges
4. `SampleSentenceGeneratorTests` - 13 edges
5. `test.textbundle (Highland 2 Screenplay Bundle)` - 13 edges
6. `CastVoiceGeneratorDecisionTests` - 12 edges
7. `TestVoiceCommand` - 11 edges
8. `VoiceCommand` - 11 edges
9. `CharacterMergerTests` - 11 edges
10. `VoxFileIntegrationTests` - 11 edges

## Surprising Connections (you probably didn't know these)
- `API.md (redirect)` --semantically_similar_to--> `Docs/api.md`  [INFERRED] [semantically similar]
  API.md → Docs/api.md
- `Fixtures PROJECT.md` --shares_data_with--> `ProjectMarkdownParser`  [INFERRED]
  Fixtures/PROJECT.md → Tests/SwiftEchadaTests/VoicePromptRoundTripTests.swift
- `Fixtures small/PROJECT.md` --shares_data_with--> `ProjectMarkdownParser`  [INFERRED]
  Fixtures/small/PROJECT.md → Tests/SwiftEchadaTests/VoicePromptRoundTripTests.swift
- `SwiftEchada app icon (wooden mannequins audition scene)` --semantically_similar_to--> `SwiftEchada Project Icon (small)`  [INFERRED] [semantically similar]
  icon.jpg → icon-sm.png
- `outline.json (scene/section structure)` --shares_data_with--> `text.md (Fountain screenplay: CRISS CROSS / Bernard & Killian)`  [INFERRED]
  Fixtures/test.textbundle/resources/outline.json → Fixtures/test.textbundle/text.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Voice Generation Pipeline** — echadaclicore_castvoicegenerator_castvoicegenerator, echadaclicore_voicedesigner_voicedesigner, swiftechada_samplesentencegenerator_samplesentencegenerator, swiftechada_characterprofile_characterprofile [INFERRED 0.85]
- **Echada CLI Subcommands** — echadaclicore_echadacli_echadacli, echadaclicore_castcommand_castcommand, echadaclicore_voicecommand_voicecommand, echadaclicore_testvoicecommand_testvoicecommand [EXTRACTED 1.00]
- **Synthetic .vox build/read flow against VoxExporter path contract** — swiftechadatests_voxfileintegrationtests_suite, swiftechadatests_castvoicegeneratordecisiontests_suite, voxformat_voxfile, concept_voxexporter_path_contract, concept_qwen3_tts_embedding_layout [INFERRED 0.85]
- **Character data model: CharacterInfo merged via CharacterMerger into CastMember** — swiftechada_characterinfo, swiftechada_charactermerger, swiftproyecto_castmember [INFERRED 0.85]
- **Highland 2 textbundle resource group** — test_textbundle, test_textbundle_text, resources_characters, resources_outline [EXTRACTED 1.00]
- **Principal characters of the screenplay** — char_bernard, char_killian, char_mason [EXTRACTED 1.00]
- **Docs describing the .vox creation pipeline** — docs_vox_pipeline, docs_architecture, concept_two_phase_pipeline, concept_qwen3_tts, concept_vox_file [EXTRACTED 0.85]
- **Agent onboarding docs hub** — agents, claude_md, gemini_md [EXTRACTED 0.85]
- **Release CI/CD flow to Homebrew** — workflows_release, concept_metal_bundle, concept_homebrew_distribution, concept_echada_cli [EXTRACTED 0.85]

## Communities (14 total, 1 thin omitted)

### Community 0 - "Project Docs & Distribution"
Cohesion: 0.07
Nodes (38): API.md (redirect), .claude/settings.local.json, CastVoiceGenerator, CharacterMerger, CharacterProfile, Character Studio (proposal), echada CLI, EchadaCLICore library (+30 more)

### Community 1 - "CLI Command Interface"
Cohesion: 0.07
Nodes (18): AsyncParsableCommand, VoiceDesign to VoiceLock to Vox Pipeline, EchadaCLIEntry, CastCommand, EchadaCLI, TestVoiceCommand, VoiceCommand, voxLanguageTag (+10 more)

### Community 2 - "Character Data Model"
Cohesion: 0.11
Nodes (19): CharacterInfo, Codable, VoxGenerationDecision, generate, skipExistingHasVariant, skipExistingUnreadable, Equatable, Gender (+11 more)

### Community 3 - "Character Model Tests & Fixtures"
Cohesion: 0.07
Nodes (8): Fixtures characters.json, Fixtures PROJECT.md, Fixtures small/PROJECT.md, CharacterInfoTests, CharacterMergerTests, VoicePromptRoundTripTests, CastMember, ProjectMarkdownParser

### Community 4 - "Screenplay Fixture (Textbundle)"
Cohesion: 0.12
Nodes (24): BERNARD (protagonist, 40s M), DOG WALKER (50s M, with dog Fannie Brice), DONNIE / DONNIE LANIER (Mason's cousin), EDITOR (Killian's video editor), KILLIAN (co-conspirator, 40s M), MASON (Killian's husband, 40s M, murder victim), MICKEY BLAZE (video merchandiser), SYLVIA (Bernard's mother, 60s F) (+16 more)

### Community 5 - "Cast Voice Generation"
Cohesion: 0.15
Nodes (18): Two-Phase Voice Generation, CandidateResult, CastVoiceGenerator, CastVoiceGeneratorError, existingVoxUnreadable, unsupportedTTSModel, GenerateResult, voxLanguageTag() (+10 more)

### Community 6 - "Vox File Format Integration"
Cohesion: 0.22
Nodes (15): VoxExporter path convention contract, ensureParent(), makeVoxFile(), syntheticClonePrompt(), syntheticWAV(), tempVoxURL(), VoxFileIntegrationTests, VoxPaths (+7 more)

### Community 7 - "Voice Design & Reference Audio"
Cohesion: 0.14
Nodes (17): CustomStringConvertible, ReferenceAudioError, conversionFailed, sayFailed, ReferenceAudioGenerator, VoiceDesigner, VoiceDesignerError, modelCastFailed (+9 more)

### Community 8 - "Profile & Sentence Generation Tests"
Cohesion: 0.09
Nodes (3): CharacterEvidence, CharacterProfileTests, SampleSentenceGeneratorTests

### Community 9 - "Vox Generation Decision Logic"
Cohesion: 0.18
Nodes (13): Qwen3-TTS .vox embedding layout (clone-prompt + sample-audio per model variant), decideVoxGeneration(), decideVoxGeneration, CastVoiceGeneratorDecisionTests, syntheticClonePrompt(), syntheticWAV(), tempVoxURL(), writeVoxOnDisk() (+5 more)

### Community 10 - "Cover Art & Branding"
Cohesion: 0.17
Nodes (13): Voice Audition Scene, SwiftEchada Branding Illustration, SWIFT ECHADA Nameplate, Three Wooden Mannequin Judges at Desk, Mid-Century Modern Atomic Aesthetic, Wooden Mannequin Performer at Microphone, SwiftEchada Cover Artwork (PNG), Wooden Mannequin Audition/Casting Scene (+5 more)

### Community 11 - "App Icon Imagery"
Cohesion: 0.24
Nodes (11): Voice casting / audition concept, SwiftEchada app icon (wooden mannequins audition scene), Standing microphone (voice/audio performance), Mid-century modern retro illustration style (atomic starburst, terrazzo floor), SwiftEchada Project Icon (small), Retro mid-century atomic-age design (starburst motifs, orange/teal palette), Row of seated mannequin figures behind desk (panel/casting audience), Wooden mannequin singing into microphone (+3 more)

### Community 12 - "Package & Dependency Setup"
Cohesion: 0.40
Nodes (6): Sibling Local Checkout Dependency Pattern, Package, sibling(), String, SwiftEchada Package, Version

## Knowledge Gaps
- **57 isolated node(s):** `generate-coverage-badge.sh script`, `Package`, `String`, `Version`, `setup-mlx.sh script` (+52 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `SampleSentenceGenerator` connect `Character Data Model` to `Profile & Sentence Generation Tests`, `CLI Command Interface`, `Cast Voice Generation`, `Voice Design & Reference Audio`?**
  _High betweenness centrality (0.109) - this node is a cross-community bridge._
- **Why does `CastVoiceGenerator` connect `Cast Voice Generation` to `CLI Command Interface`, `Character Data Model`, `Vox Generation Decision Logic`?**
  _High betweenness centrality (0.083) - this node is a cross-community bridge._
- **Why does `CharacterProfile` connect `Character Data Model` to `Profile & Sentence Generation Tests`, `CLI Command Interface`, `Voice Design & Reference Audio`?**
  _High betweenness centrality (0.081) - this node is a cross-community bridge._
- **Are the 8 inferred relationships involving `decideVoxGeneration()` (e.g. with `.corruptExistingVox_isSkippedNotOverwritten()` and `.existing06b_request06b_skips()`) actually correct?**
  _`decideVoxGeneration()` has 8 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `CastVoiceGenerator` (e.g. with `Two-Phase Voice Generation` and `.run()`) actually correct?**
  _`CastVoiceGenerator` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `generate-coverage-badge.sh script`, `Package`, `String` to the rest of the system?**
  _58 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Project Docs & Distribution` be split into smaller, more focused modules?**
  _Cohesion score 0.06857142857142857 - nodes in this community are weakly interconnected._