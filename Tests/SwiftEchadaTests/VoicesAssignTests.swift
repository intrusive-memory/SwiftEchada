import Foundation
import SwiftReparto
import Testing

@testable import EchadaCLICore

@Suite("echada voices assign — mocked API")
struct VoicesAssignTests {

  static let castText = """
    ---
    type: cast
    schemaVersion: 1
    cast:
      - character: NARRATOR
        role: narrator
        voicePrompt: "Deep British baritone."
        voices:
          voxalta:
            - characters/NARRATOR.dossier/voice/NARRATOR.vox
      - character: HERO
        role: lead
        voicePrompt: "Younger adult voice."
        provider: voxalta
    ---
    Notes body.

    """

  private func makeProject() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("voices-assign-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try "---\ntype: project\ntitle: sw\nauthor: T\ncreated: 2026-01-01T00:00:00Z\n---\n".write(
      to: dir.appendingPathComponent("PROJECT.md"), atomically: true, encoding: .utf8)
    try Self.castText.write(
      to: dir.appendingPathComponent("CAST.md"), atomically: true, encoding: .utf8)
    return dir
  }

  private func runner(
    _ dir: URL, backend: FakeElevenLabsBackend, voiceId: String,
    character: String = "NARRATOR", provider: String = "elevenlabs"
  ) -> VoicesAssignRunner {
    VoicesAssignRunner(
      projectURL: dir.appendingPathComponent("PROJECT.md"), castName: "CAST.md",
      character: character, provider: provider, voiceId: voiceId, backend: backend, log: { _ in })
  }

  private func roster(_ dir: URL) throws -> [CastMember] {
    try CastMarkdownParser().parse(fileURL: dir.appendingPathComponent("CAST.md")).cast
  }

  @Test("a 404 id fails naming the id and leaves CAST.md untouched")
  func notFoundFails() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let before = try String(contentsOf: dir.appendingPathComponent("CAST.md"), encoding: .utf8)
    let backend = FakeElevenLabsBackend()
    do {
      try await runner(dir, backend: backend, voiceId: "nope123").run()
      Issue.record("expected failure")
    } catch let error as VoicesAssignError {
      #expect(error == .voiceNotFound(id: "nope123"))
      #expect(error.localizedDescription.contains("nope123"))
    }
    let after = try String(contentsOf: dir.appendingPathComponent("CAST.md"), encoding: .utf8)
    #expect(before == after)
  }

  @Test("a valid id lands as a bare string under voices.elevenlabs; others unchanged")
  func validIdWritten() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeElevenLabsBackend()
    backend.knownVoiceIds = ["21m00Tcm4TlvDq8ikWAM"]
    let before = try roster(dir)

    try await runner(dir, backend: backend, voiceId: "21m00Tcm4TlvDq8ikWAM").run()

    let after = try roster(dir)
    let narrator = try #require(after.first { $0.character == "NARRATOR" })
    #expect(narrator.voices["elevenlabs"] == ["21m00Tcm4TlvDq8ikWAM"])
    #expect(narrator.voices["voxalta"] == ["characters/NARRATOR.dossier/voice/NARRATOR.vox"])
    #expect(try narrator[extra: "provider"]?.decode(String.self) == "elevenlabs")
    for (old, new) in zip(before, after) where old.character != "NARRATOR" {
      #expect(old == new)
    }
    let text = try String(contentsOf: dir.appendingPathComponent("CAST.md"), encoding: .utf8)
    #expect(text.contains("21m00Tcm4TlvDq8ikWAM"))
    #expect(!text.contains("elevenlabs://"))
  }

  @Test("an elevenlabs:// input is normalized to the bare id before validation")
  func uriNormalized() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeElevenLabsBackend()
    backend.knownVoiceIds = ["abc123"]
    try await runner(
      dir, backend: backend, voiceId: "elevenlabs://abc123?lang=en", character: "hero"
    ).run()
    #expect(backend.events == ["validate:abc123"])
    let hero = try #require(try roster(dir).first { $0.character == "HERO" })
    #expect(hero.voices["elevenlabs"] == ["abc123"])
    #expect(try hero[extra: "provider"]?.decode(String.self) == "elevenlabs")
  }

  @Test("an unsupported provider and an unknown character fail before any API call")
  func earlyFailures() async throws {
    let dir = try makeProject()
    defer { try? FileManager.default.removeItem(at: dir) }
    let backend = FakeElevenLabsBackend()
    await #expect(throws: VoicesAssignError.unsupportedProvider("voxalta")) {
      try await runner(dir, backend: backend, voiceId: "x", provider: "voxalta").run()
    }
    await #expect(throws: VoicesAssignError.self) {
      try await runner(dir, backend: backend, voiceId: "x", character: "GHOST").run()
    }
    #expect(backend.events.isEmpty)
  }
}
