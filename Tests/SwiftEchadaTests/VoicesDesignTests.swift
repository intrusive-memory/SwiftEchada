import Foundation
import SwiftHablare
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// Mocked-API coverage for `echada voices design` (EL-4.2 ... EL-4.6): a fake
/// backend and designer stand in for ElevenLabs, so no network is touched.

/// Records every call so a test can assert on ordering.
final class FakeElevenLabsBackend: ElevenLabsBackend, @unchecked Sendable {
  private let lock = NSLock()
  private var _events: [String] = []
  private var _slots: VoiceSlots
  private var counter = 0
  /// Characters (by voicePrompt substring) whose design is rejected.
  var rejectPromptsContaining: [String] = []

  init(limit: Int = 10, used: Int = 0) { _slots = VoiceSlots(limit: limit, used: used) }

  var events: [String] { lock.withLock { _events } }
  func record(_ event: String) { lock.withLock { _events.append(event) } }
  func nextCounter() -> Int { lock.withLock { counter += 1; return counter } }
  func addSlotUse() { lock.withLock { _slots.used += 1 } }
  func freeSlotUse() { lock.withLock { _slots.used -= 1 } }

  func slots() async throws -> VoiceSlots { lock.withLock { _slots } }
  func remainingCredits() async -> Int? { 50_000 }
  func estimateDesignCost(characters: Int) -> Int { characters }

  func designer(voiceName: String, designModel: String) -> any VoiceDesigner {
    FakeDesigner(backend: self, voiceName: voiceName, designModel: designModel)
  }

  func candidate(
    generatedVoiceId: String, previewWAV: Data, designModel: String, sampleText: String,
    description: String
  ) throws -> VoiceCandidate {
    VoiceCandidate(
      preview: GeneratedAudio(
        data: previewWAV, format: Self.format, duration: 0.01),
      handle: VoiceCandidate.Handle(
        identifier: generatedVoiceId,
        payload: try JSONEncoder().encode([designModel, sampleText])),
      promptSent: description)
  }

  static let format = AudioFormat(container: .wav, sampleRate: 24_000, channels: 1, bitDepth: 16)
  static let wav = Data("RIFF-fake-preview".utf8)
}

struct FakeDesigner: VoiceDesigner {
  let backend: FakeElevenLabsBackend
  let voiceName: String
  let designModel: String

  var producedSources: [VoiceSourcePattern] {
    [VoiceSourcePattern(engine: "elevenlabs", kind: .referenceAudio)]
  }

  func design(_ request: VoiceDesignRequest) async throws -> [VoiceCandidate] {
    backend.record("design:\(request.description.prefix(12))")
    if backend.rejectPromptsContaining.contains(where: { request.description.contains($0) }) {
      throw HablareError.invalidRequest(detail: "prompt violates the voice design policy")
    }
    return try (0..<3).map { _ in
      try backend.candidate(
        generatedVoiceId: "gen_\(backend.nextCounter())", previewWAV: FakeElevenLabsBackend.wav,
        designModel: designModel, sampleText: request.sampleText, description: request.description)
    }
  }

  func save(_ candidate: VoiceCandidate, into asset: inout VoiceAsset) async throws {
    let voiceId = "voice_\(backend.nextCounter())"
    backend.record("save:\(voiceName):\(candidate.handle.identifier)->\(voiceId)")
    backend.addSlotUse()
    try asset.setExtension(
      [
        "voice_id": voiceId, "generated_voice_id": candidate.handle.identifier,
        "design_model": designModel, "description_sent": candidate.promptSent,
        "sample_text": "x", "created_at": "2026-11-04T00:00:00Z",
      ], forEngine: "elevenlabs")
    try asset.addSampleAudio(candidate.preview.data, engine: "elevenlabs", model: designModel)
  }

  func delete(_ voice: VoiceReference) async throws {
    if case .catalog(_, let id) = voice { backend.record("delete:\(id)") }
    backend.freeSlotUse()
  }
}

