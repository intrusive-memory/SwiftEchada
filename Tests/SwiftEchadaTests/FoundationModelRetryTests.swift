import Foundation
import Testing

@testable import EchadaCLICore

/// Exercises the retry/return contract of ``FoundationModelRetry`` without Apple
/// Intelligence by injecting the model call, attempt count, and backoff.
///
/// This is the resilience layer that keeps a single transient FoundationModels
/// failure (notably "Failed to deserialize a Generable type from model output")
/// from aborting a whole cast run, so its behavior is pinned here directly.
@Suite("FoundationModelRetry — bounded transient-failure retry")
struct FoundationModelRetryTests {

  private struct StubError: Error, Equatable { let tag: String }

  /// No backoff in tests — keeps the suite fast and deterministic.
  private static func noBackoff(_ attempt: Int) async {}

  @Test("Returns the first sanitized success without extra attempts")
  func succeedsFirstTry() async {
    var calls = 0
    let (result, lastError) = await FoundationModelRetry.sanitizedResponse(
      maxAttempts: 4,
      sanitize: { $0 },
      backoff: Self.noBackoff,
      generate: {
        calls += 1
        return "hello"
      })

    #expect(result == "hello")
    #expect(lastError == nil)
    #expect(calls == 1)
  }

  @Test("Retries transient throws, then succeeds")
  func retriesThenSucceeds() async {
    var calls = 0
    let (result, lastError) = await FoundationModelRetry.sanitizedResponse(
      maxAttempts: 4,
      sanitize: { $0 },
      backoff: Self.noBackoff,
      generate: {
        calls += 1
        if calls < 3 { throw StubError(tag: "deserialize") }
        return "recovered"
      })

    #expect(result == "recovered")
    #expect(lastError == nil)
    #expect(calls == 3)
  }

  @Test("Empty-after-sanitize is a retryable miss")
  func retriesOnUnusableOutput() async {
    var calls = 0
    let (result, lastError) = await FoundationModelRetry.sanitizedResponse(
      maxAttempts: 4,
      // First two responses sanitize to nil (unusable); the third is kept.
      sanitize: { $0.isEmpty ? nil : $0 },
      backoff: Self.noBackoff,
      generate: {
        calls += 1
        return calls < 3 ? "" : "usable"
      })

    #expect(result == "usable")
    #expect(lastError == nil)
    #expect(calls == 3)
  }

  @Test("Exhausts attempts and surfaces the last underlying error")
  func exhaustsAndReportsLastError() async {
    var calls = 0
    let (result, lastError) = await FoundationModelRetry.sanitizedResponse(
      maxAttempts: 3,
      sanitize: { $0 },
      backoff: Self.noBackoff,
      generate: {
        calls += 1
        throw StubError(tag: "attempt-\(calls)")
      })

    #expect(result == nil)
    #expect(calls == 3)
    #expect((lastError as? StubError) == StubError(tag: "attempt-3"))
  }

  @Test("A final empty-output miss reports a nil underlying error")
  func exhaustsWithEmptyOutputReportsNilError() async {
    var calls = 0
    let (result, lastError) = await FoundationModelRetry.sanitizedResponse(
      maxAttempts: 2,
      sanitize: { _ in nil },
      backoff: Self.noBackoff,
      generate: {
        calls += 1
        return "always unusable"
      })

    #expect(result == nil)
    #expect(lastError == nil)
    #expect(calls == 2)
  }

  @Test("Backoff runs between attempts but never after the last")
  func backoffFiresOnlyBetweenAttempts() async {
    var backoffs = 0
    let (result, _) = await FoundationModelRetry.sanitizedResponse(
      maxAttempts: 3,
      sanitize: { $0 },
      backoff: { _ in backoffs += 1 },
      generate: { throw StubError(tag: "x") })

    #expect(result == nil)
    // 3 attempts → backoff after attempt 1 and 2 only.
    #expect(backoffs == 2)
  }
}
