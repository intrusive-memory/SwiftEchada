# Backlog

## .vox Quick Look Plugin

A macOS Quick Look extension that previews `.vox` voice files in Finder. Selecting a `.vox` file and pressing Space should extract and play the sample audio from `embeddings/qwen3-tts/<model>/sample-audio.wav` in the archive, and display voice metadata from `manifest.json` (name, description, available model embeddings).

Requires:
- Register `.vox` as a custom UTI
- Quick Look preview extension (QLPreviewingController)
- Code signing for distribution

## .vox Automator Quick Action

A Finder Quick Action (right-click menu) that extracts and plays the sample audio from a `.vox` file. Lightweight alternative to the Quick Look plugin — no code signing required.

Implementation: Automator workflow or macOS Shortcut that finds and plays the first `sample-audio.wav` from `embeddings/qwen3-tts/<model>/` in the `.vox` archive.
