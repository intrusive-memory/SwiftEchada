import Foundation
import Yams

/// The parts of PROJECT.md's `personaje:` block echada reads.
///
/// The block belongs to SwiftPersonaje (its REQUIREMENTS §5), and SwiftProyecto
/// doesn't model it, so it's decoded here straight from the front matter.
/// Unknown keys are ignored; a missing block means the defaults.
struct PersonajeSettings: Decodable, Equatable {
  /// Where character `.dossier` bundles live, relative to PROJECT.md
  /// (EC-23 rule 3). Defaults to `characters`.
  var charactersDir: String?

  var resolvedCharactersDir: String {
    guard let dir = charactersDir?.trimmingCharacters(in: .whitespaces), !dir.isEmpty else {
      return "characters"
    }
    return dir
  }

  private struct Envelope: Decodable {
    var personaje: PersonajeSettings?
  }

  /// Reads the settings from PROJECT.md text. A file with no front matter,
  /// or front matter that isn't a mapping, yields the defaults.
  static func read(content: String) throws -> PersonajeSettings {
    guard let yaml = frontMatter(of: content) else { return PersonajeSettings() }
    guard let envelope = try YAMLDecoder().decode(Envelope?.self, from: yaml) else {
      return PersonajeSettings()
    }
    return envelope.personaje ?? PersonajeSettings()
  }

  static func read(fileURL: URL) throws -> PersonajeSettings {
    try read(content: String(contentsOf: fileURL, encoding: .utf8))
  }

  /// The text between the opening `---` line and the next `---` line.
  private static func frontMatter(of content: String) -> String? {
    let lines = content.components(separatedBy: "\n")
    guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
    guard
      let close = lines.dropFirst().firstIndex(where: {
        $0.trimmingCharacters(in: .whitespaces) == "---"
      })
    else { return nil }
    return lines[1..<close].joined(separator: "\n")
  }
}
