import AVFoundation
import EchadaVoice
import Foundation
import SwiftReparto
import Testing
@preconcurrency import VoxFormat

@testable import EchadaCLICore

/// A synthetic-but-valid `.vox` with a clone prompt and a playable sample per
/// model size, laid out the way VoxExporter writes them. No model involved.
enum SyntheticVox {
  static let modelIDs = [
    "1.7b": "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16",
    "0.6b": "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-bf16",
  ]

  /// A quarter second of 24 kHz, 16-bit mono PCM.
  static func wav(sampleRate: Int = 24000) -> Data {
    let samples = sampleRate / 4
    let dataSize = samples * 2
    func le<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
      withUnsafeBytes(of: value.littleEndian) { Array($0) }
    }
    var wav = Data("RIFF".utf8)
    wav.append(contentsOf: le(UInt32(36 + dataSize)))
    wav.append(contentsOf: Data("WAVEfmt ".utf8))
    wav.append(contentsOf: le(UInt32(16)) + le(UInt16(1)) + le(UInt16(1)))
    wav.append(contentsOf: le(UInt32(sampleRate)) + le(UInt32(sampleRate * 2)))
    wav.append(contentsOf: le(UInt16(2)) + le(UInt16(16)))
    wav.append(contentsOf: Data("data".utf8))
    wav.append(contentsOf: le(UInt32(dataSize)))
    for index in 0..<samples {
      let value = Int16(8000 * sin(Double(index) * 2 * .pi * 440 / Double(sampleRate)))
      wav.append(contentsOf: le(value))
    }
    return wav
  }

  static func write(at url: URL, name: String, sizes: [String] = ["1.7b"]) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let vox = VoxFile(
      manifest: VoxManifest(
        voxVersion: VoxFormat.currentVersion, id: UUID().uuidString.lowercased(),
        created: Date(timeIntervalSince1970: 0),
        voice: VoxManifest.Voice(name: name, description: "Synthetic test voice")))
    for slug in sizes {
      let model = modelIDs[slug]!
      try vox.add(
        Data(repeating: 7, count: 64), at: "embeddings/qwen3-tts/\(slug)/clone-prompt.bin",
        metadata: [
          "key": "qwen3-tts-\(slug)-clone-prompt", "model": model, "engine": "qwen3-tts",
          "format": "bin",
        ] as [String: Any])
      try vox.add(
        wav(), at: "embeddings/qwen3-tts/\(slug)/sample-audio.wav",
        metadata: [
          "key": "qwen3-tts-\(slug)-sample-audio", "model": model, "engine": "qwen3-tts",
          "format": "wav",
        ] as [String: Any])
    }
    try vox.write(to: url)
  }
}

// MARK: - EC-26

@Suite("echada migrate voices — EC-26 (offline)")
struct VoiceMigrationTests {

  private func makeProject(_ members: [CastMember]) throws -> (dir: URL, cast: URL) {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("migrate-voices-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let cast = dir.appendingPathComponent("CAST.md")
    try CastMarkdownParser().write(document: CastDocument(cast: members), to: cast)
    try "---\ntype: project\ntitle: T\nauthor: A\ncreated: 2026-01-01T00:00:00Z\n---\n".write(
      to: dir.appendingPathComponent("PROJECT.md"), atomically: true, encoding: .utf8)
    return (dir, cast)
  }

  private func vox(_ dir: URL, _ path: String, _ name: String) throws {
    try SyntheticVox.write(at: dir.appendingPathComponent(path), name: name)
  }

  @Test("The dry run plans dossier moves, skips shared voices, and reports strays")
  func dryRunPlan() throws {
    var shane = CastMember(character: "SHANE", voices: ["voxalta": ["voices/SHANE.vox"]])
    shane.manifest = "characters/SHANE.dossier/manifest.json"
    let (dir, cast) = try makeProject([
      CastMember(
        character: "THE PRACTITIONER", voices: ["voxalta": ["voices/THE_PRACTITIONER.vox"]]),
      shane,
      CastMember(character: "HOST", voices: ["voxalta": ["../common-voices/HOST.vox"]]),
    ])
    defer { try? FileManager.default.removeItem(at: dir) }
    try vox(dir, "voices/THE_PRACTITIONER.vox", "THE PRACTITIONER")
    try vox(dir, "voices/SHANE.vox", "SHANE")
    try vox(dir, "voices/ORPHAN.vox", "ORPHAN")
    let castBefore = try Data(contentsOf: cast)

    let plan = try VoiceMigration.plan(castURL: cast, charactersDir: "characters")
    #expect(
      plan.moves == [
        .init(
          character: "THE PRACTITIONER", from: "voices/THE_PRACTITIONER.vox",
          to: "characters/THE PRACTITIONER.dossier/voice/THE PRACTITIONER.vox"),
        .init(
          character: "SHANE", from: "voices/SHANE.vox",
          to: "characters/SHANE.dossier/voice/SHANE.vox"),
      ])
    #expect(plan.skips.map(\.character) == ["HOST"])
    #expect(plan.strays == ["voices/ORPHAN.vox"])
    #expect(plan.canApply)
    // The plan wrote nothing.
    #expect(try Data(contentsOf: cast) == castBefore)
    #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent("characters").path))
  }

