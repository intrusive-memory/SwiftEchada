import ArgumentParser
import CryptoKit
import Foundation
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// EC-11: the full migration round trip — seed CAST.md from the real 309-line
/// `confessions/PROJECT.md` fixture, verify clean, prune the legacy `cast:`
/// block — is lossless. The residual PROJECT.md must differ from the original
/// by exactly the `cast:` line span: `introFile`/`outroFile`, `tts`, and the
/// full `episodes_index` structure (the issue-#44/#55 loss classes) stay
/// byte-identical and in their original positions, with zero reordering.
@Suite("EC-11 — cast migration losslessness on the confessions fixture (offline)")
struct CastMigrationLosslessnessTests {

  /// A script whose CHARACTER cues cover exactly the three legacy cast
  /// members — no extras, so the seeded CAST.md and the legacy `cast:` block
  /// agree and verification passes with zero divergences.
  static let confessionsScript = """
    INT. THE WIRE - NIGHT

    A cursor blinks in the dark.

    NARRATOR
    In the beginning, there was the terminal.

    THE PRACTITIONER
    Did I break the build again?

    ESPECTRO FAMILIAR
    The build was never whole, apprentice.
    """

  /// Copies the confessions fixture into a fresh temp project directory as
  /// PROJECT.md, with an `episodes/` folder containing `confessionsScript`
  /// and a `voices/` folder holding a dummy `.vox` for each legacy pointer
  /// (so verification's dangling-path class stays clean). Returns the
  /// PROJECT.md URL; caller removes the directory via `defer`.
  private func makeConfessionsProject() throws -> URL {
    let fixture = try #require(
      Bundle.module.url(
        forResource: "confessions-PROJECT",
        withExtension: "md",
        subdirectory: "Fixtures"))

    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("cast-losslessness-\(UUID().uuidString)")
    let episodesDir = dir.appendingPathComponent("episodes")
    try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
    try Self.confessionsScript.write(
      to: episodesDir.appendingPathComponent("ep1.fountain"), atomically: true, encoding: .utf8)

    let voicesDir = dir.appendingPathComponent("voices")
    try FileManager.default.createDirectory(at: voicesDir, withIntermediateDirectories: true)
    for vox in ["NARRATOR.vox", "ESPECTRO_FAMILIAR.vox", "THE_PRACTITIONER.vox"] {
      try Data("vox".utf8).write(to: voicesDir.appendingPathComponent(vox))
    }

