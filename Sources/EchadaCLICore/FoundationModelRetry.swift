import Foundation
import FoundationModels

/// Runs an on-device Foundation Model text generation with bounded retry.
///
/// The system model occasionally fails a single request transiently — most
/// commonly with *"Failed to deserialize a Generable type from model output"*,
/// which FoundationModels raises even for plain-string `respond(to:)` calls
/// because it round-trips the output through an internal `Generable`
/// representation. These failures clear on a **fresh** `LanguageModelSession`,
/// so they must never abort a whole cast run: echada sources every audition
/// sentence and voice prompt from this model with no curated fallback, so a
/// lone flaky character among many would otherwise take the entire pipeline
/// down.
///
/// Callers pass their own `sanitize` so retries also cover the "model returned
/// something, but nothing usable survived normalization" case — that is just as
/// transient as an outright throw.
enum FoundationModelRetry {

  /// Total generation attempts before surfacing a hard failure. A fresh session
  /// is created for each attempt.
  static let maxAttempts = 4

  /// Generate a response to `prompt`, retrying transient failures, and return
  /// the first sanitized result that survives.
  ///
  /// A new `LanguageModelSession` is created on every attempt (a stale session
  /// is a common cause of repeat deserialization failures). Both a thrown error
  /// and a `nil` from `sanitize` count as a retryable miss.
  ///
  /// - Parameters:
  ///   - prompt: The instruction handed to the model.
  ///   - sanitize: Normalizes raw model output into a usable string, or `nil`
  ///     when nothing usable remains.
  /// - Returns: `(result, lastError)` — `result` is the first usable string, or
  ///   `nil` if every attempt missed. `lastError` carries the final underlying
  ///   FoundationModels error (if the last miss was a throw) so the caller can
  ///   surface the real cause; it is `nil` when the last miss was empty output.
  static func sanitizedResponse(
    to prompt: String,
    sanitize: (String) -> String?
  ) async -> (result: String?, lastError: Error?) {
    await sanitizedResponse(
      maxAttempts: maxAttempts,
      sanitize: sanitize,
      backoff: Self.defaultBackoff,
      generate: { try await LanguageModelSession().respond(to: prompt).content }
    )
  }

  /// Testable retry core. Identical control flow to the public entry point but
  /// with the model call, attempt count, and backoff injected so the
  /// retry/return contract can be exercised without Apple Intelligence.
  ///
  /// - Parameters:
  ///   - maxAttempts: Number of generation attempts (must be >= 1).
  ///   - sanitize: Normalizes raw output, or returns `nil` for a retryable miss.
  ///   - backoff: Awaited between attempts (never after the final attempt).
  ///   - generate: Produces raw model output; a throw is a retryable miss.
  static func sanitizedResponse(
    maxAttempts: Int,
    sanitize: (String) -> String?,
    backoff: (Int) async -> Void,
    generate: () async throws -> String
  ) async -> (result: String?, lastError: Error?) {
    var lastError: Error?
    for attempt in 1...max(1, maxAttempts) {
      do {
        let content = try await generate()
        if let usable = sanitize(content) {
          return (usable, nil)
        }
        // Model responded but normalization found nothing usable — transient.
        lastError = nil
      } catch {
        lastError = error
      }
      if attempt < maxAttempts {
        await backoff(attempt)
      }
    }
    return (nil, lastError)
  }

  /// Brief pause before a fresh session; the failure is often immediate, and a
  /// short backoff avoids hammering the model service.
  static func defaultBackoff(_ attempt: Int) async {
    try? await Task.sleep(nanoseconds: 200_000_000)
  }
}
