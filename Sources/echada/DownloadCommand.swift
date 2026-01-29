import ArgumentParser
import Foundation
import SwiftBruja

struct DownloadCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "download",
        abstract: "Download an LLM model for local inference."
    )

    @Option(name: .long, help: "HuggingFace model identifier.")
    var model: String = Bruja.defaultModel

    @Flag(name: .long, help: "Re-download even if model exists locally.")
    var force: Bool = false

    @Flag(name: .long, help: "Suppress progress output.")
    var quiet: Bool = false

    func run() async throws {
        if !quiet {
            print("Downloading model: \(model)")
            if force { print("(force re-download)") }
        }

        try await Bruja.download(model: model, force: force)

        if !quiet {
            print("Download complete.")
        }
    }
}
