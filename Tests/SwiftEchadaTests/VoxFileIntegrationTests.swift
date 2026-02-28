import Foundation
import Testing
import SwiftProyecto
@preconcurrency import VoxFormat
@testable import SwiftEchada

// MARK: - Helpers

/// Creates a minimal valid WAV header + silent PCM data.
private func syntheticWAV(durationSeconds: Double = 0.5, sampleRate: Int = 24000) -> Data {
    let numSamples = Int(Double(sampleRate) * durationSeconds)
    let dataSize = numSamples * 2 // 16-bit mono
    let fileSize = 36 + dataSize

    var data = Data()
    data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
    data.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
    data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"
    data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
    data.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
    data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
    data.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
    data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
    data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) }) // byte rate
    data.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })  // block align
    data.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample
    data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
    data.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })
    data.append(Data(repeating: 0, count: dataSize)) // silence
    return data
}

/// Creates random bytes to simulate a clone prompt embedding.
private func syntheticClonePrompt(size: Int = 1024) -> Data {
    Data((0..<size).map { _ in UInt8.random(in: 0...255) })
}

/// Temporary directory scoped to a test run.
private func tempVoxURL(name: String = "test-voice") -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("vox-integration-\(UUID().uuidString)")
        .appendingPathComponent("\(name).vox")
}

private func ensureParent(of url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
}

/// Creates a VoxFile with gender set on the voice (since Voice.gender is set via init).
private func makeVoxFile(name: String, description: String, gender: String? = nil) -> VoxFile {
    let manifest = VoxManifest(
        voxVersion: VoxFormat.currentVersion,
        id: UUID().uuidString.lowercased(),
        created: Date(),
        voice: VoxManifest.Voice(name: name, description: description, gender: gender)
    )
    return VoxFile(manifest: manifest)
}

// MARK: - Path Constants (contract with VoxExporter)

/// These must match VoxExporter's path conventions exactly.
/// If VoxExporter changes its paths, these tests should fail — that's intentional.
private enum VoxPaths {
    static func clonePrompt(slug: String) -> String {
        "embeddings/qwen3-tts/\(slug)/clone-prompt.bin"
    }
    static func sampleAudio(slug: String) -> String {
        "embeddings/qwen3-tts/\(slug)/sample-audio.wav"
    }
    static func embeddingKey(slug: String, suffix: String) -> String {
        "qwen3-tts-\(slug)-\(suffix)"
    }
}

// MARK: - Model Constants

private let model06B = "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16"
private let model17B = "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16"

// MARK: - Tests

@Suite("VoxFile Integration Tests")
struct VoxFileIntegrationTests {

