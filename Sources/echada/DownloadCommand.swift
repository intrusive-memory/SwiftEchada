import ArgumentParser
import Foundation
import SwiftBruja

import os

private final class ProgressTracker: Sendable {
    private let _lastPercent = OSAllocatedUnfairLock(initialState: -1)
    func update(_ percent: Int) -> Bool {
        _lastPercent.withLock { last in
            guard percent != last else { return false }
            last = percent
            return true
        }
    }
}

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

        let tracker = ProgressTracker()
        try await Bruja.download(model: model, force: force) { fraction in
            let percent = Int(fraction * 100)
            guard tracker.update(percent) else { return }
            let filled = percent / 2
            let empty = 50 - filled
            let bar = String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
            print("\r[\(bar)] \(percent)%", terminator: "")
            fflush(stdout)
            if percent >= 100 { print() }
        }

        if !quiet {
            print("Download complete.")
        }
    }
}
