import Foundation
import SwiftProyecto
import Testing

@testable import EchadaCLICore

/// Regression coverage for the PROJECT.md write-back data-loss bug
/// (intrusive-memory/SwiftEchada#55, same root cause as #44).
///
/// The bug: `echada generate vox` rebuilt PROJECT.md by re-emitting the whole
/// frontmatter from the typed model. The hand-rolled emitter dropped every key
/// it did not explicitly list — first `appSections` (#44), then the known-but-
/// unemitted `introFile`/`outroFile` keys (#55) — silently deleting that content
/// on every voice run.
///
/// The fix routes the write-back through the surgical
/// `ProjectMarkdownParser.replacingCastBlock(in:with:)`, which mutates ONLY the
/// `cast:` block and leaves every other byte identical. These tests exercise that
/// exact seam offline, without loading any TTS model.
@Suite("GenerateVox write-back preserves PROJECT.md content (#55, #44)")
struct GenerateVoxWriteBackTests {

  /// A PROJECT.md shaped like the real podcasts/* layout: a `cast:` block echada
  /// owns, plus content it does NOT own and must keep — `introFile`/`outroFile`
  /// (the #55 loss), a top-level `episodes_index:` list (#44), and a body.
  static let projectWithExtras = """
    ---
    type: project
    title: Confessions
    author: Test Author
    created: 2026-01-01T00:00:00Z
    description: A hand-maintained project file with extra keys.
    cast:
      - character: THE PRACTITIONER
        voicePrompt: A calm deliberate voice
        voices:
          voxalta: voices/PRACTITIONER.vox
    introFile: intro.fountain
    outroFile: outro.fountain
    episodes_index:
      - id: ep-001
        title: The First Confession
      - id: ep-002
        title: The Second Confession
    ---
    Body content stays too.
    """

  /// The surgical write-back must keep `introFile`/`outroFile`, the top-level
  /// `episodes_index`, and the body while updating only the cast voice.
  @Test("intro/outro + episodes_index survive a cast write-back")
  func nonCastContentPreserved() throws {
    let parser = ProjectMarkdownParser()

    let updatedCast = [
      CastMember(
        character: "THE PRACTITIONER",
        voiceDescription: "A calm deliberate voice",
        voices: ["voxalta": ["voices/PRACTITIONER-v2.vox"]]
      )
    ]

    let output = try parser.replacingCastBlock(in: Self.projectWithExtras, with: updatedCast)

    // The #55 loss — these must survive.
    #expect(output.contains("introFile: intro.fountain"), "introFile dropped (#55 regression)")
    #expect(output.contains("outroFile: outro.fountain"), "outroFile dropped (#55 regression)")
    // The #44 loss — still preserved.
    #expect(output.contains("episodes_index"), "episodes_index dropped (#44 regression)")
    #expect(output.contains("ep-002"))
    #expect(output.contains("Body content stays too."))

    // The cast update landed.
    let (reparsed, _) = try parser.parse(content: output)
    #expect(reparsed.cast?.first?.voices["voxalta"] == ["voices/PRACTITIONER-v2.vox"])
    #expect(reparsed.introFile == "intro.fountain")
    #expect(reparsed.outroFile == "outro.fountain")
  }

  /// Byte-level guarantee: only the `voices` line under the cast changes; every
  /// other line — including introFile/outroFile — is byte-identical.
  @Test("Only the cast voice line changes; all other bytes identical")
  func onlyCastBytesChange() throws {
    let parser = ProjectMarkdownParser()
    let updatedCast = [
      CastMember(
        character: "THE PRACTITIONER",
        voiceDescription: "A calm deliberate voice",
        voices: ["voxalta": ["voices/PRACTITIONER-v2.vox"]]
      )
    ]

    let output = try parser.replacingCastBlock(in: Self.projectWithExtras, with: updatedCast)

    let originalLines = Self.projectWithExtras.components(separatedBy: "\n")
    let updatedLines = output.components(separatedBy: "\n")
    #expect(originalLines.count == updatedLines.count)

    let changed = zip(originalLines, updatedLines).filter { $0 != $1 }
    #expect(changed.count == 1, "exactly one line should differ; got \(changed)")
    #expect(changed.first?.0 == "      voxalta: voices/PRACTITIONER.vox")
    #expect(changed.first?.1 == "      voxalta: voices/PRACTITIONER-v2.vox")
  }
}
