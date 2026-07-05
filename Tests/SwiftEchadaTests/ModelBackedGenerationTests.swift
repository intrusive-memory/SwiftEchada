import ArgumentParser
import Foundation
import FoundationModels
import SwiftProyecto
import Testing
@preconcurrency import VoxFormat

@testable import EchadaCLICore

/// Model-backed, end-to-end tests for the generative stages (S9, OPERATION
/// GENERAL MUSTER). These exercise REAL models — the on-device Foundation Model
/// (audition sentences + voice prompts) and the MLX Qwen3-TTS weights (`.vox`
/// synthesis) — and are therefore gated so they SKIP (never fail) on any machine
/// that lacks the model they need.
///
/// **Two independent gates.**
///
/// 1. **Apple Intelligence** — `SystemLanguageModel.default.isAvailable`, exactly
///    as in `FoundationModelSentenceTests`. GitHub-hosted `macos-26` reports
///    `false` here, so Foundation-Model paths skip on hosted CI and run only on a
///    developer Mac / self-hosted Apple-Intelligence runner (accepted per resolved
///    OQ-4; see `Docs/build-and-test.md`).
///
/// 2. **TTS weights present** — a cheap filesystem check (`TTSWeights.present`)
///    against the SwiftAcervo model-cache directory the CI runner primes (S10). It
///    NEVER loads a model or fetches a manifest, so it can't trigger the network
///    hydration that strict-offline mode would throw on (the reason `tests.yml`
///    sets `TEST_RUNNER_ACERVO_OFFLINE=0`). Locally the weights are usually absent,
///    so the `.vox` tests skip here.
///
/// The `generate vox` and full-pipeline `echada cast` paths need BOTH models: the
/// candidate/lock steps load the Qwen3-TTS weights, and every audition sentence is
/// sourced exclusively from the Foundation Model (`CastVoiceGenerator` calls
/// `FoundationModelSentence.requireAvailable()`), so their gate is the conjunction
/// of both conditions. `generate prompt` needs only the Foundation Model.

// MARK: - TTS-weights presence check (filesystem only — no hydration)

/// Detects whether the Qwen3-TTS weights `generate vox` loads are already on disk
/// in the SwiftAcervo model cache. This is a pure directory/file existence probe:
/// it never constructs a model, opens a manifest for hydration, or touches the
/// network. It exists solely to decide whether the model-backed `.vox` tests can
/// run or must skip.
enum TTSWeights {

  /// SwiftAcervo CDN directory names (`== slugify(modelId)`) for the weights the
  /// vox pipeline loads: Base 1.7B + Base 0.6B (voice locking) and VoiceDesign
  /// 1.7B (Phase-A candidate generation). These mirror `ACERVO_CI_MODELS` in
  /// `.github/workflows/tests.yml`.
  static let requiredSlugs = [
    "mlx-community_Qwen3-TTS-12Hz-1.7B-Base-bf16",
    "mlx-community_Qwen3-TTS-12Hz-0.6B-Base-bf16",
    "mlx-community_Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16",
  ]

  /// Resolves the model-cache root from the environment the CI runner sets.
  ///
  /// `tests.yml` exports `TEST_RUNNER_ACERVO_MODELS_DIR`; xcodebuild strips the
  /// `TEST_RUNNER_` prefix before the xctest process runs, so inside the test the
  /// variable arrives as `ACERVO_MODELS_DIR` (the same name SwiftAcervo itself
  /// reads first). We check the stripped name first, then the prefixed one as a
  /// fallback for any harness that forwards it verbatim.
  static func modelsDirectory() -> URL? {
    let env = ProcessInfo.processInfo.environment
    for key in ["ACERVO_MODELS_DIR", "TEST_RUNNER_ACERVO_MODELS_DIR"] {
      if let path = env[key]?.trimmingCharacters(in: .whitespaces), !path.isEmpty {
        return URL(fileURLWithPath: path, isDirectory: true)
      }
    }
    return nil
  }

  /// `true` only when the cache dir is configured AND every required slug has a
  /// primed `manifest.json` on disk (actions/cache restores each model directory
  /// atomically, so a present manifest means the whole model is present). Computed
  /// once — the check is side-effect-free and stable for the test run.
  static let present: Bool = {
    guard let dir = modelsDirectory() else { return false }
    let fm = FileManager.default
    for slug in requiredSlugs {
      let manifest =
        dir.appendingPathComponent(slug, isDirectory: true)
        .appendingPathComponent("manifest.json")
      guard fm.fileExists(atPath: manifest.path) else { return false }
    }
    return true
  }()
}

