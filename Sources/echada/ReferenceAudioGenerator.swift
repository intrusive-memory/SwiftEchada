#if os(macOS)
import Foundation

/// Generates reference audio WAV files using macOS `say` command as a fallback
/// when on-device ML voice design is unavailable.
///
/// The output is 24kHz, 16-bit PCM mono WAV suitable for voice cloning reference.
enum ReferenceAudioGenerator {

    /// Generate a reference WAV file using macOS text-to-speech.
    ///
    /// - Parameters:
    ///   - text: The text to speak.
    ///   - voice: The macOS `say` voice name (e.g. "Daniel", "Samantha").
    ///     Defaults to system default.
    ///   - outputURL: Where to write the WAV file.
    /// - Throws: If the `say` command fails.
    static func generate(
        text: String,
        voice: String? = nil,
        outputURL: URL
    ) async throws {
        // say outputs AIFF by default; we produce AIFF then convert via afconvert
        let aiffURL = outputURL.deletingPathExtension().appendingPathExtension("aiff")

        var sayArgs = ["-o", aiffURL.path]
        if let voice {
            sayArgs += ["-v", voice]
        }
        sayArgs.append(text)

        // Generate AIFF
        let sayProcess = Process()
        sayProcess.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        sayProcess.arguments = sayArgs
        try sayProcess.run()
        sayProcess.waitUntilExit()

        guard sayProcess.terminationStatus == 0 else {
            throw ReferenceAudioError.sayFailed(sayProcess.terminationStatus)
        }

        // Convert to 24kHz 16-bit PCM WAV
        let convertProcess = Process()
        convertProcess.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        convertProcess.arguments = [
            aiffURL.path,
            outputURL.path,
            "-d", "LEI16",     // Little-endian 16-bit integer
            "-f", "WAVE",      // WAV format
            "-r", "24000",     // 24kHz sample rate
            "-c", "1",         // Mono
        ]
        try convertProcess.run()
        convertProcess.waitUntilExit()

        // Clean up intermediate AIFF
        try? FileManager.default.removeItem(at: aiffURL)

        guard convertProcess.terminationStatus == 0 else {
            throw ReferenceAudioError.conversionFailed(convertProcess.terminationStatus)
        }
    }

    /// Generate reference WAV data in memory.
    ///
    /// - Parameters:
    ///   - text: The text to speak.
    ///   - voice: The macOS `say` voice name.
    /// - Returns: WAV format Data (24kHz, 16-bit PCM, mono).
    static func generateData(
        text: String,
        voice: String? = nil
    ) async throws -> Data {
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        try await generate(text: text, voice: voice, outputURL: outputURL)
        return try Data(contentsOf: outputURL)
    }
}

enum ReferenceAudioError: Error, CustomStringConvertible {
    case sayFailed(Int32)
    case conversionFailed(Int32)

    var description: String {
        switch self {
        case .sayFailed(let code):
            "macOS 'say' command failed with exit code \(code)"
        case .conversionFailed(let code):
            "afconvert failed with exit code \(code)"
        }
    }
}
#endif
