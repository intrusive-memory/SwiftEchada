import ArgumentParser
import Foundation
import SwiftProyecto

import enum SwiftEchada.SwiftEchada

public struct EchadaCLI: AsyncParsableCommand {
  public static let configuration = CommandConfiguration(
    commandName: "echada",
    abstract: "On-device voice generation for screenplay projects.",
    version: SwiftEchada.version,
    subcommands: [VoiceCommand.self, CastCommand.self, PromptCommand.self, TestVoiceCommand.self],
    defaultSubcommand: CastCommand.self
  )

  public init() {}
}