// MARK: - Fixtures

private enum Fixtures {
  /// A one-character script — minimal on purpose so the Foundation-Model and
  /// MLX-TTS work stays fast and deterministic when the gated tests DO run.
  static let oneCharacterScript = """
    INT. STUDIO - NIGHT

    The room is quiet.

    NARR
    Welcome back to the show.

    NARR
    Tonight we keep it short.
    """

  /// A short two-block ALICE fixture with enough dialogue evidence for
  /// `generate prompt` to synthesize from, kept tiny to avoid model context
  /// overflow.
  static let aliceScript = """
    INT. HOUSE - DAY

    Some action sets the scene.

    ALICE
    Hello there, friend.

    ALICE
    It is a fine, quiet morning.
    """
}

/// Builds a fully-isolated temp project directory (no PROJECT.md, and none in any
/// ancestor — dodging the orchestrator's ancestor-discovery edge case) with an
/// `episodes/` folder holding the given scripts. Returns `(projectDir, projectFile)`.
private func makeIsolatedProject(scripts: [String: String]) throws -> (
  projectDir: URL, projectFile: URL
) {
  let base = FileManager.default.temporaryDirectory
    .appendingPathComponent("model-backed-\(UUID().uuidString)")
  let projectDir = base.appendingPathComponent("show")
  let episodesDir = projectDir.appendingPathComponent("episodes")
  try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
  for (name, content) in scripts {
    try content.write(
      to: episodesDir.appendingPathComponent(name), atomically: true, encoding: .utf8)
  }
  return (projectDir, projectDir.appendingPathComponent("PROJECT.md"))
}

// MARK: - Tests

@Suite("Model-backed generation — gated (skip when the model is absent)")
struct ModelBackedGenerationTests {

  /// **Gate: Foundation Model + TTS weights.**
  ///
  /// Drives `generate vox` twice against a single PROJECT.md — once for the 0.6B
  /// variant and once for 1.7B — so the second run APPENDS its embedding to the
  /// first run's bundle, yielding one multi-model `.vox`. Asserts the file is a
  /// valid, ready bundle carrying embeddings from two distinct models.
  @Test(
    "generate vox produces a valid multi-model .vox (0.6B + 1.7B)",
    .enabled(if: SystemLanguageModel.default.isAvailable && TTSWeights.present))
  func generateVoxProducesMultiModelVox() async throws {
    let (projectDir, projectFile) = try makeIsolatedProject(scripts: [:])
    defer { try? FileManager.default.removeItem(at: projectDir.deletingLastPathComponent()) }

    // A single cast member with a voice prompt (the input `generate vox` consumes).
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Multi-Model Vox",
      author: "Test",
      created: Date(timeIntervalSince1970: 0),
      episodesDir: "episodes",
      filePattern: FilePattern("*.fountain"),
      cast: [
        CastMember(
          character: "NARR",
          voiceDescription: "A calm, warm narrator with a measured, steady pace.",
          language: "en"
        )
      ]
    )
    try ProjectMarkdownParser().write(frontMatter: frontMatter, body: "", to: projectFile)

    // Two passes into the same PROJECT.md → one .vox with both model embeddings.
    for variant in ["0.6b", "1.7b"] {
      let cmd = try GenerateVoxCommand.parse([
        "--project", projectFile.path, "--tts-model", variant,
      ])
      try await cmd.run()
    }

    let voxURL = projectDir.appendingPathComponent("voices/NARR.vox")
    #expect(FileManager.default.fileExists(atPath: voxURL.path))

    let vox = try VoxFile(contentsOf: voxURL)
    #expect(vox.isValid)
    #expect(vox.isReady)

