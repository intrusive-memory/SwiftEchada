import Foundation
import SwiftProyecto
import Testing

@testable import EchadaCLICore

/// Regression coverage for issues #44 and #55 — the `generate` stages must not
/// destroy or corrupt non-cast content in PROJECT.md when they write back the
/// `cast:` block.
///
/// Two distinct failure modes, both now covered:
///
/// - **#55 — deletion.** Keys the hand-rolled emitter in
///   `ProjectMarkdownParser.generate` didn't know how to write (`introFile`,
///   `outroFile`) were dropped entirely.
/// - **#44 — corruption.** Unknown top-level keys captured into `appSections`
///   survived by *name* but lost their structure: a list of maps such as
///   `episodes_index` came back as an Objective-C `NSDictionary.description`
///   dump inside a YAML string.
///
/// The corruption mode is why the previous version of these tests passed while
/// the bug shipped: they asserted `output.contains("ep-001")`, and the mangled
/// form `- "{\n    id = ep-001;\n ...}"` still contains that substring. Every
/// assertion here therefore checks **structure after re-parsing**, or exact
/// line-level preservation — never bare substring presence.
@Suite("PROJECT.md cast write-back preserves non-cast content (#44, #55)")
struct GenerateVoxWriteBackTests {

  /// A PROJECT.md shaped like the real podcasts/* layout: a `cast:` block echada
  /// owns, plus content it does not own and must keep byte-for-byte —
  /// `introFile`/`outroFile` (#55), a nested `episodes_index` list-of-maps (#44),
  /// a per-member `bio`, and a comment.
  static let projectWithExtras = """
    ---
    type: project
    title: Confessions
    author: Test Author
    created: 2026-01-01T00:00:00Z
    description: A hand-maintained project file with extra keys.
    # This comment must survive the write-back.
    introFile: audio/intro.m4a
    outroFile: audio/outro.m4a
    cast:
      - character: THE PRACTITIONER
        voicePrompt: "A calm, deliberate voice."
        bio: "A hand-authored biography."
        voices:
          voxalta: voices/PRACTITIONER.vox
    episodes_index:
      - id: ep-001
        title: The First Confession
        keywords:
          - shame
          - ADHD
      - id: ep-002
        title: The Second Confession
    ---
    Body content stays too.
    """

  /// Applies a cast update through the real write-back seam the commands use.
  private func writeBack(_ cast: [CastMember], to source: String) throws -> String {
    try ProjectCastWriteBack.applying(cast: cast, to: source)
  }

  private var updatedCast: [CastMember] {
    [
      CastMember(
        character: "THE PRACTITIONER",
        voiceDescription: "A calm, deliberate voice.",
        voices: ["voxalta": ["voices/PRACTITIONER-v2.vox"]]
      )
    ]
  }

  /// #55: keys the emitter never knew how to write must still be present.
  @Test("introFile/outroFile survive a cast write-back (#55)")
  func introOutroPreserved() throws {
    let output = try writeBack(updatedCast, to: Self.projectWithExtras)
    let (reparsed, _) = try ProjectMarkdownParser().parse(content: output)

    #expect(reparsed.introFile == "audio/intro.m4a", "introFile was dropped (#55 regression)")
    #expect(reparsed.outroFile == "audio/outro.m4a", "outroFile was dropped (#55 regression)")
  }

  /// #44: the nested `episodes_index` must stay a **list of maps**, not become
  /// strings. This is the assertion the old substring-based test lacked.
  @Test("Nested episodes_index keeps its structure, not just its name (#44)")
  func nestedUnknownKeyStructurePreserved() throws {
    let output = try writeBack(updatedCast, to: Self.projectWithExtras)

    #expect(
      !output.contains("{\\n"),
      "episodes_index was flattened into an NSDictionary description dump (#44 regression)")

