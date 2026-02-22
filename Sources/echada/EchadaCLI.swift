import ArgumentParser
import Foundation
import SwiftBruja
import enum SwiftEchada.SwiftEchada
import SwiftProyecto

@main
struct EchadaCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "echada",
        abstract: "AI-powered cast management for screenplay projects.",
        version: SwiftEchada.version,
        subcommands: [ExtractCommand.self, CastCommand.self, DownloadCommand.self],
        defaultSubcommand: ExtractCommand.self
    )
}