    let entries = vox.manifest.embeddingEntries ?? [:]
    let distinctModels = Set(entries.values.compactMap(\.model))
    #expect(
      distinctModels.count >= 2,
      "expected embeddings from both the 0.6B and 1.7B models, got: \(distinctModels)")

    // PROJECT.md now records the produced .vox under the member's voxalta voices.
    let (updated, _) = try ProjectMarkdownParser().parse(fileURL: projectFile)
    let narr = try #require(updated.cast?.first { $0.character == "NARR" })
    #expect(narr.voices["voxalta"] == ["voices/NARR.vox"])
  }

  /// **Gate: Foundation Model + TTS weights.**
  ///
  /// The full `echada cast` pipeline against an episodes dir with NO PROJECT.md.
  /// Asserts all four pipeline outputs: PROJECT.md created, cast populated
  /// (heuristic), `voicePrompt` written (Foundation Model), and a `.vox` produced
  /// (MLX). The whole `run()` is atomic — the prompt stage calls
  /// `VoicePromptSynthesizer.requireAvailable()` and the vox stage sources its
  /// audition sentence from the Foundation Model — so it can only complete where
  /// BOTH models are present; hence the conjunction gate. On any machine missing
  /// either model it skips rather than failing, honoring the overriding rule.
  @Test(
    "Full `echada cast` pipeline yields PROJECT.md, cast, voicePrompts, and .vox",
    .enabled(if: SystemLanguageModel.default.isAvailable && TTSWeights.present))
  func fullCastPipelineProducesAllFourOutputs() async throws {
    let (projectDir, projectFile) = try makeIsolatedProject(scripts: [
      "ep1.fountain": Fixtures.oneCharacterScript
    ])
    defer { try? FileManager.default.removeItem(at: projectDir.deletingLastPathComponent()) }

    #expect(!FileManager.default.fileExists(atPath: projectFile.path))

    let cmd = try CastCommand.parse(["--project", projectFile.path])
    try await cmd.run()

    // 1) PROJECT.md was bootstrapped.
    #expect(FileManager.default.fileExists(atPath: projectFile.path))
    let (frontMatter, _) = try ProjectMarkdownParser().parse(fileURL: projectFile)

    // 2) Cast populated heuristically from the screenplay.
    #expect(frontMatter.cast?.map(\.character) == ["NARR"])
    let narr = try #require(frontMatter.cast?.first { $0.character == "NARR" })

    // 3) A voicePrompt was written by the Foundation Model.
    let prompt = try #require(narr.voiceDescription)
    #expect(!prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

    // 4) A .vox file was produced by MLX TTS and recorded on the member.
    #expect(narr.voices["voxalta"] == ["voices/NARR.vox"])
    let voxURL = projectDir.appendingPathComponent("voices/NARR.vox")
    #expect(FileManager.default.fileExists(atPath: voxURL.path))
    let vox = try VoxFile(contentsOf: voxURL)
    #expect(vox.isValid)
    #expect(vox.isReady)
  }

  /// **Gate: Foundation Model only** (consistent with `FoundationModelSentenceTests`).
  ///
  /// `generate prompt` reads a character's dialogue and asks the on-device
  /// Foundation Model to write a `voicePrompt`. No TTS weights involved. Skips on
  /// hosted CI (no Apple Intelligence) — the accepted OQ-4 coverage gap — and runs
  /// locally on an Apple-Intelligence machine.
  @Test(
    "generate prompt writes a non-empty voicePrompt from dialogue",
    .enabled(if: SystemLanguageModel.default.isAvailable))
  func generatePromptWritesVoicePrompt() async throws {
    let (projectDir, projectFile) = try makeIsolatedProject(scripts: [
      "ep1.fountain": Fixtures.aliceScript
    ])
    defer { try? FileManager.default.removeItem(at: projectDir.deletingLastPathComponent()) }

    // Seed a PROJECT.md whose cast has ALICE with an empty voicePrompt to fill.
    let frontMatter = ProjectFrontMatter(
      type: "project",
      title: "Prompt Fixture",
      author: "Test",
      created: Date(timeIntervalSince1970: 0),
      episodesDir: "episodes",
      filePattern: FilePattern("*.fountain"),
      cast: [CastMember(character: "ALICE", language: "en")]
    )
    try ProjectMarkdownParser().write(frontMatter: frontMatter, body: "", to: projectFile)

    let cmd = try GeneratePromptCommand.parse(["--project", projectFile.path])
    try await cmd.run()

    let (updated, _) = try ProjectMarkdownParser().parse(fileURL: projectFile)
    let alice = try #require(updated.cast?.first { $0.character == "ALICE" })
    let prompt = try #require(alice.voiceDescription)
    #expect(!prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
  }
}
