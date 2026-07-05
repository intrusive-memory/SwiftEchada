import Foundation
import Testing

@testable import EchadaCLICore

@Suite("--accent CLI surface")
struct AccentOptionTests {

  // MARK: - composeVoicePrompt

  @Test func nilAccentReturnBaseUnchanged() {
    #expect(composeVoicePrompt(base: "X", accent: nil) == "X")
  }

  @Test func emptyAccentReturnsBaseUnchanged() {
    #expect(composeVoicePrompt(base: "X", accent: "") == "X")
  }

  @Test func whitespaceOnlyAccentReturnsBaseUnchanged() {
    #expect(composeVoicePrompt(base: "X", accent: "   ") == "X")
  }

  @Test func nonEmptyAccentContainsBothBaseAndAccent() {
    let result = composeVoicePrompt(base: "X", accent: "slow drawl")
    #expect(result.contains("X"))
    #expect(result.contains("slow drawl"))
  }

  // MARK: - GenerateVoxCommand.resolvedAccent normalization

  @Test func noFlagReturnsNil() throws {
    let cmd = try GenerateVoxCommand.parse([])
    #expect(cmd.resolvedAccent() == nil)
  }

  @Test func whitespaceOnlyFlagReturnsNil() throws {
    let cmd = try GenerateVoxCommand.parse(["--accent", "   "])
    #expect(cmd.resolvedAccent() == nil)
  }

  @Test func paddedValueIsTrimmed() throws {
    let cmd = try GenerateVoxCommand.parse(["--accent", "  drawl "])
    #expect(cmd.resolvedAccent() == "drawl")
  }

  @Test func accentFlagParsesAndReachesResolvedAccent() throws {
    let cmd = try GenerateVoxCommand.parse(["--accent", "slow southern drawl"])
    #expect(cmd.resolvedAccent() == "slow southern drawl")
  }
}