    // The list entries must still be indented YAML mappings.
    #expect(output.contains("  - id: ep-001"), "episodes_index entry lost its mapping form")
    #expect(output.contains("    title: The First Confession"))
    #expect(output.contains("      - shame"), "nested keywords list was flattened")
    #expect(output.contains("  - id: ep-002"))
  }

  /// The strongest guarantee: every line outside the `cast:` block is unchanged.
  @Test("Everything outside the cast block is byte-for-byte identical")
  func nonCastContentIsByteIdentical() throws {
    let output = try writeBack(updatedCast, to: Self.projectWithExtras)

    func linesOutsideCastBlock(_ text: String) -> [String] {
      var result: [String] = []
      var inCast = false
      for line in text.components(separatedBy: "\n") {
        if line.hasPrefix("cast:") {
          inCast = true
          continue
        }
        if inCast {
          // The block ends at the first line that isn't indented.
          if let first = line.first, first == " " || first == "\t" { continue }
          inCast = false
        }
        result.append(line)
      }
      return result
    }

    #expect(
      linesOutsideCastBlock(output) == linesOutsideCastBlock(Self.projectWithExtras),
      "content outside the cast block changed")
  }

  /// The comment must survive — proof the whole-file re-serialization path is gone.
  @Test("Inline comments survive the write-back")
  func commentPreserved() throws {
    let output = try writeBack(updatedCast, to: Self.projectWithExtras)
    #expect(output.contains("# This comment must survive the write-back."))
  }

  /// The cast update itself must actually be applied.
  @Test("Cast update is applied")
  func castUpdateApplied() throws {
    let output = try writeBack(updatedCast, to: Self.projectWithExtras)
    let (reparsed, _) = try ProjectMarkdownParser().parse(content: output)

    #expect(reparsed.cast?.count == 1)
    #expect(reparsed.cast?.first?.voices["voxalta"] == ["voices/PRACTITIONER-v2.vox"])
    #expect(reparsed.title == "Confessions")
  }

  /// Per-member unknown keys (`bio`) must round-trip.
  @Test("Per-member bio survives the write-back")
  func perMemberExtraKeyPreserved() throws {
    // Re-parse the source so the member carries its decoded `extraKeys`, then
    // write that same member back with an updated voice.
    let (frontMatter, _) = try ProjectMarkdownParser().parse(content: Self.projectWithExtras)
    guard let existing = frontMatter.cast?.first else {
      Issue.record("fixture cast failed to parse")
      return
    }
    // Mutating a struct copy keeps the decoded `extraKeys` (which carry `bio`).
    var updated = existing
    updated.voices = ["voxalta": ["voices/PRACTITIONER-v2.vox"]]

    let output = try writeBack([updated], to: Self.projectWithExtras)
    #expect(output.contains("bio:"), "per-member bio was dropped")
  }

  /// Running the write-back twice must be a no-op the second time.
  @Test("Write-back is idempotent")
  func idempotent() throws {
    let once = try writeBack(updatedCast, to: Self.projectWithExtras)
    let twice = try writeBack(updatedCast, to: once)
    #expect(once == twice, "write-back is not idempotent")
  }

  // MARK: - Blank lines inside the cast block (SwiftProyecto 4.8.1)

  /// A hand-maintained file that separates cast entries with a blank line —
  /// ordinary YAML style, and exactly what the #44/#55 population writes.
  static let projectWithBlankLineInCast = """
    ---
    type: project
    title: Confessions
    author: Test Author
    created: 2026-01-01T00:00:00Z
    cast:
      - character: THE PRACTITIONER
        voicePrompt: "A calm, deliberate voice."

      - character: THE PENITENT
        voicePrompt: "A hesitant, searching voice."
    episodes_index:
      - id: ep-001
        title: The First Confession
    ---
    Body content stays too.
    """

  /// The splice used to stop at the blank line, leaving every entry below it
  /// unreplaced but still indented. The re-rendered block was spliced in *above*
  /// those survivors, so re-parsing read them back as **duplicate** members.
  ///
  /// This is the seam `echada generate {cast,prompt,vox}` all write through, so
  /// the corruption was reachable from an ordinary cast run. Requires the fix in
  /// SwiftProyecto 4.8.1 — it fails against 4.6.1.
  @Test("A blank line between cast entries does not duplicate members")
  func blankLineInCastDoesNotDuplicate() throws {
    let (frontMatter, _) = try ProjectMarkdownParser().parse(
      content: Self.projectWithBlankLineInCast)
    let cast = try #require(frontMatter.cast)
    #expect(cast.count == 2, "fixture should parse as exactly two members")

    var updated = cast
    updated[1].voices = ["voxalta": ["voices/PENITENT.vox"]]

    let output = try writeBack(updated, to: Self.projectWithBlankLineInCast)
    let (reparsed, _) = try ProjectMarkdownParser().parse(content: output)

    #expect(
      (reparsed.cast ?? []).map(\.character) == ["THE PRACTITIONER", "THE PENITENT"],
      "cast was duplicated by the blank line")
    #expect(
      output.components(separatedBy: "- character: THE PENITENT").count - 1 == 1,
      "THE PENITENT must appear exactly once")

    // The unknown top-level key after the block must still survive intact.
    #expect(output.contains("  - id: ep-001"), "episodes_index lost its structure")
  }

  /// The write-back must also stay idempotent once blank lines are involved —
  /// a second pass over its own output must change nothing.
  @Test("Write-back over a blank-line cast block is idempotent")
  func blankLineWriteBackIsIdempotent() throws {
    let (frontMatter, _) = try ProjectMarkdownParser().parse(
      content: Self.projectWithBlankLineInCast)
    let cast = try #require(frontMatter.cast)

    let once = try writeBack(cast, to: Self.projectWithBlankLineInCast)
    let twice = try writeBack(cast, to: once)
    #expect(once == twice, "write-back is not idempotent across a blank line")
  }

  /// `GenerateCastCommand` stopped special-casing an empty merge and now passes
  /// `[]` straight through, relying on the splice to remove the block. Pin that
  /// behaviour here so the dependency cannot change it silently.
  @Test("An empty cast removes the block but keeps everything else")
  func emptyCastRemovesBlock() throws {
    let output = try writeBack([], to: Self.projectWithExtras)
    let (reparsed, _) = try ProjectMarkdownParser().parse(content: output)

    #expect(reparsed.cast?.isEmpty ?? true, "cast members should be gone")
    #expect(reparsed.introFile == "audio/intro.m4a", "introFile must survive")
    #expect(reparsed.outroFile == "audio/outro.m4a", "outroFile must survive")
    #expect(output.contains("  - id: ep-001"), "episodes_index must survive")
    #expect(output.contains("Body content stays too."))
  }
}
