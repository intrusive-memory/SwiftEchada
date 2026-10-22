import Foundation
import FoundationModels
import SwiftLlavero

/// Resolves `--llm` to a FoundationModels model through SwiftLlavero.
///
/// Every choice runs through the same `LanguageModelSession` API, so the
/// prompt, the retry policy, and output normalization are identical wherever
/// inference happens:
///
/// - `on-device` (default) — Apple's on-device model. Nothing leaves the Mac.
/// - `pcc` — Apple Private Cloud Compute (no account or key).
/// - `account:model` — any provider configured with `echada auth login`
///   (`anthropic:claude-sonnet-5-5`, `openai:gpt-5.6`, `gemini`, `ollama:llama3.3`).
///
/// Off-device choices send the character's dialogue to that provider.
enum LanguageModelResolver {

  /// Resolves `reference`, failing fast with a message that names the
  /// selected model. Call before any per-character work.
  static func resolve(
    _ reference: ModelReference, llavero: Llavero = .standard
  ) async throws -> any LanguageModel {
    do {
      return try await llavero.model(reference)
    } catch let error as LlaveroError {
      throw VoicePromptSynthesizerError.modelUnavailable(
        reference, reason: error.localizedDescription)
    }
  }

  /// `true` when the reference keeps inference on this Mac.
  static func isOnDevice(_ reference: ModelReference) -> Bool {
    reference == .onDevice
  }
}
