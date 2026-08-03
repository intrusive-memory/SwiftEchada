import Foundation
import SwiftReparto
import Testing

/// Regression coverage for the CAST.md write-back call sequence the `generate`
/// stages use since the CAST.md extraction (EC-12, EC-18):
///
///     CastMarkdownParser().parse(fileURL:) → document.cast = updated
///         → parser.write(document:to:)
///
/// This is the same *class* of bug as issues #44 and #55 in the old PROJECT.md
/// write-back, where a field-by-field front-matter rebuild silently destroyed
/// or corrupted content the writer never knew about. SwiftReparto's own
/// round-trip tests prove its parser/writer pair is lossless; they do not prove
/// that **this repo's** read-modify-write sequence is — a stale cached parse, a
/// rebuild from `[CastMember]` alone, or an absolutized voice path would all
/// pass there and still corrupt files here. Every test below drives the exact
/// seam `GenerateVoxCommand.run()` (and `GeneratePromptCommand`) executes.
@Suite("CAST.md vox write-back preserves non-roster content (EC-18)")
struct GenerateVoxWriteBackTests {

  /// A CAST.md shaped like the real podcasts/* layout: a roster echada owns,
  /// plus content it does not own and must keep byte-for-byte — a per-member
  /// undeclared `bio:` key, and a hand-authored markdown body with formatting
  /// a rebuild-style writer would mangle.
  static let castMarkdownWithExtras = """
    ---
    type: cast
    schemaVersion: 1
    cast:
      - character: THE PRACTITIONER
        voicePrompt: "A calm, deliberate voice."
        bio: "A hand-authored biography."
        voices:
          voxalta: voices/PRACTITIONER.vox
      - character: THE PENITENT
        voicePrompt: "A hesitant, searching voice."
    ---
    ## Casting notes

    Hand-authored body — **markdown**, double  spaces, and a fenced block:

    ```text
    keep me byte-for-byte — em-dash and trailing colon included:
    ```

    """

  // MARK: - Helpers

  /// Writes the fixture into an isolated temp directory and returns its URL.
  /// Caller removes the directory via `defer`.
  private func makeCastFile(content: String = castMarkdownWithExtras) throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("vox-write-back-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let castURL = dir.appendingPathComponent("CAST.md")
    try content.write(to: castURL, atomically: true, encoding: .utf8)
    return castURL
  }

  /// The exact read-modify-write sequence `GenerateVoxCommand.run()` performs:
  /// parse from disk, replace the roster on the same document, write back
  /// through the one serializer allowed to emit CAST.md (D8).
  private func voxWriteBack(
    at castURL: URL,
    updating transform: (inout [CastMember]) -> Void
  ) throws -> String {
    let parser = CastMarkdownParser()
    var document = try parser.parse(fileURL: castURL)
    var roster = document.cast
    transform(&roster)
    document.cast = roster
    try parser.write(document: document, to: castURL)
    return try String(contentsOf: castURL, encoding: .utf8)
  }

  /// Records a freshly generated `.vox` on THE PRACTITIONER, exactly as the
  /// vox stage does after generation.
  private func recordVox(_ roster: inout [CastMember]) {
    for index in roster.indices where roster[index].character == "THE PRACTITIONER" {
      roster[index].voices = ["voxalta": ["voices/PRACTITIONER-v2.vox"]]
    }
  }

  /// The body region of a front-mattered file: every byte after the closing
  /// `---` delimiter line. Parser-free on purpose — the comparison is on file
  /// bytes, not on any type's idea of the body.
  private func bodyRegion(of text: String) throws -> Substring {
    let close = try #require(text.range(of: "\n---\n"), "expected a closing delimiter")
    return text[close.upperBound...]
  }

  // MARK: - EC-18: the call sequence preserves what it does not own

  /// The hand-authored markdown body must survive a vox write-back
  /// byte-for-byte.
  @Test("The markdown body survives a vox write-back byte-for-byte")
  func bodySurvivesWriteBack() throws {
    let castURL = try makeCastFile()
    defer { try? FileManager.default.removeItem(at: castURL.deletingLastPathComponent()) }

    let bodyBefore = try bodyRegion(of: Self.castMarkdownWithExtras)
    let output = try voxWriteBack(at: castURL, updating: recordVox)

    #expect(try bodyRegion(of: output) == bodyBefore, "CAST.md body region changed")
  }

