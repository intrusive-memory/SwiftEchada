import ArgumentParser
import Foundation
import SwiftProyecto

import enum SwiftEchada.SwiftEchada

@main
struct EchadaCLI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "echada",
    abstract: "On-device voice generation for screenplay projects.",
    version: SwiftEchada.version,
    subcommands: [VoiceCommand.self, CastCommand.self, TestVoiceCommand.self],
    defaultSubcommand: CastCommand.self
  )
}
