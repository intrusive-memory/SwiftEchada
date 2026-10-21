import Foundation
import SwiftProyecto
import SwiftReparto
import Testing

/// The member type the legacy PROJECT.md `cast:` fixtures are built from.
///
/// SwiftProyecto 5 dropped its own `CastMember`, so legacy fixtures are now
/// written from SwiftReparto's, which serializes the same YAML keys.
typealias ProyectoCastMember = SwiftReparto.CastMember

extension SwiftReparto.CastMember {
  /// The SwiftProyecto 4.x initializer shape the fixtures were written with,
  /// where `voiceDescription` was the prompt's name.
  init(
    character: String, actor: String? = nil, voiceDescription: String?,
    voices: [String: [String]] = [:], language: String? = nil
  ) {
    self.init(
      character: character, actor: actor, language: language,
      voicePrompt: voiceDescription, voices: voices)
  }
}

/// Writes a pre-v5 PROJECT.md: `frontMatter` as SwiftProyecto emits it, plus
/// a legacy `cast:` block spliced in before the closing `---`.
enum LegacyProjectFixture {
  static func write(
    frontMatter: ProjectFrontMatter, cast: [SwiftReparto.CastMember]?, body: String = "",
    to url: URL
  ) throws {
    try ProjectMarkdownParser().write(frontMatter: frontMatter, body: body, to: url)
    guard let cast else { return }

    let scratch = url.deletingLastPathComponent()
      .appendingPathComponent("legacy-cast-\(UUID().uuidString).md")
    defer { try? FileManager.default.removeItem(at: scratch) }
    try CastMarkdownParser().write(document: CastDocument(cast: cast), to: scratch)
    let castMarkdown = try String(contentsOf: scratch, encoding: .utf8)
    let castLines = castMarkdown.components(separatedBy: "\n")
    let start = try #require(castLines.firstIndex { $0.hasPrefix("cast:") })
    let end = try #require(castLines[start...].firstIndex(of: "---"))

    var lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    let opening = try #require(lines.firstIndex(of: "---"))
    let closing = try #require(lines[(opening + 1)...].firstIndex(of: "---"))
    // Indent the members under `cast:`, as hand-written PROJECT.md files do.
    let block = [castLines[start]] + castLines[(start + 1)..<end].map { "  " + $0 }
    lines.insert(contentsOf: block, at: closing)
    try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
  }
}
