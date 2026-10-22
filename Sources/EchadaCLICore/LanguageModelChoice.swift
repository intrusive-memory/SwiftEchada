import ArgumentParser
import Foundation
import FoundationModels

/// Which language model writes echada's voice-design briefs.
///
/// Both choices run through Apple's FoundationModels framework, so the prompt,
/// the retry policy, and output normalization are identical regardless of where
/// inference happens:
///
/// - ``onDevice`` — the on-device `SystemLanguageModel` (the default). Nothing
///   leaves the Mac.
/// - ``privateCloud`` — Apple's server model through
///   `PrivateCloudComputeLanguageModel` (macOS 27+). No account or API key, but
///   the character's dialogue is sent to Private Cloud Compute.
///
/// Third-party providers (Claude, OpenAI, Gemini) will plug in here as further
/// cases backed by FoundationModels' `LanguageModel` protocol once a shared
/// credential layer exists to supply their keys.
public enum LanguageModelChoice: String, CaseIterable, Sendable, ExpressibleByArgument {
  case onDevice = "on-device"
  case privateCloud = "pcc"

  /// Human-readable name for status lines and error messages.
  public var displayName: String {
    switch self {
    case .onDevice: return "on-device Apple Foundation Model"
    case .privateCloud: return "Apple Private Cloud Compute"
    }
  }

  /// `nil` when the model is usable now; otherwise why it is not.
  var unavailableReason: String? {
    switch self {
    case .onDevice:
      guard SystemLanguageModel.default.isAvailable else {
        return """
          Apple Intelligence is not available on this device. Turn it on in \
          System Settings ▸ Apple Intelligence & Siri on a supported Apple silicon \
          Mac, or pass `--llm pcc` to use Apple Private Cloud Compute instead.
          """
      }
      return nil
    case .privateCloud:
      guard #available(macOS 27.0, iOS 27.0, *) else {
        return "Apple Private Cloud Compute requires macOS 27 or later."
      }
      switch PrivateCloudComputeLanguageModel().availability {
      case .available:
        return nil
      case .unavailable(.deviceNotEligible):
        return "This device is not eligible for Apple Private Cloud Compute."
      case .unavailable(.systemNotReady):
        return """
          Apple Private Cloud Compute is not ready yet. Make sure Apple Intelligence \
          is enabled and you are signed in to your Apple Account, then try again.
          """
      case .unavailable:
        return "Apple Private Cloud Compute is unavailable."
      }
    }
  }

  /// Generate a plain-text response in a fresh session.
  ///
  /// A new `LanguageModelSession` per call is deliberate: ``FoundationModelRetry``
  /// relies on a fresh session to clear transient failures.
  func respond(to prompt: String) async throws -> String {
    switch self {
    case .onDevice:
      return try await LanguageModelSession().respond(to: prompt).content
    case .privateCloud:
      guard #available(macOS 27.0, iOS 27.0, *) else {
        throw LanguageModelChoiceError.unavailable(
          choice: self, reason: "Apple Private Cloud Compute requires macOS 27 or later.")
      }
      let session = LanguageModelSession(model: PrivateCloudComputeLanguageModel())
      return try await session.respond(to: prompt).content
    }
  }
}

/// Raised when the selected language model cannot be used.
enum LanguageModelChoiceError: LocalizedError {
  case unavailable(choice: LanguageModelChoice, reason: String)

  var errorDescription: String? {
    switch self {
    case .unavailable(_, let reason):
      return reason
    }
  }
}