  /// Per-member unknown keys (`bio`) must ride through the write-back inside
  /// `extraKeys`, exactly as they were.
  @Test("Per-member bio survives the write-back")
  func perMemberExtraKeyPreserved() throws {
    let castURL = try makeCastFile()
    defer { try? FileManager.default.removeItem(at: castURL.deletingLastPathComponent()) }

    let output = try voxWriteBack(at: castURL, updating: recordVox)

    let reparsed = try CastMarkdownParser().parse(content: output)
    let practitioner = try #require(reparsed.cast.first { $0.character == "THE PRACTITIONER" })
    let bio = try practitioner[extra: "bio"]?.decode(String.self)
    #expect(bio == "A hand-authored biography.", "per-member bio was dropped or rewritten")
  }

  /// The vox update itself must actually be applied — and only to the member
  /// it targets. The untouched member keeps every field.
  @Test("The vox update is applied, and untargeted members are untouched")
  func castUpdateAppliedWithoutCollateral() throws {
    let castURL = try makeCastFile()
    defer { try? FileManager.default.removeItem(at: castURL.deletingLastPathComponent()) }

    let output = try voxWriteBack(at: castURL, updating: recordVox)
    let reparsed = try CastMarkdownParser().parse(content: output)

    #expect(reparsed.cast.map(\.character) == ["THE PRACTITIONER", "THE PENITENT"])

    let practitioner = try #require(reparsed.cast.first { $0.character == "THE PRACTITIONER" })
    #expect(practitioner.voices["voxalta"] == ["voices/PRACTITIONER-v2.vox"])
    #expect(practitioner.voicePrompt == "A calm, deliberate voice.")

    let penitent = try #require(reparsed.cast.first { $0.character == "THE PENITENT" })
    #expect(penitent.voicePrompt == "A hesitant, searching voice.")
    #expect(penitent.voices.isEmpty)
  }

  /// `parse(fileURL:)` relativizes voice paths against CAST.md's directory
  /// (RQ-6/EC-16). The write-back must re-emit them CAST.md-relative — an
  /// absolutized path here would leak the temp directory into the file and
  /// break the file on any other machine.
  @Test("Voice paths stay CAST.md-relative through parse → write")
  func voicePathsStayRelative() throws {
    let castURL = try makeCastFile()
    defer { try? FileManager.default.removeItem(at: castURL.deletingLastPathComponent()) }

    // No roster change — the write-back alone must not rewrite the paths.
    let output = try voxWriteBack(at: castURL) { _ in }

    #expect(output.contains("voices/PRACTITIONER.vox"))
    #expect(
      !output.contains(castURL.deletingLastPathComponent().path),
      "a voice path was absolutized by the write-back")
  }

  /// Running the same write-back twice must be a no-op the second time —
  /// the guarantee that keeps repeated `generate vox` runs from producing
  /// spurious diffs in a committed CAST.md.
  @Test("The write-back is idempotent")
  func idempotent() throws {
    let castURL = try makeCastFile()
    defer { try? FileManager.default.removeItem(at: castURL.deletingLastPathComponent()) }

    let once = try voxWriteBack(at: castURL, updating: recordVox)
    let twice = try voxWriteBack(at: castURL, updating: recordVox)
    #expect(once == twice, "write-back is not idempotent")
  }

  /// `schemaVersion` and `type: cast` — front matter the vox stage never
  /// touches — must survive the write-back, or the re-written file stops
  /// being accepted as a cast document at all (RQ-1).
  @Test("type: cast and schemaVersion survive the write-back")
  func documentIdentitySurvives() throws {
    let castURL = try makeCastFile()
    defer { try? FileManager.default.removeItem(at: castURL.deletingLastPathComponent()) }

    let output = try voxWriteBack(at: castURL, updating: recordVox)

    // Re-parsing proves acceptance (a non-cast document throws), and the
    // version rides through unchanged.
    let reparsed = try CastMarkdownParser().parse(content: output)
    #expect(reparsed.schemaVersion == 1)
  }
}
