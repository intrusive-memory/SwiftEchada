//
//  VoicesLiveTests.swift
//  SwiftEchadaLiveTests
//
//  Real ElevenLabs calls for `echada voices design` / `assign` (EL-4.7). Not part of
//  `make test`; run with `make test-live`. Gated twice: only when ELEVENLABS_API_KEY is set
//  and GITHUB_ACTIONS is not "true".
//
//  Budget: one design call (three previews), one TTS line of at most 60 characters. The
//  designed voice is deleted in cleanup that always runs. The key is read from the
//  environment and never printed.
//

import Foundation
import SwiftHablare
import SwiftHablareOnce
import SwiftOnce
import SwiftReparto
import Testing

@testable import EchadaCLICore

private let environment = ProcessInfo.processInfo.environment
private let liveKey = environment["ELEVENLABS_API_KEY"] ?? ""
private let liveEnabled = !liveKey.isEmpty && environment["GITHUB_ACTIONS"] != "true"
private let skipReason: Comment =
  "Live ElevenLabs test needs ELEVENLABS_API_KEY and runs only outside GitHub Actions (make test-live)"

private func log(_ line: String) { print("[live] \(line)") }

@Suite(.serialized) struct VoicesLiveTests {

  @Test(.enabled(if: liveEnabled, skipReason))
  func designPickSynthesizeAndFreeTheSlot() async throws {
    let fm = FileManager.default
    let tag = UUID().uuidString.prefix(8)
    let title = "echada-live-\(tag)"
    let dir = fm.temporaryDirectory.appendingPathComponent(title)
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: dir) }
    try """
    ---
    type: project
    title: \(title)
    author: Test
    created: 2026-01-01T00:00:00Z
    ---
    """.write(to: dir.appendingPathComponent("PROJECT.md"), atomically: true, encoding: .utf8)
    try """
    ---
    type: cast
    schemaVersion: 1
    cast:
      - character: TESTER
        role: narrator
        voicePrompt: "A calm, warm older woman with a soft coastal accent."
        provider: elevenlabs
    ---

    """.write(to: dir.appendingPathComponent("CAST.md"), atomically: true, encoding: .utf8)

    let sample =
      "The tide is out and the lanterns are lit along the pier, so come and walk with me a while before the fog rolls in."
    #expect((100...150).contains(sample.count), "sample is \(sample.count) characters")
    let line = "The harbor lights are coming on."  // 32 characters
    #expect(line.count <= 60)

    let backend = try await LiveElevenLabsBackend()
    let client = SwiftOnce(apiKey: liveKey)
    let before = try await backend.slots().used
    log("voice_slots_used before: \(before)")

    var failure: Error?
    do {
      let projectURL = dir.appendingPathComponent("PROJECT.md")
      let candidates = dir.appendingPathComponent("candidates").path
      let design = VoicesDesignRunner(
        projectURL: projectURL, castName: "CAST.md", characters: ["TESTER"], roles: [],
        sampleTextOverride: sample, designModel: "eleven_multilingual_ttv_v2",
        candidatesDir: candidates, pick: nil, backend: backend, log: { log($0) })
      let outcome = try await design.run()
      #expect(outcome.failures.isEmpty)

      let index = try #require(
        try VoiceCandidateIndex.load(from: URL(fileURLWithPath: candidates, isDirectory: true)))
      let first = try #require(index.candidates.first, "design returned no candidates")
      log("candidates returned: \(index.candidates.count)")

      let pick = VoicesDesignRunner(
        projectURL: projectURL, castName: "CAST.md", characters: ["TESTER"], roles: [],
        sampleTextOverride: nil, designModel: "eleven_multilingual_ttv_v2",
        candidatesDir: candidates, pick: first.generatedVoiceId, backend: backend,
        log: { log($0) })
      try await pick.run()

      let vox = dir.appendingPathComponent("characters/TESTER.dossier/voice/TESTER.vox")
      #expect(fm.fileExists(atPath: vox.path))

      let plugin = try await ElevenLabsPlugin(
        context: PluginContext(keys: ChainedAPIKeyStore.default, registry: PluginRegistry.default))
      let synth = try #require(plugin.synthesizer)
      let audio = try await synth.synthesize(
        SpeechRequest(
          text: line, voice: .asset(vox), settings: VoiceSettings(["model": .string("eleven_v4")])))
      log("synthesized \(line.count) characters, \(audio.duration) s, \(audio.data.count) bytes")
      #expect(audio.data.prefix(4) == Data("RIFF".utf8))
      #expect(audio.duration > 0.5)
    } catch {
      failure = error
    }

    // Cleanup runs on success and failure alike: delete by the id recorded in the .vox,
    // else by the unique voice name.
    var deleteError: Error?
    let vox = dir.appendingPathComponent("characters/TESTER.dossier/voice/TESTER.vox")
    let recorded = (try? VoiceAsset(contentsOf: vox))?
      .extensionFields(forEngine: "elevenlabs")?["voice_id"] as? String
    if let recorded {
      do { try await client.deleteVoice(recorded) } catch { deleteError = error }
    }
    await client.invalidateVoiceCache()
    if let found = try? await client.voices(search: title, category: .generated) {
      for voice in found.voices where voice.name.contains(title) {
        do { try await client.deleteVoice(voice.voiceId) } catch { deleteError = error }
      }
    }
    let after = try await backend.slots().used
    log("voice_slots_used after: \(after)")

    if let failure { throw failure }
    if let deleteError { throw deleteError }
    #expect(after == before, "voice slot leaked: before \(before), after \(after)")
  }
}