    @Test func createSingleModelVoxFile() throws {
        let url = tempVoxURL()
        try ensureParent(of: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let cloneData = syntheticClonePrompt()
        let sampleData = syntheticWAV()
        let slug = "0.6b"

        // Build
        let vox = makeVoxFile(name: "NARRATOR", description: "Deep authoritative male narrator voice with gravitas", gender: "male")
        vox.manifest.provenance = VoxManifest.Provenance(
            method: "synthesized",
            engine: "qwen3-tts",
            license: "CC0-1.0",
            notes: "Integration test voice"
        )

        try vox.add(cloneData, at: VoxPaths.clonePrompt(slug: slug), metadata: [
            "key": VoxPaths.embeddingKey(slug: slug, suffix: "clone-prompt"),
            "model": model06B,
            "engine": "qwen3-tts",
            "format": "bin",
            "description": "Clone prompt for voice cloning (\(slug))",
        ] as [String: Any])

        try vox.add(sampleData, at: VoxPaths.sampleAudio(slug: slug), metadata: [
            "key": VoxPaths.embeddingKey(slug: slug, suffix: "sample-audio"),
            "model": model06B,
            "engine": "qwen3-tts",
            "format": "wav",
            "description": "Engine-generated voice sample (\(slug))",
        ] as [String: Any])

        // Write
        try vox.write(to: url)
        #expect(FileManager.default.fileExists(atPath: url.path))

        // Re-read
        let reopened = try VoxFile(contentsOf: url)

        // Manifest
        #expect(reopened.manifest.voice.name == "NARRATOR")
        #expect(reopened.manifest.voice.gender == "male")
        #expect(reopened.manifest.provenance?.method == "synthesized")

        // Embeddings
        let embeddings = reopened.manifest.embeddingEntries ?? [:]
        #expect(embeddings.count == 2)
        let cloneKey = VoxPaths.embeddingKey(slug: slug, suffix: "clone-prompt")
        let sampleKey = VoxPaths.embeddingKey(slug: slug, suffix: "sample-audio")
        #expect(embeddings[cloneKey] != nil)
        #expect(embeddings[sampleKey] != nil)
        #expect(embeddings[cloneKey]?.model == model06B)

        // Data round-trip
        #expect(reopened[VoxPaths.clonePrompt(slug: slug)]?.data == cloneData)
        #expect(reopened[VoxPaths.sampleAudio(slug: slug)]?.data == sampleData)

        // Readiness & validation
        #expect(reopened.isReady)
        #expect(reopened.isValid)
    }

    @Test func createMultiModelVoxFile() throws {
        let url = tempVoxURL()
        try ensureParent(of: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let vox = makeVoxFile(name: "HERO", description: "Young confident voice with warmth and energy", gender: "female")

        // Add 0.6b model
        for (slug, model) in [("0.6b", model06B), ("1.7b", model17B)] {
            try vox.add(syntheticClonePrompt(), at: VoxPaths.clonePrompt(slug: slug), metadata: [
                "key": VoxPaths.embeddingKey(slug: slug, suffix: "clone-prompt"),
                "model": model,
                "engine": "qwen3-tts",
                "format": "bin",
                "description": "Clone prompt (\(slug))",
            ] as [String: Any])

            try vox.add(syntheticWAV(), at: VoxPaths.sampleAudio(slug: slug), metadata: [
                "key": VoxPaths.embeddingKey(slug: slug, suffix: "sample-audio"),
                "model": model,
                "engine": "qwen3-tts",
                "format": "wav",
                "description": "Sample audio (\(slug))",
            ] as [String: Any])
        }

        try vox.write(to: url)
        let reopened = try VoxFile(contentsOf: url)

        // 4 embedding entries: clone-prompt + sample-audio for each of 2 models
        let embeddings = reopened.manifest.embeddingEntries ?? [:]
        #expect(embeddings.count == 4)

        // Both models present
        #expect(embeddings[VoxPaths.embeddingKey(slug: "0.6b", suffix: "clone-prompt")]?.model == model06B)
        #expect(embeddings[VoxPaths.embeddingKey(slug: "1.7b", suffix: "clone-prompt")]?.model == model17B)

        // All data present
        #expect(reopened.entryCount == 4)
        #expect(reopened.isReady)
        #expect(reopened.isValid)
    }

    @Test func appendModelToExistingVoxFile() throws {
        let url = tempVoxURL()
        try ensureParent(of: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        // Pass 1: Create with 0.6b only
        let vox = makeVoxFile(name: "VILLAIN", description: "Menacing low voice with subtle threat underneath", gender: "male")

        let clone06 = syntheticClonePrompt()
        try vox.add(clone06, at: VoxPaths.clonePrompt(slug: "0.6b"), metadata: [
            "key": VoxPaths.embeddingKey(slug: "0.6b", suffix: "clone-prompt"),
            "model": model06B,
            "engine": "qwen3-tts",
            "format": "bin",
        ] as [String: Any])
        try vox.add(syntheticWAV(), at: VoxPaths.sampleAudio(slug: "0.6b"), metadata: [
            "key": VoxPaths.embeddingKey(slug: "0.6b", suffix: "sample-audio"),
            "model": model06B,
            "engine": "qwen3-tts",
            "format": "wav",
        ] as [String: Any])
        try vox.write(to: url)

        // Pass 2: Re-open and append 1.7b
        let reopened = try VoxFile(contentsOf: url)
        let clone17 = syntheticClonePrompt()
        try reopened.add(clone17, at: VoxPaths.clonePrompt(slug: "1.7b"), metadata: [
            "key": VoxPaths.embeddingKey(slug: "1.7b", suffix: "clone-prompt"),
            "model": model17B,
            "engine": "qwen3-tts",
            "format": "bin",
        ] as [String: Any])
        try reopened.add(syntheticWAV(), at: VoxPaths.sampleAudio(slug: "1.7b"), metadata: [
            "key": VoxPaths.embeddingKey(slug: "1.7b", suffix: "sample-audio"),
            "model": model17B,
            "engine": "qwen3-tts",
            "format": "wav",
        ] as [String: Any])
        try reopened.write(to: url)

        // Verify both models present
        let final = try VoxFile(contentsOf: url)
        let embeddings = final.manifest.embeddingEntries ?? [:]
        #expect(embeddings.count == 4)

        // Original 0.6b data preserved
        #expect(final[VoxPaths.clonePrompt(slug: "0.6b")]?.data == clone06)
        // New 1.7b data present
        #expect(final[VoxPaths.clonePrompt(slug: "1.7b")]?.data == clone17)

        #expect(final.isReady)
        #expect(final.isValid)
    }

    @Test func characterProfileGenderMapsToVoxFormat() {
        let cases: [(Gender, String)] = [
            (.male, "male"),
            (.female, "female"),
            (.nonBinary, "nonbinary"),
            (.notSpecified, "neutral"),
        ]

        for (gender, expected) in cases {
            let profile = CharacterProfile(
                name: "TEST",
                gender: gender,
                ageRange: "30s",
                description: "test voice",
                voiceTraits: [],
                summary: "test"
            )
            #expect(
                profile.voxFormatGender == expected,
                "Gender.\(gender) should map to \"\(expected)\" but got \"\(profile.voxFormatGender)\""
            )
        }
    }

    @Test func emptyVoxFileIsReady() {
        let vox = VoxFile(name: "EMPTY", description: "A valid voice with no embeddings declared")
        #expect(vox.isReady)
    }
}