@Suite("echada voices design — mocked API")
struct VoicesDesignTests {

  static let narratorLine =
    "The server room hummed with the patient sound of a thousand small decisions being made "
    + "somewhere far below the floor, and nobody noticed."

  static let castText = """
    ---
    type: cast
    schemaVersion: 1
    cast:
      - character: NARRATOR
        role: narrator
        voicePrompt: "Deep authoritative British baritone with measured pacing."
        provider: elevenlabs
        voices:
          voxalta:
            - characters/NARRATOR.dossier/voice/NARRATOR.vox
      - character: HERO
        role: lead
        voicePrompt: "Younger adult voice, natural and slightly uncertain."
        provider: elevenlabs
      - character: VILLAIN
        role: supporting
        voicePrompt: "Silky, unhurried menace."
        bio: "Stays on VoxAlta."
        voices:
          voxalta:
            - voices/VILLAIN.vox
    ---
    Notes body.

    """

  static let projectText = """
    ---
    type: project
    title: synchronized-worlds
    author: Test
    created: 2026-01-01T00:00:00Z
    episodesDir: episodes
    filePattern: ["*.fountain"]
    ---
    """

  /// A fixture project on disk: NARRATOR has a long dialogue line; HERO has none.
  private func makeProject() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("voices-design-\(UUID().uuidString)")
    let fm = FileManager.default
    try fm.createDirectory(at: dir.appendingPathComponent("episodes"), withIntermediateDirectories: true)
    try Self.projectText.write(
      to: dir.appendingPathComponent("PROJECT.md"), atomically: true, encoding: .utf8)
    try Self.castText.write(
      to: dir.appendingPathComponent("CAST.md"), atomically: true, encoding: .utf8)
    let episode = """
      INT. SERVER ROOM - NIGHT

      NARRATOR
      Short.

      NARRATOR
      \(Self.narratorLine)

      """
    try episode.write(
      to: dir.appendingPathComponent("episodes/ep1.fountain"), atomically: true, encoding: .utf8)
    // NARRATOR's existing VoxAlta .vox, holding a qwen3-tts entry that must survive.
    let voxURL = dir.appendingPathComponent("characters/NARRATOR.dossier/voice/NARRATOR.vox")
    try fm.createDirectory(at: voxURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    var seed = VoiceAsset(name: "NARRATOR", description: "A seeded qwen3 voice for tests.")
    try seed.addSampleAudio(Data("qwen".utf8), engine: "qwen3-tts", model: "1.7b")
    try seed.write(to: voxURL)
    return dir
  }

  private func runner(
    _ dir: URL, backend: FakeElevenLabsBackend, characters: [String] = [], roles: [String] = [],
    sample: String? = nil, pick: String? = nil
  ) -> VoicesDesignRunner {
    VoicesDesignRunner(
      projectURL: dir.appendingPathComponent("PROJECT.md"), castName: "CAST.md",
      characters: characters, roles: roles, sampleTextOverride: sample,
      designModel: "eleven_multilingual_ttv_v2",
      candidatesDir: dir.appendingPathComponent("candidates").path, pick: pick, backend: backend,
      log: { _ in })
  }

  private func castRoster(_ dir: URL) throws -> [CastMember] {
    try CastMarkdownParser().parse(fileURL: dir.appendingPathComponent("CAST.md")).cast
  }

  // MARK: - design

  @Test("design writes preview WAVs and an index JSON, then stops")
  func designWritesCandidates() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeElevenLabsBackend()
    let sample = String(repeating: "Hero speaks at length here. ", count: 5)

    let outcome = try await runner(dir, backend: backend, sample: sample).run()