    let projectURL = dir.appendingPathComponent("PROJECT.md")
    try FileManager.default.copyItem(at: fixture, to: projectURL)
    return projectURL
  }

  private func sha256(of url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  /// The line-index range of the top-level `cast:` block: the `cast:` line
  /// plus the contiguous run of indented lines under it.
  private static func castLineSpan(in lines: [String]) -> Range<Int>? {
    guard let start = lines.firstIndex(where: { $0.hasPrefix("cast:") }) else { return nil }
    var end = start + 1
    while end < lines.count, let first = lines[end].first, first == " " || first == "\t" {
      end += 1
    }
    return start..<end
  }

  /// The line span starting at the line exactly equal to `header` plus the
  /// contiguous indented run under it (e.g. the whole `episodes_index:`
  /// structure).
  private static func lineSpan(header: String, in lines: [String]) -> [String]? {
    guard let start = lines.firstIndex(of: header) else { return nil }
    var end = start + 1
    while end < lines.count, let first = lines[end].first, first == " " || first == "\t" {
      end += 1
    }
    return Array(lines[start..<end])
  }

  @Test("Seed → verify → prune: residual PROJECT.md differs only by the cast: line span")
  func migrationRoundTripIsLossless() async throws {
    let projectURL = try makeConfessionsProject()
    defer { try? FileManager.default.removeItem(at: projectURL.deletingLastPathComponent()) }
    let castURL = projectURL.deletingLastPathComponent().appendingPathComponent("CAST.md")

    let original = try String(contentsOf: projectURL, encoding: .utf8)
    let originalLines = original.components(separatedBy: "\n")

    // --- Step 1: seed CAST.md from the legacy cast: block.
    try await GenerateCastCommand.parse(["--project", projectURL.path]).run()

    // Every cast field survived into CAST.md, including bio via extraKeys.
    let document = try CastMarkdownParser().parse(fileURL: castURL)
    #expect(
      document.cast.map(\.character) == ["NARRATOR", "ESPECTRO FAMILIAR", "THE PRACTITIONER"])
    let byName = Dictionary(uniqueKeysWithValues: document.cast.map { ($0.character, $0) })
    for member in document.cast {
      #expect(member.voicePrompt?.isEmpty == false, "\(member.character) voicePrompt")
    }
    #expect(byName["NARRATOR"]?.voices == ["voxalta": ["voices/NARRATOR.vox"]])
    #expect(byName["ESPECTRO FAMILIAR"]?.voices == ["voxalta": ["voices/ESPECTRO_FAMILIAR.vox"]])
    #expect(
      byName["THE PRACTITIONER"]?.voices == ["voxalta": ["voices/THE_PRACTITIONER.vox"]])
    let bio = try byName["THE PRACTITIONER"]?[extra: "bio"]?.decode(String.self)
    #expect(bio?.hasPrefix("Neurodivergent (ADHD), gay Gen X developer") == true)

    // --- Step 2: verification is clean.
    let divergences = try VerifyCastCommand.collectDivergences(
      projectURL: projectURL, castName: "CAST.md")
    #expect(divergences.isEmpty)
    try await VerifyCastCommand.parse(["--project", projectURL.path]).run()

    // --- Step 3: prune the legacy cast: block.
    let castShaBefore = try sha256(of: castURL)
    try await PruneCastCommand.parse(["--project", projectURL.path]).run()

    let residual = try String(contentsOf: projectURL, encoding: .utf8)
    let residualLines = residual.components(separatedBy: "\n")

    // The residual differs from the original by exactly the cast: line span —
    // byte-for-byte equality against the original with that span spliced out.
    let castSpan = try #require(Self.castLineSpan(in: originalLines))
    var expectedLines = originalLines
    expectedLines.removeSubrange(castSpan)
    #expect(residual == expectedLines.joined(separator: "\n"))

    // No cast: key survives, at any indentation depth's top level.
    #expect(!residualLines.contains { $0.hasPrefix("cast:") })

    // The emitter-forgotten keys (issue #44) are intact — same bytes, same
    // positions (they precede the cast block, so their indexes are unchanged).
    for key in ["introFile: audio/intro.m4a", "outroFile: audio/outro.m4a"] {
      #expect(residualLines.firstIndex(of: key) == originalLines.firstIndex(of: key), "\(key)")
    }

    // The appSections keys (issue #55) are intact: tts and the full
    // episodes_index structure are byte-identical, in original order, shifted
    // up by exactly the removed span — zero lines changed, zero reordering.
    let originalTts = try #require(Self.lineSpan(header: "tts:", in: originalLines))
    let residualTts = try #require(Self.lineSpan(header: "tts:", in: residualLines))
    #expect(originalTts == residualTts)
    #expect(originalTts == ["tts:", "  model: 1.7b"])

    let originalEpisodes = try #require(
      Self.lineSpan(header: "episodes_index:", in: originalLines))
    let residualEpisodes = try #require(
      Self.lineSpan(header: "episodes_index:", in: residualLines))
    #expect(originalEpisodes == residualEpisodes)
    #expect(originalEpisodes.filter { $0.hasPrefix("  - number:") }.count == 69)

    let originalIndex = try #require(originalLines.firstIndex(of: "episodes_index:"))
    let residualIndex = try #require(residualLines.firstIndex(of: "episodes_index:"))
    #expect(residualIndex == originalIndex - castSpan.count)

    // Prune never writes CAST.md.
    #expect(try sha256(of: castURL) == castShaBefore)

    // --- Step 4: a second prune is a clean, zero-exit no-op.
    let residualSha = try sha256(of: projectURL)
    try await PruneCastCommand.parse(["--project", projectURL.path]).run()
    #expect(try sha256(of: projectURL) == residualSha)
  }
}