  @Test("--apply moves the files, rewrites every pointer once, and removes the old files")
  func applyMoves() throws {
    let (dir, cast) = try makeProject([
      CastMember(character: "DR. O'NEILL", voices: ["voxalta": ["voices/DR._O'NEILL.vox"]])
    ])
    defer { try? FileManager.default.removeItem(at: dir) }
    try vox(dir, "voices/DR._O'NEILL.vox", "DR. O'NEILL")

    let plan = try VoiceMigration.plan(castURL: cast, charactersDir: "characters")
    try VoiceMigration.apply(plan, castURL: cast)

    let new = "characters/DR. O'NEILL.dossier/voice/DR. O'NEILL.vox"
    let member = try #require(try CastMarkdownParser().parse(fileURL: cast).cast.first)
    #expect(member.voices["voxalta"] == [new])
    #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent(new).path))
    #expect(
      !FileManager.default.fileExists(
        atPath: dir.appendingPathComponent("voices/DR._O'NEILL.vox").path))
    #expect(try VoxFile(contentsOf: dir.appendingPathComponent(new)).isValid)

    // A second plan finds nothing left to move.
    let again = try VoiceMigration.plan(castURL: cast, charactersDir: "characters")
    #expect(again.moves.isEmpty)
    #expect(again.alreadyInPlace == ["DR. O'NEILL"])
  }

  @Test(
    "A failure at any step leaves the old files and CAST.md untouched",
    arguments: [VoiceMigration.Step.copied, .pointersWritten, .verified])
  func rollbackOnInjectedFailure(step: VoiceMigration.Step) throws {
    let (dir, cast) = try makeProject([
      CastMember(character: "NARRATOR", voices: ["voxalta": ["voices/NARRATOR.vox"]])
    ])
    defer { try? FileManager.default.removeItem(at: dir) }
    try vox(dir, "voices/NARRATOR.vox", "NARRATOR")
    let castBefore = try Data(contentsOf: cast)

    let plan = try VoiceMigration.plan(castURL: cast, charactersDir: "characters")
    #expect(throws: VoiceMigration.MigrationError.injected(step)) {
      try VoiceMigration.apply(plan, castURL: cast, failAfter: step)
    }
    #expect(try Data(contentsOf: cast) == castBefore)
    #expect(
      FileManager.default.fileExists(atPath: dir.appendingPathComponent("voices/NARRATOR.vox").path)
    )
    #expect(
      !FileManager.default.fileExists(
        atPath: dir.appendingPathComponent("characters/NARRATOR.dossier/voice/NARRATOR.vox").path))
  }

  @Test("A non-canonical name blocks the whole migration and points at reparto canonicalize")
  func nonCanonicalBlocks() throws {
    let (dir, cast) = try makeProject([
      CastMember(character: "Narrator", voices: ["voxalta": ["voices/Narrator.vox"]])
    ])
    defer { try? FileManager.default.removeItem(at: dir) }
    try vox(dir, "voices/Narrator.vox", "Narrator")

    let plan = try VoiceMigration.plan(castURL: cast, charactersDir: "characters")
    #expect(!plan.canApply)
    #expect(plan.blockers.first?.reason.contains("reparto canonicalize") == true)
    #expect(throws: VoiceMigration.MigrationError.self) {
      try VoiceMigration.apply(plan, castURL: cast)
    }
  }

  @Test("A destination that already exists with different contents blocks the migration")
  func differentDestinationBlocks() throws {
    let (dir, cast) = try makeProject([
      CastMember(character: "MAYA", voices: ["voxalta": ["voices/MAYA.vox"]])
    ])
    defer { try? FileManager.default.removeItem(at: dir) }
    try vox(dir, "voices/MAYA.vox", "MAYA")
    try vox(dir, "characters/MAYA.dossier/voice/MAYA.vox", "SOMEONE ELSE")

    let plan = try VoiceMigration.plan(castURL: cast, charactersDir: "characters")
    #expect(plan.blockers.map(\.character) == ["MAYA"])
  }
}

