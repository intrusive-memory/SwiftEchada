# Changelog

All notable changes to SwiftEchada will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.9.2] - 2026-02-21

### Added
- CharacterProfile for detailed voice profiling (gender, age range, voice traits)
- CharacterAnalyzer for building profiles from cast members via LLM
- SampleSentenceGenerator for TTS audition sentences
- ParentheticalMapper for screenplay parenthetical-to-TTS mapping
- VoiceDesigner for candidate WAV generation via Qwen3-TTS
- CastVoiceGenerator for orchestrating .vox pipeline
- ReferenceAudioGenerator (macOS `say` fallback)
- `echada cast` command for on-device voice generation

### Changed
- Library now depends only on SwiftProyecto (removed SwiftHablare dependency)
- Makefile uses xcodebuild exclusively (no more swift build/swift test)
- 54 tests across 7 suites (up from 31)

### Removed
- CastMatcher and `echada match` command (replaced by `echada cast`)
- ElevenLabs types and defaults export
- CastMember+Provider extension
- SwiftHablare dependency
- REQUIREMENTS.md

## [0.9.1] - 2026-02-14

### Added
- SwiftVoxAlta integration for on-device voice generation
- VoiceDescriptionEnricher for LLM-powered voice descriptions

### Changed
- Updated architecture documentation

## [0.6.0] - 2026-02-01

### Added
- AGENTS.md with comprehensive project documentation
- LICENSE (MIT)
- CONTRIBUTING.md
- CHANGELOG.md

### Changed
- CLAUDE.md now serves as a stub referencing AGENTS.md

## [0.5.0] - 2026-01-27

### Added
- Initial public release
- CharacterExtractor with LLM-powered character discovery
- CharacterMerger for deduplication across files
- CastMatcher for TTS voice assignment via LLM
- `echada` CLI with extract, match, and download commands
- Closure-based dependency injection for testability
- Scene-based chunking for large screenplay files
- Homebrew distribution support
