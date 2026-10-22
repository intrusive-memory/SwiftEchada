import ArgumentParser
import Foundation
import SwiftLlavero
import Testing

@testable import EchadaCLICore

/// Offline coverage for `--llm`, which picks the model that writes voice
/// prompts, and for resolving it through SwiftLlavero. No model call is made.
@Suite("--llm option — offline")
struct LanguageModelOptionTests {

  @Test("generate prompt defaults to the on-device model")
  func promptDefaultsToOnDevice() throws {
    let cmd = try GeneratePromptCommand.parse([])
    #expect(cmd.llm == .onDevice)
  }

  @Test("generate prompt accepts Apple shorthands and account:model references")
  func promptAcceptsReferences() throws {
    #expect(try GeneratePromptCommand.parse(["--llm", "on-device"]).llm == .onDevice)
    #expect(try GeneratePromptCommand.parse(["--llm", "pcc"]).llm == .privateCloud)
    let claude = try GeneratePromptCommand.parse(["--llm", "anthropic:claude-sonnet-5-5"]).llm
    #expect(claude.account == "anthropic")
    #expect(claude.model == "claude-sonnet-5-5")
  }

  @Test("generate prompt rejects a malformed reference at parse time")
  func promptRejectsMalformedReference() {
    #expect(throws: (any Error).self) {
      try GeneratePromptCommand.parse(["--llm", "not a model"])
    }
  }

  @Test("cast pipeline defaults to on-device and accepts a provider reference")
  func castAcceptsReference() throws {
    #expect(try CastCommand.parse([]).llm == .onDevice)
    #expect(try CastCommand.parse(["--llm", "openai:gpt-5.6"]).llm.account == "openai")
  }

  @Test("an unconfigured account fails fast with a message naming it")
  func unconfiguredAccountFailsFast() async {
    let llavero = Llavero.standard(store: InMemoryCredentialStore())
    do {
      _ = try await LanguageModelResolver.resolve(
        ModelReference(account: "anthropic"), llavero: llavero)
      Issue.record("expected an error")
    } catch {
      let message = error.localizedDescription
      #expect(message.contains("'anthropic'"))
      #expect(message.contains("auth login"))
    }
  }

  @Test("only the on-device reference counts as on-device")
  func onDeviceDetection() {
    #expect(LanguageModelResolver.isOnDevice(.onDevice))
    #expect(!LanguageModelResolver.isOnDevice(.privateCloud))
    #expect(!LanguageModelResolver.isOnDevice(ModelReference(account: "anthropic")))
  }

  @Test("echada mounts Llavero's auth command")
  func authMounted() {
    let names = EchadaCLI.configuration.subcommands.compactMap { $0.configuration.commandName }
    #expect(names.contains("auth"))
  }
}