// MARK: - EC-28

@Suite("echada sample — EC-28 (offline)")
struct VoiceSampleTests {

  @Test("neutral exports the embedded sample to sample-neutral.m4a with no synthesis")
  func neutralExport() async throws {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("sample-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let member = CastMember(character: "MAYA", language: "en")
    try SyntheticVox.write(
      at: dir.appendingPathComponent("characters/MAYA.dossier/voice/MAYA.vox"), name: "MAYA",
      sizes: ["1.7b", "0.6b"])

    let builder = VoiceBuilder(castDirectory: dir)
    let neutral = try await builder.renderSample(for: member)
    #expect(neutral.relativePath == "characters/MAYA.dossier/voice/sample-neutral.m4a")
    #expect(neutral.variant == "neutral")
    #expect(neutral.model == .large)
    #expect(!neutral.sampleText.isEmpty)

    let small = try await builder.renderSample(for: member, model: .small)
    #expect(small.relativePath == "characters/MAYA.dossier/voice/sample-neutral-0.6b.m4a")

    let m4a = try AVAudioFile(forReading: dir.appendingPathComponent(neutral.relativePath))
    #expect(m4a.length > 0)
    #expect(m4a.fileFormat.settings[AVFormatIDKey] as? UInt32 == kAudioFormatMPEG4AAC)
  }

  @Test("A missing .vox or model size is reported, not invented")
  func missingVoiceIsReported() async throws {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("sample-missing-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let builder = VoiceBuilder(castDirectory: dir)
    await #expect(throws: VoiceBuilderError.self) {
      try await builder.renderSample(for: CastMember(character: "NOAH"))
    }
    try SyntheticVox.write(
      at: dir.appendingPathComponent("characters/NOAH.dossier/voice/NOAH.vox"), name: "NOAH")
    await #expect(throws: VoiceBuilderError.self) {
      try await builder.renderSample(for: CastMember(character: "NOAH"), model: .small)
    }
  }

  @Test("--all-variants reads samples.yaml, else neutral on every size the .vox holds")
  func allVariantsJobs() throws {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("sample-jobs-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: dir) }
    let voxURL = dir.appendingPathComponent("characters/MAYA.dossier/voice/MAYA.vox")
    try SyntheticVox.write(at: voxURL, name: "MAYA", sizes: ["1.7b", "0.6b"])

    let cmd = try SampleCommand.parse(["MAYA", "--all-variants"])
    #expect(
      try cmd.jobs(voxURL: voxURL, sampleLine: nil) == [
        .init(variant: "neutral", text: nil, model: .large),
        .init(variant: "neutral", text: nil, model: .small),
      ])

    try """
    - variant: whisper
      text: Did you sleep at all?
      instruct: barely audible
    - variant: shout
      text: Get out!
      model: 0.6b
      language: es
    """.write(
      to: voxURL.deletingLastPathComponent().appendingPathComponent("samples.yaml"),
      atomically: true, encoding: .utf8)
    #expect(
      try cmd.jobs(voxURL: voxURL, sampleLine: nil) == [
        .init(
          variant: "whisper", text: "Did you sleep at all?", model: .large, language: nil,
          instruct: "barely audible"),
        .init(variant: "shout", text: "Get out!", model: .small, language: "es", instruct: nil),
      ])
  }

  @Test("sampleLine comes from CHARACTER.md front matter")
  func sampleLineFromCharacterMd() throws {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("sample-line-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    #expect(SampleCommand.sampleLine(characterDirectory: dir) == nil)
    try "---\ntype: character\ncharacter: MAYA\nsampleLine: \"Did you sleep at all?\"\n---\n\nBody."
      .write(to: dir.appendingPathComponent("CHARACTER.md"), atomically: true, encoding: .utf8)
    #expect(SampleCommand.sampleLine(characterDirectory: dir) == "Did you sleep at all?")
  }

  @Test("Sample file names add the size only when it isn't the default")
  func sampleFileNames() {
    #expect(VoiceBuilder.sampleFileName(variant: "neutral", model: .large) == "sample-neutral.m4a")
    #expect(VoiceBuilder.sampleFileName(variant: "angry", model: .small) == "sample-angry-0.6b.m4a")
  }
}
