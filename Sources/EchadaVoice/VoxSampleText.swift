import CryptoKit
import Foundation
@preconcurrency import VoxFormat

/// The words each embedded qwen3-tts sample speaks (#70).
///
/// vox-format's embedding entries have no transcript field, so echada keeps
/// the text in its own extension namespace, keyed by the SHA-256 of the
/// sample's audio bytes:
///
/// ```json
/// "extensions": { "echada": { "sample_text": { "<sha256 of the WAV>": "The North Wind…" } } }
/// ```
///
/// Keying by content rather than archive path means the text can never be
/// attributed to different audio: a sample replaced by a writer that didn't
/// record its text simply has no text. Readers that don't know the `echada`
/// namespace ignore it (vox-format: unknown extensions MUST be ignored).
package enum VoxSampleText {
  static let namespace = "echada"
  static let key = "sample_text"

  /// Records that the sample audio `audio` speaks `text`. Drops entries whose
  /// audio is no longer embedded in `vox`, so regenerations don't accumulate.
  package static func record(_ text: String, forSample audio: Data, in vox: VoxFile) {
    var ours = vox.manifest.extensions?[namespace]?.value as? [String: Any] ?? [:]
    var texts = ours[key] as? [String: Any] ?? [:]
    texts[digest(audio)] = text
    let embedded = Set(
      vox.entries(under: "embeddings/").filter { $0.path.contains("sample-audio") }
        .map { digest($0.data) }
    ).union([digest(audio)])
    texts = texts.filter { embedded.contains($0.key) }
    ours[key] = texts
    var extensions = vox.manifest.extensions ?? [:]
    extensions[namespace] = AnyCodable(ours)
    vox.manifest.extensions = extensions
  }

  /// The words `audio` speaks, if echada recorded them when it embedded it.
  /// `nil` for samples embedded before #70 was fixed, or by other tools.
  package static func text(forSample audio: Data, in vox: VoxFile) -> String? {
    let ours = vox.manifest.extensions?[namespace]?.value as? [String: Any]
    let text = (ours?[key] as? [String: Any])?[digest(audio)] as? String
    return text?.isEmpty == false ? text : nil
  }

  static func digest(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
