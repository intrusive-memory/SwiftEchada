import Foundation
import Testing
@preconcurrency import VoxFormat

@testable import EchadaVoice

@Suite("VoxSampleText — sample text recorded in the .vox (#70)")
struct VoxSampleTextTests {

  private func vox(sample: Data) throws -> VoxFile {
    let vox = VoxFile(name: "MAYA", description: "Synthetic test voice")
    try vox.add(
      sample, at: "embeddings/qwen3-tts/1.7b/sample-audio.wav",
      metadata: [
        "key": "qwen3-tts-1.7b-sample-audio", "model": SyntheticVox.modelIDs["1.7b"]!,
        "engine": "qwen3-tts", "format": "wav",
      ] as [String: Any])
    return vox
  }

  @Test("Recorded text survives a write and read of the .vox")
  func roundTrip() throws {
    let audio = SyntheticVox.wav()
    let vox = try vox(sample: audio)
    VoxSampleText.record("Please call Stella.", forSample: audio, in: vox)

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("vst-\(UUID().uuidString).vox")
    defer { try? FileManager.default.removeItem(at: url) }
    try vox.write(to: url)
    let reread = try VoxFile(contentsOf: url)
    #expect(VoxSampleText.text(forSample: audio, in: reread) == "Please call Stella.")
  }

  @Test("Different audio gets no text, even at the same path")
  func keyedByContent() throws {
    let audio = SyntheticVox.wav()
    let vox = try vox(sample: audio)
    VoxSampleText.record("Old line.", forSample: audio, in: vox)
    #expect(VoxSampleText.text(forSample: SyntheticVox.wav(sampleRate: 16000), in: vox) == nil)
  }

  @Test("A .vox with no echada extension has no text")
  func legacyVox() throws {
    let audio = SyntheticVox.wav()
    #expect(VoxSampleText.text(forSample: audio, in: try vox(sample: audio)) == nil)
  }

  @Test("Re-recording drops text for audio that is no longer embedded")
  func prunesStaleEntries() throws {
    let old = SyntheticVox.wav()
    let new = SyntheticVox.wav(sampleRate: 16000)
    let vox = try vox(sample: old)
    VoxSampleText.record("Old line.", forSample: old, in: vox)
    try vox.add(
      new, at: "embeddings/qwen3-tts/1.7b/sample-audio.wav",
      metadata: [
        "key": "qwen3-tts-1.7b-sample-audio", "model": SyntheticVox.modelIDs["1.7b"]!,
        "engine": "qwen3-tts", "format": "wav",
      ] as [String: Any])
    VoxSampleText.record("New line.", forSample: new, in: vox)

    let texts = (vox.manifest.extensions?["echada"]?.value as? [String: Any])?["sample_text"]
      as? [String: Any]
    #expect(texts?.count == 1)
    #expect(VoxSampleText.text(forSample: new, in: vox) == "New line.")
    #expect(VoxSampleText.text(forSample: old, in: vox) == nil)
  }

  @Test("Other extensions are left alone")
  func keepsOtherExtensions() throws {
    let audio = SyntheticVox.wav()
    let vox = try vox(sample: audio)
    vox.manifest.extensions = ["elevenlabs": AnyCodable(["voice_id": "abc123"])]
    VoxSampleText.record("A line.", forSample: audio, in: vox)
    let eleven = vox.manifest.extensions?["elevenlabs"]?.value as? [String: Any]
    #expect(eleven?["voice_id"] as? String == "abc123")
  }
}