    #expect(outcome.designed == ["NARRATOR", "HERO"])  // VILLAIN has no provider: elevenlabs
    #expect(outcome.failures.isEmpty)
    let candidates = dir.appendingPathComponent("candidates")
    let index = try #require(try VoiceCandidateIndex.load(from: candidates))
    #expect(index.project == "synchronized-worlds")
    #expect(index.candidates.count == 6)
    for entry in index.candidates {
      let wav = try Data(contentsOf: candidates.appendingPathComponent(entry.previewFile))
      #expect(wav == FakeElevenLabsBackend.wav)
      #expect(entry.designModel == "eleven_multilingual_ttv_v2")
      #expect(!entry.promptSent.isEmpty)
    }
    // NARRATOR's sample is its own first 100-1,000 char episode line, not --sample-text.
    #expect(
      index.candidates.filter { $0.character == "NARRATOR" }.allSatisfy {
        $0.sampleText == Self.narratorLine
      })
    #expect(
      index.candidates.filter { $0.character == "HERO" }.allSatisfy { $0.sampleText == sample })
    // Nothing saved: no slot used, CAST.md untouched.
    #expect(!backend.events.contains { $0.hasPrefix("save") })
    #expect(try castRoster(dir) == CastMarkdownParser().parse(content: Self.castText).cast)
  }

  @Test("design errors naming the character when no sample text exists")
  func noSampleTextNamesCharacter() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeElevenLabsBackend()

    let outcome = try await runner(dir, backend: backend).run()  // no --sample-text

    #expect(outcome.designed == ["NARRATOR"])
    #expect(outcome.failures == [.noSampleText(character: "HERO")])
    #expect(outcome.failures.first?.localizedDescription.contains("HERO") == true)
  }

  @Test("a --role filter narrows the selection")
  func roleFilter() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let outcome = try await runner(dir, backend: FakeElevenLabsBackend(), roles: ["narrator"]).run()
    #expect(outcome.designed == ["NARRATOR"])
  }

  @Test("refuses when designs exceed free slots, naming the shortfall and fixes")
  func slotShortfall() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeElevenLabsBackend(limit: 10, used: 9)  // 1 free, 2 wanted

    do {
      _ = try await runner(dir, backend: backend, sample: String(repeating: "x", count: 120)).run()
      Issue.record("expected a slot-shortfall refusal")
    } catch let error as VoicesDesignError {
      #expect(
        error
          == .slotShortfall(
            needed: 2, free: 1, limit: 10, used: 9, characters: ["NARRATOR", "HERO"]))
      let text = error.localizedDescription
      #expect(text.contains("short by 1"))
      #expect(text.contains("VoxAlta"))
      #expect(text.contains("delete unused voices"))
    }
    #expect(backend.events.isEmpty, "no design call may be made on refusal")
  }

  @Test("a rejected prompt is a typed error naming the character, and the run continues")
  func rejectedPromptContinues() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeElevenLabsBackend()
    backend.rejectPromptsContaining = ["Deep authoritative"]

    let outcome = try await runner(
      dir, backend: backend, sample: String(repeating: "x", count: 120)
    ).run()

    #expect(outcome.designed == ["HERO"])
    guard case .designRejected(let character, _)? = outcome.failures.first else {
      Issue.record("expected designRejected")
      return
    }
    #expect(character == "NARRATOR")
  }

  // MARK: - pick

  private func designThenIndex(_ dir: URL, backend: FakeElevenLabsBackend) async throws
    -> VoiceCandidateIndex
  {
    _ = try await runner(dir, backend: backend, roles: ["narrator"]).run()
    return try #require(try VoiceCandidateIndex.load(from: dir.appendingPathComponent("candidates")))
  }

  @Test("pick writes the .vox extension, keeps qwen3 entries, and updates only one CAST.md member")
  func pickSaves() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeElevenLabsBackend()
    let index = try await designThenIndex(dir, backend: backend)
    let chosen = index.candidates[1]
    let before = try castRoster(dir)

    _ = try await runner(dir, backend: backend, pick: chosen.generatedVoiceId).run()

    let voxURL = dir.appendingPathComponent("characters/NARRATOR.dossier/voice/NARRATOR.vox")
    let asset = try VoiceAsset(contentsOf: voxURL)
    let fields = try #require(asset.extensionFields(forEngine: "elevenlabs"))
    #expect(fields["generated_voice_id"] as? String == chosen.generatedVoiceId)
    #expect((fields["voice_id"] as? String)?.hasPrefix("voice_") == true)
    #expect(fields["design_model"] as? String == "eleven_multilingual_ttv_v2")
    #expect(fields["description_sent"] as? String == chosen.promptSent)
    #expect(asset.entryPaths.contains { $0.hasPrefix("embeddings/qwen3-tts/") })
    #expect(asset.entryPaths.contains { $0.hasPrefix("embeddings/elevenlabs/") })
    #expect(backend.events.contains { $0.hasPrefix("save:synchronized-worlds — NARRATOR:") })

    let after = try castRoster(dir)
    #expect(after.count == before.count)
    for (old, new) in zip(before, after) where old.character != "NARRATOR" {
      #expect(old == new, "\(old.character) must be unchanged")
    }
    let narrator = try #require(after.first { $0.character == "NARRATOR" })
    #expect(
      narrator.voices["elevenlabs"] == ["characters/NARRATOR.dossier/voice/NARRATOR.vox"])
    #expect(narrator.voices["voxalta"] == ["characters/NARRATOR.dossier/voice/NARRATOR.vox"])
    #expect(try narrator[extra: "provider"]?.decode(String.self) == "elevenlabs")
  }

  @Test("pick creates a .vox when the character has none")
  func pickCreatesVox() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeElevenLabsBackend()
    _ = try await runner(dir, backend: backend, characters: ["HERO"], sample: String(repeating: "y", count: 150)).run()
    let index = try #require(try VoiceCandidateIndex.load(from: dir.appendingPathComponent("candidates")))

    _ = try await runner(dir, backend: backend, pick: index.candidates[0].generatedVoiceId).run()

    let voxURL = dir.appendingPathComponent("characters/HERO.dossier/voice/HERO.vox")
    #expect(FileManager.default.fileExists(atPath: voxURL.path))
    let hero = try #require(try castRoster(dir).first { $0.character == "HERO" })
    #expect(hero.voices["elevenlabs"] == ["characters/HERO.dossier/voice/HERO.vox"])
  }

  @Test("redesign deletes the old voice only after the new one is saved")
  func redesignDeletesAfterSave() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeElevenLabsBackend()
    var index = try await designThenIndex(dir, backend: backend)
    _ = try await runner(dir, backend: backend, pick: index.candidates[0].generatedVoiceId).run()
    let voxURL = dir.appendingPathComponent("characters/NARRATOR.dossier/voice/NARRATOR.vox")
    let oldId = try #require(
      try VoiceAsset(contentsOf: voxURL).extensionFields(forEngine: "elevenlabs")?["voice_id"]
        as? String)

    index = try await designThenIndex(dir, backend: backend)
    _ = try await runner(dir, backend: backend, pick: index.candidates[2].generatedVoiceId).run()

    let newId = try #require(
      try VoiceAsset(contentsOf: voxURL).extensionFields(forEngine: "elevenlabs")?["voice_id"]
        as? String)
    #expect(newId != oldId)
    let events = backend.events
    let saveSecond = try #require(events.lastIndex { $0.hasPrefix("save:") })
    let deleteOld = try #require(events.firstIndex(of: "delete:\(oldId)"))
    #expect(deleteOld > saveSecond, "old voice deleted before the new one was saved")
    #expect(events.filter { $0.hasPrefix("delete:") }.count == 1)
  }

  @Test("pick with an unknown generated_voice_id fails")
  func pickUnknownId() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeElevenLabsBackend()
    _ = try await designThenIndex(dir, backend: backend)
    await #expect(throws: VoicesDesignError.self) {
      _ = try await runner(dir, backend: backend, pick: "nope").run()
    }
  }
}
