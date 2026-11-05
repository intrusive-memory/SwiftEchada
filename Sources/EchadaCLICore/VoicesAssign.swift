import Foundation
import SwiftProyecto
import SwiftReparto

/// Typed failures of `echada voices assign` (EL-4.7).
enum VoicesAssignError: LocalizedError, Equatable {
  case unsupportedProvider(String)
  case emptyVoiceId
  case voiceNotFound(id: String)
  case unknownCharacter(String, available: [String])
  case castNotFound(String)

  var errorDescription: String? {
    switch self {
    case .unsupportedProvider(let provider):
      return "Unsupported provider '\(provider)'; `voices assign` supports only `elevenlabs`."
    case .emptyVoiceId:
      return "--voice-id is empty."
    case .voiceNotFound(let id):
      return "ElevenLabs has no voice with id '\(id)' (GET /v1/voices/\(id) returned 404)."
    case .unknownCharacter(let name, let available):
      return
        "Character '\(name)' not found in CAST.md. Available: \(available.joined(separator: ", "))"
    case .castNotFound(let path):
      return "Cast file not found: \(path)"
    }
  }
}

/// The work of `echada voices assign`, with the ElevenLabs seam injected so tests run offline.
struct VoicesAssignRunner {
  var projectURL: URL
  var castName: String
  var character: String
  var provider: String
  var voiceId: String
  /// `--switch`: also set `provider: elevenlabs`. Default is additive (voices only).
  var switchProvider: Bool = false
  var backend: any ElevenLabsBackend
  var log: @Sendable (String) -> Void = { print($0) }

  /// `elevenlabs://<id>[?query]` and bare ids both normalize to the bare id (EL-3.1).
  static func normalize(_ input: String) -> String {
    var id = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let scheme = "\(ElevenLabsProviderID.value)://"
    if id.lowercased().hasPrefix(scheme) { id = String(id.dropFirst(scheme.count)) }
    if let q = id.firstIndex(where: { $0 == "?" || $0 == "#" }) { id = String(id[..<q]) }
    return id.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  }

  func run() async throws {
    guard provider.lowercased() == ElevenLabsProviderID.value else {
      throw VoicesAssignError.unsupportedProvider(provider)
    }
    let id = Self.normalize(voiceId)
    guard !id.isEmpty else { throw VoicesAssignError.emptyVoiceId }

    let castURL = try CastFile.resolve(
      named: castName, in: projectURL.deletingLastPathComponent())
    guard FileManager.default.fileExists(atPath: castURL.path) else {
      throw VoicesAssignError.castNotFound(castURL.path)
    }
    let parser = CastMarkdownParser()
    var document = try parser.parse(fileURL: castURL)
    guard
      let at = document.cast.firstIndex(where: {
        $0.character.localizedCaseInsensitiveCompare(character) == .orderedSame
      })
    else {
      throw VoicesAssignError.unknownCharacter(character, available: document.cast.map(\.character))
    }

    // Validate before touching CAST.md.
    try await backend.validateVoice(id: id)

    document.cast[at].voices[ElevenLabsProviderID.value] = [id]
    if switchProvider {
      document.cast[at].setExtra(try AnyCodable(ElevenLabsProviderID.value), forKey: "provider")
    }
    try parser.write(document: document, to: castURL)
    log("\(document.cast[at].character): assigned ElevenLabs voice \(id)")
  }
}
