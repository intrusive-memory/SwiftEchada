import EchadaVoice
import Foundation
import SwiftReparto
import Testing
@preconcurrency import VoxFormat

/// This target depends on `EchadaVoice` alone, so it builds without
/// ArgumentParser or a PROJECT.md reader in its dependency closure — the
/// linkable-library requirement for Personaje (EC-P5, acceptance 4).
@Suite("EchadaVoice — app-facing voice builder")
struct EchadaVoiceTests {

  /// The TTS weights `buildVoice` loads are on disk in the SwiftAcervo cache
  /// the CI runner primes. A filesystem check only; it never loads a model.
  static let ttsWeightsPresent: Bool = {
    let env = ProcessInfo.processInfo.environment
    guard
      let path = ["ACERVO_MODELS_DIR", "TEST_RUNNER_ACERVO_MODELS_DIR"]
        .compactMap({ env[$0] }).first(where: { !$0.isEmpty })
    else { return false }
    let dir = URL(fileURLWithPath: path, isDirectory: true)
    return [
      "mlx-community_Qwen3-TTS-12Hz-1.7B-Base-bf16",
      "mlx-community_Qwen3-TTS-12Hz-0.6B-Base-bf16",
      "mlx-community_Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16",
    ].allSatisfy {
      FileManager.default.fileExists(atPath: dir.appending(path: "\($0)/manifest.json").path)
    }
  }()

  @Test("The builder places a new member's voice in its dossier folder (EC-23)")
  func locationForNewMember() throws {
    let dir = URL(fileURLWithPath: "/tmp/echada-voice-\(UUID().uuidString)")
    let builder = VoiceBuilder(castDirectory: dir)
    let location = try builder.location(for: CastMember(character: "SHANE"))
    #expect(location.relativePath == "characters/SHANE.dossier/voice/SHANE.vox")
  }

  @Test("A member with no voicePrompt can't be auditioned")
  func noPromptIsRefused() async {
    let builder = VoiceBuilder(castDirectory: FileManager.default.temporaryDirectory)
    await #expect(throws: VoiceBuilderError.self) {
      _ = try await builder.audition(for: CastMember(character: "SHANE"))
    }
  }

  /// **Gate: TTS weights.** EC-P6 in one call: one VoiceDesign candidate,
  /// locked with both Base sizes, written as one `.vox` to the EC-23 location.
  @Test(
    "buildVoice writes one .vox holding both the 1.7B and 0.6B embeddings (EC-P6)",
    .enabled(if: EchadaVoiceTests.ttsWeightsPresent), .timeLimit(.minutes(10)))
  func buildVoiceWritesBothEmbeddings() async throws {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("echada-voice-build-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }

    let member = CastMember(
      character: "SHANE", language: "en",
      voicePrompt: "A calm, warm narrator with a measured, steady pace.")
    let steps = ProgressLog()
    let result = try await VoiceBuilder(castDirectory: dir)
      .buildVoice(for: member, progress: { steps.append($0) })

    #expect(result.location.relativePath == "characters/SHANE.dossier/voice/SHANE.vox")
    #expect(Set(result.models) == [.large, .small])
    let vox = try VoxFile(contentsOf: result.location.url)
    #expect(vox.isValid)
    #expect(vox.isReady)
    #expect(vox.supportsModel("1.7b") && vox.supportsModel("0.6b"))
    #expect(result.updating(member).voices["voxalta"] == [result.location.relativePath])
    #expect(steps.values.contains(.locking(.small)))
  }
}

/// Collects progress events from a `@Sendable` callback.
final class ProgressLog: @unchecked Sendable {
  private let lock = NSLock()
  private var events: [VoiceBuildProgress] = []
  func append(_ event: VoiceBuildProgress) { lock.withLock { events.append(event) } }
  var values: [VoiceBuildProgress] { lock.withLock { events } }
}
