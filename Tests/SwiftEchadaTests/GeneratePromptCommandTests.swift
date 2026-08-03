import ArgumentParser
import Foundation
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// Covers the model-free validation gates of `GeneratePromptCommand.run()` —
/// everything reached before the Foundation Model availability check. Since
/// Sortie 7 the roster lives in CAST.md: the command reads it via SwiftReparto's
/// `CastMarkdownParser` and fails when it is absent (EC-14).
@Suite("GeneratePromptCommand.run — model-free branches")
struct GeneratePromptCommandTests {

  /// Minimal PROJECT.md — deliberately without any legacy `cast:` block; the
  /// roster belongs to CAST.md now.
  static let minimalProject = """
    ---
    type: project
    title: Prompt Fixture
    author: Test
    created: 2026-01-01T00:00:00Z
    ---
    """

  /// Writes a PROJECT.md (and, unless `castMembers` is nil, a CAST.md roster
  /// beside it) into a fresh per-test temp directory and returns PROJECT.md's
  /// URL. The caller removes the parent directory (`defer`).
  private func writeProject(castMembers: [SwiftReparto.CastMember]?) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("prompt-cmd-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("PROJECT.md")
    try Self.minimalProject.write(to: url, atomically: true, encoding: .utf8)
    if let castMembers {
      let castURL = dir.appendingPathComponent("CAST.md")
      try CastMarkdownParser().write(document: CastDocument(cast: castMembers), to: castURL)
    }
    return url
  }

  @Test("A missing project file is rejected")
  func missingProjectFileThrows() async throws {
    let missing = FileManager.default.temporaryDirectory
      .appendingPathComponent("does-not-exist-\(UUID().uuidString)")
      .appendingPathComponent("PROJECT.md")
    let cmd = try GeneratePromptCommand.parse(["--project", missing.path])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  @Test("A missing CAST.md fails, pointing at `echada generate cast`, and never creates it (EC-14)")
  func missingCastFileThrowsActionably() async throws {
    let url = try writeProject(castMembers: nil)
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let cmd = try GeneratePromptCommand.parse(["--project", url.path])
    do {
      try await cmd.run()
      Issue.record("expected a ValidationError for the missing CAST.md")
    } catch let error as ValidationError {
      #expect(error.message.contains("echada generate cast"))
    }
    // EC-14: the command must not have created the roster it failed over.
    let castURL = url.deletingLastPathComponent().appendingPathComponent("CAST.md")
    #expect(!FileManager.default.fileExists(atPath: castURL.path))
  }

  @Test("An empty CAST.md roster is rejected")
  func emptyRosterThrows() async throws {
    let url = try writeProject(castMembers: [])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let cmd = try GeneratePromptCommand.parse(["--project", url.path])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  @Test("An unknown --character is rejected against the CAST.md roster")
  func unknownCharacterThrows() async throws {
    let url = try writeProject(castMembers: [SwiftReparto.CastMember(character: "ALICE")])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let cmd = try GeneratePromptCommand.parse([
      "--project", url.path, "--character", "NOBODY", "--dry-run",
    ])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }

  @Test("--cast rejects values containing path separators (OQ-1)")
  func castOptionRejectsPathSeparators() async throws {
    let url = try writeProject(castMembers: [SwiftReparto.CastMember(character: "ALICE")])
    defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
    let cmd = try GeneratePromptCommand.parse([
      "--project", url.path, "--cast", "../CAST.md",
    ])
    await #expect(throws: ValidationError.self) { try await cmd.run() }
  }
}
