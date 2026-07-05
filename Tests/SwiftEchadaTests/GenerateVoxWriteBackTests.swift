import Foundation
import SwiftProyecto
import Testing

@testable import EchadaCLICore

/// Regression coverage for issue #44 — `echada generate vox` must NOT destroy
/// non-cast content in PROJECT.md when it writes back `voices.voxalta` paths.
///
/// The bug: the write-back rebuilt `ProjectFrontMatter` field-by-field, dropping
/// every field it didn't explicitly copy — most damagingly `appSections`, the
/// catch-all that carries unknown top-level keys the user hand-maintains
/// (`episodes_index`, etc.). Those were silently deleted on every voice run.
///
/// The fix routes the write-back through `ProjectFrontMatter.withCast(_:)`, which
/// preserves all non-cast fields. These tests exercise the exact seam the command
/// uses (`GenerateVoxCommand.updatedFrontMatter(preserving:cast:)`) plus the
/// parser round-trip, offline, without loading any TTS model.
@Suite("GenerateVoxCommand write-back preserves PROJECT.md content (#44)")
struct GenerateVoxWriteBackTests {

  /// A PROJECT.md shaped like the real podcasts/* layout: a `cast:` block echada
  /// owns, plus a top-level `episodes_index:` list it does not own (and must keep).
  static let projectWithEpisodesIndex = """
    ---
    type: project
    title: Confessions
    author: Test Author
    created: 2026-01-01T00:00:00Z
    description: A hand-maintained project file with extra keys.
    cast:
      - character: THE PRACTITIONER
        voicePrompt: "A calm, deliberate voice."
        voices:
          voxalta: voices/PRACTITIONER.vox
    episodes_index:
      - id: ep-001
        title: The First Confession
      - id: ep-002
        title: The Second Confession
      - id: ep-003
        title: The Third Confession
    ---
    Body content stays too.
    """

  /// The write-back seam must keep the top-level `episodes_index` key and update
  /// only the cast — proving `appSections` survives the round-trip.
  @Test("Top-level episodes_index survives a cast write-back")
  func topLevelKeyPreserved() throws {
    let parser = ProjectMarkdownParser()
    let (frontMatter, body) = try parser.parse(content: Self.projectWithEpisodesIndex)

    // Simulate what run() does after generation: attach a freshly written .vox.
    let updatedCast = [
      CastMember(
        character: "THE PRACTITIONER",
        voiceDescription: "A calm, deliberate voice.",
        voices: ["voxalta": ["voices/PRACTITIONER.vox"]]
      )
    ]
    let updated = GenerateVoxCommand.updatedFrontMatter(
      preserving: frontMatter, cast: updatedCast)
    let output = parser.generate(frontMatter: updated, body: body)

    // The destroyed-on-write-back content must still be present.
    #expect(output.contains("episodes_index"), "episodes_index was dropped (#44 regression)")
    #expect(output.contains("ep-001"))
    #expect(output.contains("The Third Confession"))
    #expect(output.contains("Body content stays too."))
  }

  /// A full parse → update → re-parse cycle keeps episodes_index structurally
  /// intact and reflects the updated cast voice.
  @Test("Round-trip keeps episodes_index and applies the cast update")
  func roundTripPreservesAndUpdates() throws {
    let parser = ProjectMarkdownParser()
    let (frontMatter, body) = try parser.parse(content: Self.projectWithEpisodesIndex)

    let updatedCast = [
      CastMember(
        character: "THE PRACTITIONER",
        voiceDescription: "A calm, deliberate voice.",
        voices: ["voxalta": ["voices/PRACTITIONER-v2.vox"]]
      )
    ]
    let updated = GenerateVoxCommand.updatedFrontMatter(
      preserving: frontMatter, cast: updatedCast)
    let output = parser.generate(frontMatter: updated, body: body)

    let (reparsed, _) = try parser.parse(content: output)

    // Non-cast content preserved.
    #expect(reparsed.title == "Confessions")
    #expect(reparsed.description == "A hand-maintained project file with extra keys.")
    #expect(output.contains("episodes_index"))
    #expect(output.contains("ep-002"))

    // Cast update applied.
    #expect(reparsed.cast?.count == 1)
    #expect(reparsed.cast?.first?.voices["voxalta"] == ["voices/PRACTITIONER-v2.vox"])
  }
}
