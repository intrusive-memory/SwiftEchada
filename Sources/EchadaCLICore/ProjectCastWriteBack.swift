import Foundation
import SwiftProyecto

/// Surgical `cast:` write-back into PROJECT.md, shared by the three `generate`
/// stages (`cast`, `prompt`, `vox`).
///
/// All three stages mutate **only** the `cast:` block, so all three must leave
/// every other byte of the file untouched. Re-serializing the whole front matter
/// from the typed model does not achieve that: `ProjectMarkdownParser.generate`
/// is a hand-rolled, field-by-field YAML emitter, and anything it does not know
/// how to write is lost or mangled on the way out.
///
/// Two failure modes were observed in production (issues #44 and #55):
///
/// - Keys the emitter forgot entirely were **deleted** (`introFile`/`outroFile`).
/// - Unknown top-level keys captured into `appSections` survived by *name* but
///   had their structure **corrupted**: a nested value such as `episodes_index`
///   (a list of maps) round-tripped through `AnyCodable` into an
///   Objective-C `NSDictionary.description` dump crammed into a YAML string —
///   `- "{\n    id = ep01;\n    title = \"First Episode\";\n}"`. Still valid
///   YAML, still containing the original substrings, but no longer the structure
///   it started as. On a real 309-line project file this reduced it to 103 lines.
///
/// Routing through ``ProjectMarkdownParser/replacingCastBlock(in:with:)`` avoids
/// both by construction: it splices the `cast:` line span in the original text
/// and copies everything else verbatim, so unknown keys, key ordering, comments,
/// and spacing are preserved exactly.
enum ProjectCastWriteBack {

  /// Applies `cast` to `original` PROJECT.md text, changing only the `cast:` block.
  ///
  /// - Parameters:
  ///   - cast: The cast list to write. Pass an empty array to remove the block.
  ///   - original: The complete, original PROJECT.md text.
  ///   - parser: Parser supplying the splice implementation.
  /// - Returns: New file text identical to `original` outside the `cast:` block.
  static func applying(
    cast: [CastMember],
    to original: String,
    using parser: ProjectMarkdownParser = ProjectMarkdownParser()
  ) throws -> String {
    try parser.replacingCastBlock(in: original, with: cast)
  }

  /// Reads `fileURL`, splices in `cast`, and writes the result back atomically.
  ///
  /// The file is re-read here rather than reusing text captured earlier, so the
  /// splice applies to what is on disk at write time. Note the scope of that
  /// guarantee: it protects everything *outside* the `cast:` block from edits
  /// made while the command was running. The `cast` argument itself was derived
  /// from a parse taken much earlier, so a concurrent edit *inside* the cast
  /// block is still overwritten.
  static func write(
    cast: [CastMember],
    to fileURL: URL,
    using parser: ProjectMarkdownParser = ProjectMarkdownParser()
  ) throws {
    let original = try String(contentsOf: fileURL, encoding: .utf8)
    let updated = try applying(cast: cast, to: original, using: parser)
    try updated.write(to: fileURL, atomically: true, encoding: .utf8)
  }
}
