import AVFoundation
import ArgumentParser
import EchadaVoice
import Foundation
import SwiftHablare
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// Records every call; never touches the network.
final class FakeSampleBackend: ElevenLabsSampleBackend, @unchecked Sendable {
  private let lock = NSLock()
  private var _synthesized: [SpeechRequest] = []
  private var _estimated: [SpeechRequest] = []
  var synthesized: [SpeechRequest] { lock.withLock { _synthesized } }
  var estimated: [SpeechRequest] { lock.withLock { _estimated } }

  func estimateCredits(_ request: SpeechRequest) -> Int? {
    lock.withLock { _estimated.append(request) }
    return request.text.count * 2
  }

  func remainingCredits() async -> Int? { 1_000 }

  func synthesize(_ request: SpeechRequest) async throws -> Data {
    lock.withLock { _synthesized.append(request) }
    return SampleElevenLabsTests.wav(sampleRate: 24_000)
  }
}

@Suite("echada sample --provider elevenlabs — mocked")
struct SampleElevenLabsTests {

  /// A short 16-bit mono sine WAV.
  static func wav(sampleRate: Int, seconds: Double = 0.25) -> Data {
    let frames = Int(Double(sampleRate) * seconds)
    var pcm = Data()
    for i in 0..<frames {
      let value = Int16(8_000 * sin(2 * Double.pi * 440 * Double(i) / Double(sampleRate)))
      withUnsafeBytes(of: value.littleEndian) { pcm.append(contentsOf: $0) }
    }
    var header = Data()
    func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { header.append(contentsOf: $0) } }
    func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { header.append(contentsOf: $0) } }
    header.append(contentsOf: Array("RIFF".utf8))
    u32(UInt32(36 + pcm.count))
    header.append(contentsOf: Array("WAVEfmt ".utf8))
    u32(16)
    u16(1)
    u16(1)
    u32(UInt32(sampleRate))
    u32(UInt32(sampleRate * 2))
    u16(2)
    u16(16)
    header.append(contentsOf: Array("data".utf8))
    u32(UInt32(pcm.count))
    return header + pcm
  }

  static let previewText =
    "The preview line the designed voice speaks, long enough to be a real one."

  /// A project with: HERO (designed voice, `.vox`), NARRATOR (bare id), EXTRA (`elevenlabs://`),
  /// GHOST (VoxAlta only).
  private func makeProject() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("sample-el-\(UUID().uuidString)")
    let voice = dir.appendingPathComponent("characters/HERO.dossier/voice")
    try FileManager.default.createDirectory(at: voice, withIntermediateDirectories: true)

    var asset = VoiceAsset(name: "HERO", description: "A hero.")
    try asset.setExtension(
      [
        "voice_id": "voice_hero_1", "generated_voice_id": "gen_1",
        "design_model": "eleven_multilingual_ttv_v2", "description_sent": "A hero.",
        "sample_text": Self.previewText,
      ], forEngine: "elevenlabs")
    // 44.1 kHz on purpose: the export must come out 24 kHz mono.
    try asset.addSampleAudio(
      Self.wav(sampleRate: 44_100), engine: "elevenlabs", model: "eleven_multilingual_ttv_v2")
    try asset.write(to: voice.appendingPathComponent("HERO.vox"))
    // A VoxAlta sample already sits there; it must survive.
    try Data("voxalta".utf8).write(to: voice.appendingPathComponent("sample-neutral.m4a"))

    try "---\ntype: project\ntitle: sw\nauthor: T\ncreated: 2026-01-01T00:00:00Z\n---\n".write(
      to: dir.appendingPathComponent("PROJECT.md"), atomically: true, encoding: .utf8)
    try """
    ---
    type: cast
    schemaVersion: 1
    cast:
      - character: HERO
        voices:
          voxalta:
            - characters/HERO.dossier/voice/HERO.vox
          elevenlabs:
            - characters/HERO.dossier/voice/HERO.vox
      - character: NARRATOR
        voices:
          elevenlabs:
            - 21m00Tcm4TlvDq8ikWAM
      - character: EXTRA
        voices:
          elevenlabs:
            - "elevenlabs://abc123?x=1"
      - character: GHOST
        voices:
          voxalta:
            - characters/GHOST.dossier/voice/GHOST.vox
    ---

    """.write(
      to: dir.appendingPathComponent("CAST.md"), atomically: true, encoding: .utf8)
    return dir
  }

  private func runner(
    _ dir: URL, _ character: String, variant: String = "neutral", text: String? = nil,
    instruct: String? = nil, model: String = "eleven_v4", preview: Bool = false,
    dryRun: Bool = false, output: String? = nil, backend: FakeSampleBackend
  ) -> ElevenLabsSampleRunner {
    ElevenLabsSampleRunner(
      projectURL: dir.appendingPathComponent("PROJECT.md"), castName: "CAST.md",
      character: character, variant: variant, text: text, instruct: instruct, model: model,
      fromDesignPreview: preview, dryRun: dryRun, output: output,
      makeBackend: { backend }, log: { _ in })
  }

  private func audioFormat(_ url: URL) throws -> (rate: Double, channels: UInt32) {
    let file = try AVAudioFile(forReading: url)
    return (file.fileFormat.sampleRate, file.fileFormat.channelCount)
  }

  // MARK: Naming

  @Test("default output is voice/sample-<variant>-elevenlabs.m4a beside the VoxAlta samples")
  func outputNaming() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeSampleBackend()
    let result = try await runner(dir, "HERO", variant: "whisper", backend: backend).run()

    #expect(
      result.relativePath == "characters/HERO.dossier/voice/sample-whisper-elevenlabs.m4a")
    let url = URL(fileURLWithPath: result.path)
    #expect(FileManager.default.fileExists(atPath: url.path))
    #expect(url.deletingLastPathComponent().lastPathComponent == "voice")
    let format = try audioFormat(url)
    #expect(format.rate == 24_000)
    #expect(format.channels == 1)
    // The VoxAlta sample is untouched.
    let existing = url.deletingLastPathComponent().appendingPathComponent("sample-neutral.m4a")
    #expect(try Data(contentsOf: existing) == Data("voxalta".utf8))
    #expect(
      VoiceBuilder.elevenLabsSampleFileName(variant: "neutral") == "sample-neutral-elevenlabs.m4a")
  }

  @Test("--output overrides the default path")
  func outputOverride() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let target = dir.appendingPathComponent("custom/out.m4a").path
    let result = try await runner(dir, "HERO", output: target, backend: FakeSampleBackend()).run()
    #expect(result.path == target)
    #expect(FileManager.default.fileExists(atPath: target))
  }

  // MARK: Voice resolution

  @Test(".vox, bare id and elevenlabs:// all resolve; VoxAlta-only is an error")
  func voiceResolution() throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let roster = try CastMarkdownParser().parse(fileURL: dir.appendingPathComponent("CAST.md")).cast
    func member(_ name: String) -> CastMember { roster.first { $0.character == name }! }

    let designed = try ElevenLabsSampleRunner.resolveVoice(for: member("HERO"), castDirectory: dir)
    #expect(designed.voiceId == "voice_hero_1")
    #expect(designed.voxRelativePath == "characters/HERO.dossier/voice/HERO.vox")
    #expect(designed.voxURL != nil)

    let bare = try ElevenLabsSampleRunner.resolveVoice(for: member("NARRATOR"), castDirectory: dir)
    #expect(
      bare == ElevenLabsVoice(voiceId: "21m00Tcm4TlvDq8ikWAM", voxURL: nil, voxRelativePath: nil))

    let scheme = try ElevenLabsSampleRunner.resolveVoice(for: member("EXTRA"), castDirectory: dir)
    #expect(scheme.voiceId == "abc123")
    #expect(scheme.voxURL == nil)
  }

  @Test("the request carries the resolved voice id, model, text and mapped instruct")
  func requestShape() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeSampleBackend()
    let result = try await runner(
      dir, "HERO", variant: "whisper", text: "Did you sleep at all?", backend: backend
    ).run()
    let request = try #require(backend.synthesized.first)
    #expect(request.voice == .catalog(pluginId: "elevenlabs", voiceId: "voice_hero_1"))
    #expect(request.text == "Did you sleep at all?")
    #expect(request.instruct == "whisper")
    #expect(request.settings["model"] == .string("eleven_v4"))
    #expect(result.provider == "elevenlabs")
    #expect(result.model == "eleven_v4")
    #expect(result.voiceId == "voice_hero_1")
    #expect(result.variant == "whisper")
    #expect(result.instruct == "whisper")
    #expect(result.text == "Did you sleep at all?")
    #expect(result.creditsUsed == "Did you sleep at all?".count * 2)

    // Bare id, neutral: no instruct, default sample line.
    let neutral = try await runner(dir, "NARRATOR", backend: backend).run()
    #expect(neutral.instruct == nil)
    #expect(neutral.text == VoiceBuilder.defaultSampleLine)
    #expect(neutral.voxPath == nil)
    #expect(
      backend.synthesized.last?.voice
        == .catalog(pluginId: "elevenlabs", voiceId: "21m00Tcm4TlvDq8ikWAM"))
  }

  // MARK: Errors

  @Test("a member without voices.elevenlabs errors clearly and calls nothing")
  func missingVoice() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeSampleBackend()
    do {
      _ = try await runner(dir, "GHOST", backend: backend).run()
      Issue.record("expected failure")
    } catch let error as SampleElevenLabsError {
      #expect(error == .noElevenLabsVoice(character: "GHOST"))
      #expect(error.localizedDescription.contains("voices.elevenlabs"))
      #expect(error.localizedDescription.contains("echada voices"))
    }
    #expect(backend.synthesized.isEmpty)
    #expect(backend.estimated.isEmpty)
  }

  @Test("an unknown character lists the roster")
  func unknownCharacter() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    do {
      _ = try await runner(dir, "NOBODY", backend: FakeSampleBackend()).run()
      Issue.record("expected failure")
    } catch let error as SampleElevenLabsError {
      #expect(error.localizedDescription.contains("HERO"))
    }
  }

  // MARK: --dry-run

  @Test("--dry-run prices the sample, synthesizes nothing and writes nothing")
  func dryRun() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeSampleBackend()
    let result = try await runner(
      dir, "HERO", variant: "whisper", text: "Short line.", dryRun: true, backend: backend
    ).run()
    #expect(backend.synthesized.isEmpty)
    #expect(backend.estimated.count == 1)
    #expect(result.dryRun)
    #expect(result.creditsEstimated == "Short line.".count * 2)
    #expect(result.creditsUsed == 0)
    #expect(!FileManager.default.fileExists(atPath: result.path))
  }

  // MARK: --from-design-preview

  @Test("--from-design-preview exports the stored preview with no backend and no credits")
  func designPreview() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let runner = ElevenLabsSampleRunner(
      projectURL: dir.appendingPathComponent("PROJECT.md"), castName: "CAST.md",
      character: "HERO", variant: "neutral", text: nil, instruct: nil, model: "eleven_v4",
      fromDesignPreview: true, dryRun: false, output: nil,
      makeBackend: {
        Issue.record("the design preview must not create a backend")
        throw CancellationError()
      }, log: { _ in })
    let result = try await runner.run()

    #expect(result.relativePath == "characters/HERO.dossier/voice/sample-neutral-elevenlabs.m4a")
    #expect(result.creditsUsed == 0)
    #expect(result.creditsEstimated == 0)
    #expect(result.fromDesignPreview)
    #expect(result.text == Self.previewText)
    #expect(result.model == "eleven_multilingual_ttv_v2")
    #expect(result.voiceId == "voice_hero_1")
    #expect(result.voxPath == "characters/HERO.dossier/voice/HERO.vox")
    // The stored preview was 44.1 kHz; the export is 24 kHz mono like the other samples.
    let format = try audioFormat(URL(fileURLWithPath: result.path))
    #expect(format.rate == 24_000)
    #expect(format.channels == 1)
  }

  @Test("--from-design-preview on a stock voice errors clearly")
  func designPreviewStockVoice() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    do {
      _ = try await runner(dir, "NARRATOR", preview: true, backend: FakeSampleBackend()).run()
      Issue.record("expected failure")
    } catch let error as SampleElevenLabsError {
      #expect(error == .notADesignedVoice(character: "NARRATOR", voiceId: "21m00Tcm4TlvDq8ikWAM"))
      #expect(error.localizedDescription.contains("stock"))
    }
  }

  // MARK: JSON

  @Test("the result encodes the fields the dossier builder reads")
  func jsonShape() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let result = try await runner(dir, "HERO", variant: "whisper", backend: FakeSampleBackend())
      .run()
    let data = try JSONEncoder().encode(result)
    let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    for key in [
      "path", "provider", "model", "voiceId", "text", "sampleText", "instruct", "variant",
      "creditsUsed", "voxPath",
    ] {
      #expect(object[key] != nil, "missing \(key)")
    }
    #expect(object["provider"] as? String == "elevenlabs")
  }

  // MARK: VoxAlta unchanged

  @Test("the default provider is voxalta and the VoxAlta names don't change")
  func voxAltaUnchanged() throws {
    var command = try SampleCommand.parse(["MAYA", "--variant", "whisper"])
    try command.validate()
    #expect(command.provider == "voxalta")
    #expect(command.model == "1.7b")
    #expect(VoiceBuilder.sampleFileName(variant: "neutral", model: .large) == "sample-neutral.m4a")
    #expect(
      VoiceBuilder.sampleFileName(variant: "neutral", model: .small) == "sample-neutral-0.6b.m4a")
    command = try SampleCommand.parse(["MAYA", "--all-variants", "--json"])
    try command.validate()
  }

  @Test("ElevenLabs-only flags are rejected under voxalta; VoxAlta-only flags under elevenlabs")
  func flagValidation() throws {
    func invalid(_ args: [String]) -> Bool {
      do {
        let command = try SampleCommand.parse(args)
        try command.validate()
        return false
      } catch { return true }
    }
    #expect(invalid(["MAYA", "--dry-run"]))
    #expect(invalid(["MAYA", "--from-design-preview"]))
    #expect(invalid(["MAYA", "--instruct", "angry"]))
    #expect(invalid(["MAYA", "--provider", "nope"]))
    #expect(invalid(["MAYA", "--provider", "elevenlabs", "--all-variants"]))
    #expect(invalid(["MAYA", "--provider", "elevenlabs", "--model", "0.6b"]))
    #expect(invalid(["MAYA", "--provider", "elevenlabs", "--from-design-preview", "--dry-run"]))
    #expect(
      invalid(["MAYA", "--provider", "elevenlabs", "--from-design-preview", "--variant", "x"]))
    #expect(!invalid(["MAYA", "--provider", "elevenlabs", "--variant", "whisper", "--dry-run"]))
    #expect(!invalid(["MAYA", "--provider", "elevenlabs", "--from-design-preview", "--json"]))
  }
}
