import ArgumentParser
import Foundation
import Testing

@testable import EchadaCLICore

/// Offline parse coverage for `--llm`, which picks the FoundationModels-backed
/// model that writes voice prompts. No model call is made.
@Suite("--llm option — offline parse")
struct LanguageModelOptionTests {

  @Test("generate prompt defaults to the on-device model")
  func promptDefaultsToOnDevice() throws {
    let cmd = try GeneratePromptCommand.parse([])
    #expect(cmd.llm == .onDevice)
  }

  @Test("generate prompt accepts on-device and pcc")
  func promptAcceptsBothChoices() throws {
    #expect(try GeneratePromptCommand.parse(["--llm", "on-device"]).llm == .onDevice)
    #expect(try GeneratePromptCommand.parse(["--llm", "pcc"]).llm == .privateCloud)
  }

  @Test("generate prompt rejects an unknown model")
  func promptRejectsUnknownChoice() {
    #expect(throws: (any Error).self) {
      try GeneratePromptCommand.parse(["--llm", "claude"])
    }
  }

  @Test("cast pipeline defaults to on-device and accepts pcc")
  func castAcceptsChoice() throws {
    #expect(try CastCommand.parse([]).llm == .onDevice)
    #expect(try CastCommand.parse(["--llm", "pcc"]).llm == .privateCloud)
  }

  @Test("raw values are the CLI spellings")
  func rawValues() {
    #expect(LanguageModelChoice.allCases.map(\.rawValue) == ["on-device", "pcc"])
  }
}
