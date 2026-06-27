import Foundation
@preconcurrency import MLX
@preconcurrency import MLXAudioTTS
@preconcurrency import MLXLMCommon
import SwiftProyecto
import SwiftVoxAlta
@preconcurrency import VoxFormat

import enum SwiftEchada.SwiftEchada

/// Maps a casting `--language` value to the `.vox` storage language tag.
///
/// English (`"en"`) is the language-less DEFAULT path, so it maps to `nil` —
/// preserving byte-for-byte equivalence with pre-language output. Any other
/// language is stored at its `<lang>`-segmented path. The generation/extraction
/// language strings (passed to `generate`/`createLock`) are kept verbatim; only
/// the storage tag collapses `"en"` to the default path.
func voxLanguageTag(for language: String) -> String? {
  language.lowercased() == "en" ? nil : language
}

/// Audits the language threaded into a TTS generation call. No-op unless
/// `verbose` is set, so it ships in release builds behind the `--verbose` flag.
///
/// Verifies the two things that silently break in-language generation:
/// 1. **Passed correctly** — prints the resolved ``TTSLanguage`` case and the
///    exact `modelName` string handed to `Qwen3TTSModel.generate(language:)`.
/// 2. **Format the recipient understands** — checks that `modelName` is an
///    actual key in the *loaded model's* `codec_language_id` map via
///    `recognizesLanguage(_:)`. A miss means the model emits no language token
///    and generates UN-CONDITIONED audio with no error, so the line is flagged.
///
/// Emitted on stderr with the same `[lang]` prefix SwiftVoxAlta's own
/// ``TTSLanguage/trace(_:_:)`` uses, so the value can be followed across the
/// stack.
func logLanguageAudit(
  _ language: TTSLanguage, model: Qwen3TTSModel, site: String, verbose: Bool
) {
  guard verbose else { return }
  let key = language.modelName
  let recognized = model.recognizesLanguage(key)
  let accepted = model.supportedLanguageKeys.sorted().joined(separator: ", ")
  var line =
    "[lang] \(site): TTSLanguage.\(language.rawValue) → "
    + "generate(language: \"\(key)\") recognized=\(recognized)"
  if !recognized {
    line += " ⚠️ NOT a codec_language_id key — generation will be UN-CONDITIONED"
  }
  line += " (model accepts: \(accepted.isEmpty ? "<none>" : accepted))"
  FileHandle.standardError.write(Data((line + "\n").utf8))
}

/// Composes an optional accent/delivery directive onto a voice prompt string.
///
/// When `accent` is `nil` or empty (after trimming whitespace), the `base`
/// prompt is returned verbatim — preserving byte-for-byte equivalence with the
/// no-accent path. When a non-empty accent is supplied it is appended to `base`
/// with a clear delimiter so VoiceDesign can pick up both the character voice
/// and the delivery style.
///
/// - Parameters:
///   - base: The character's voice prompt string.
///   - accent: An optional accent/delivery directive (e.g. `"slow southern drawl"`).
/// - Returns: The composed prompt, or `base` unchanged when accent is absent.
func composeVoicePrompt(base: String, accent: String?) -> String {
  guard let trimmed = accent?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else {
    return base
  }
  return "\(base) — accent/delivery: \(trimmed)"
}

/// Errors thrown by CastVoiceGenerator.
enum CastVoiceGeneratorError: LocalizedError {
  case unsupportedTTSModel(String, supported: [String])
  case existingVoxUnreadable(path: String, underlying: Error)

  var errorDescription: String? {
    switch self {
    case .unsupportedTTSModel(let value, let supported):
      return
        "Unsupported TTS model variant '\(value)'. Supported values: \(supported.joined(separator: ", "))"
    case .existingVoxUnreadable(let path, let underlying):
      return
        "Existing voice bundle at '\(path)' could not be opened: \(underlying.localizedDescription). Refusing to overwrite — re-run with --force-regenerate to discard it."
    }
  }
}

/// Decision outcome for whether a character's existing `.vox` should be skipped
/// or fed through the generation pipeline (so the requested variant's embedding
/// can be added to the existing bundle).
enum VoxGenerationDecision: Equatable {
  /// No existing file, or `--force-regenerate` was set, or the requested variant
  /// is missing from the existing bundle. Run Phase A/B for this member.
  case generate
  /// The existing `.vox` already contains the requested variant. Skip.
  case skipExistingHasVariant
  /// The existing `.vox` is corrupt / unreadable. Don't silently overwrite —
  /// surface the error and increment skippedCount.
  case skipExistingUnreadable
}

/// Resolves the localized voice prompt for a BCP-47 `language` tag, trying the
/// exact tag first and then its base subtag.
///
/// `CastMember.voice(for:)` is an exact (lowercased) dictionary lookup, so a
/// regional request like `"es-MX"` misses a prompt stored under the documented
/// base key `voices["es"]`. This helper mirrors the sample-sentence path, which
/// already treats regional tags (`es-MX`) by their base language (`es`) via the
/// same `split(separator: "-").first` derivation.
///
/// - Returns: The localized prompt stored under the exact tag, else under its
///   base subtag, else `nil` when neither key exists. (Does not fall through to
///   `voiceDescription` — callers layer that fallback themselves.)
func localizedVoicePrompt(for member: CastMember, language: String) -> String? {
  if let exact = member.voice(for: language) {
    return exact
  }
  let base = language.split(separator: "-").first.map(String.init) ?? language
  // When `base == language` the exact lookup above already covered it.
  return base == language ? nil : member.voice(for: base)
}

/// Resolves the BCP-47 language(s) to cast a member into.
///
/// When the caller supplied an explicit `--language` list (`explicitLanguages`
/// non-empty), that list wins and is applied uniformly to every member — this is
/// the multi-embedding "casting loop" mechanism (run once per language to stack
/// several language-keyed embeddings into one `.vox`).
///
/// When no explicit list was given (`explicitLanguages` empty), each member is
/// cast in its OWN declared `member.language` — so a Spanish teacher (`es-MX`) is
/// voiced in Spanish and an English narrator (`en`) in English from a single
/// `echada cast`. This honors `CastMember.language` end-to-end (audition sentence,
/// VoiceDesign language token, clone-prompt extraction, and `.vox` storage key)
/// instead of silently forcing the whole stack to English.
///
/// The member's tag is trimmed and lowercased to match the explicit-flag path
/// (`CastCommand.resolvedLanguages`). Falls back to `"en"` only when a member
/// declares no language at all.
///
/// - Returns: A non-empty, order-preserving language list for this member.
func castingLanguages(for member: CastMember, explicitLanguages: [String]) -> [String] {
  if !explicitLanguages.isEmpty { return explicitLanguages }
  let normalized = member.language?.trimmingCharacters(in: .whitespaces).lowercased()
  if let normalized, !normalized.isEmpty { return [normalized] }
  return ["en"]
}

/// Pure decision function: which of the requested languages is this cast member
/// castable for?
///
/// A member is castable for language `L` if either:
///   - `localizedVoicePrompt(for:language:)` returns a non-nil value (a localized
///     voice prompt is stored under `L` or its base subtag — so `es-MX` matches a
///     documented `voices["es"]` entry), OR
///   - `member.voiceDescription` is non-empty (a base prompt exists that can be
///     used as a fallback for any language).
///
/// This function is side-effect-free and requires no model — safe to call from
/// unit tests without constructing a `CastVoiceGenerator`.
///
/// - Parameters:
///   - member: The cast member to evaluate.
///   - requestedLanguages: The set of BCP-47 language codes the caller wants to
///     cast into (e.g. `["en", "es"]`).
/// - Returns: The subset of `requestedLanguages` that the member can be cast
///   for. An empty array means the member should be skipped entirely.
func castableLanguages(for member: CastMember, requestedLanguages: [String]) -> [String] {
  let hasBasePrompt = member.voiceDescription.map { !$0.isEmpty } ?? false
  return requestedLanguages.filter { language in
    localizedVoicePrompt(for: member, language: language) != nil || hasBasePrompt
  }
}

/// Pure decision function: should we skip this character because the existing
/// `.vox` already has what we need?
///
/// Skipping is correct only when ALL of:
///   - the file exists,
///   - `--force-regenerate` is NOT set,
///   - the existing bundle's manifest declares an embedding matching
///     `ttsModelVariant` (matched via `VoxFile.supportsModel(_:)`).
///
/// Otherwise we fall through and let Phase A/B run; the existing block in
/// `generate(cast:)` will open the existing VoxFile and append the new
/// variant's clone-prompt + sample-audio to it.
func decideVoxGeneration(
  existingFileExists: Bool,
  forceRegenerate: Bool,
  ttsModelVariant: String,
  openExistingVox: () throws -> VoxFile
) -> VoxGenerationDecision {
  guard existingFileExists, !forceRegenerate else {
    return .generate
  }
  do {
    let existing = try openExistingVox()
    if existing.supportsModel(ttsModelVariant) {
      return .skipExistingHasVariant
    }
    return .generate
  } catch {
    return .skipExistingUnreadable
  }
}

/// Generates custom on-device voices for cast members using SwiftVoxAlta.
///
/// For each character with a non-empty voice prompt, generates a `.vox` bundle
/// containing a voice lock (speaker embedding) using the VoiceDesign → VoiceLock
/// → VoxExporter pipeline.
///
/// Generation is split into two phases to avoid model thrashing:
///   Phase A: Load VoiceDesign model once, generate all candidate WAVs
///   Phase B: Load Base model once, create all voice locks and export .vox bundles
struct CastVoiceGenerator {

  /// Result of a voice generation operation.
  struct GenerateResult: Sendable {
    let updatedCast: [CastMember]
    let generatedCount: Int
    let skippedCount: Int
  }

  /// Intermediate data from Phase A (candidate generation) needed by Phase B (locking).
  private struct CandidateResult {
    let index: Int
    let member: CastMember
    let voicePrompt: String
    let candidateWAV: Data
    let sampleSentence: String
    let language: String
    let voxPath: String
    let voxURL: URL
  }

  private let projectDirectory: URL
  private let forceRegenerate: Bool
  private let verbose: Bool
  private let ttsModelVariant: String
  /// Explicit BCP-47 language override from `--language`. Empty means "no
  /// override" — each member is then cast in its own `member.language` (see
  /// `castingLanguages(for:explicitLanguages:)`). When non-empty, this list is
  /// applied uniformly to every member. Each resolved language gets its own
  /// same-language reference sentence, candidate audio, clone prompt, and sample
  /// audio; `"en"` is stored at the language-less default path, others at their
  /// `<lang>`-segmented paths.
  private let explicitLanguages: [String]

  /// Optional accent/delivery directive applied to every character's voice prompt
  /// before the VoiceDesign call. `nil` means no accent — the default path is
  /// byte-for-byte unchanged. Flows ONLY through the `voice` argument to
  /// `qwenModel.generate`; never passed as `instruct:`.
  private let accent: String?

  init(
    projectDirectory: URL, forceRegenerate: Bool = false, verbose: Bool = false,
    ttsModelVariant: String = Qwen3TTSModelRepo.base1_7B.slug,
    languages: [String] = [],
    accent: String? = nil
  ) {
    self.projectDirectory = projectDirectory
    self.forceRegenerate = forceRegenerate
    self.verbose = verbose
    self.ttsModelVariant = ttsModelVariant
    self.explicitLanguages = languages
    self.accent = accent
  }

  /// The default model size slug.
  static let defaultModelSlug = Qwen3TTSModelRepo.base1_7B.slug

  /// Known TTS model variant strings.
  static let supportedVariants = Qwen3TTSModelRepo.supportedSlugs

  /// Resolves the TTS model variant string to a `Qwen3TTSModelRepo`.
  private func resolvedModelRepo() throws -> Qwen3TTSModelRepo {
    guard let repo = Qwen3TTSModelRepo(slug: ttsModelVariant) else {
      throw CastVoiceGeneratorError.unsupportedTTSModel(
        ttsModelVariant,
        supported: Self.supportedVariants.sorted()
      )
    }
    return repo
  }

  /// Generate .vox files for each cast member with a non-empty voice prompt.
  ///
  /// Members without a `voiceDescription` (or with an empty one) are silently skipped.
  func generate(cast: [CastMember]) async throws -> GenerateResult {
    // Audition sentences are sourced exclusively from the on-device Foundation
    // Model — fail fast with a clear configuration error before any expensive
    // model loading if Apple Intelligence isn't available.
    try FoundationModelSentence.requireAvailable()

    let voicesDir = projectDirectory.appending(path: "voices")
    try FileManager.default.createDirectory(at: voicesDir, withIntermediateDirectories: true)

    let modelManager = VoxAltaModelManager()
    var updatedCast = cast
    var generatedCount = 0
    var skippedCount = 0

    // Determine which members need generation
    var membersToGenerate: [(index: Int, member: CastMember, voxPath: String, voxURL: URL)] = []

    for (index, member) in cast.enumerated() {
      // Skip members with no castable language — use castableLanguages() so that a member
      // with only localized voices (e.g. voices["es"]) but no voiceDescription is NOT skipped.
      // Each member's casting language(s) come from --language when set, else its own
      // member.language (so a single `echada cast` voices each character in its own tongue).
      let castable = castableLanguages(
        for: member,
        requestedLanguages: castingLanguages(for: member, explicitLanguages: explicitLanguages))
      guard !castable.isEmpty else {
        if verbose {
          print(
            "[verbose] Skipping \(member.character) — no voice prompt for any requested language")
        }
        skippedCount += 1
        continue
      }

      let sanitizedName = member.character.replacingOccurrences(of: " ", with: "_")
      let voxPath = "voices/\(sanitizedName).vox"
      let voxURL = projectDirectory.appending(path: voxPath)

      let fileExists = FileManager.default.fileExists(atPath: voxURL.path)
      let decision = decideVoxGeneration(
        existingFileExists: fileExists,
        forceRegenerate: forceRegenerate,
        ttsModelVariant: ttsModelVariant,
        openExistingVox: { try VoxFile(contentsOf: voxURL) }
      )

      switch decision {
      case .skipExistingHasVariant:
        if verbose {
          print(
            "[verbose] Skipping \(member.character) — \(voxPath) already has \(ttsModelVariant) embedding"
          )
        }
        if member.voices["voxalta"] == nil {
          updatedCast[index].voices = {
            var v = member.voices
            v["voxalta"] = [voxPath]
            return v
          }()
        }
        continue

      case .skipExistingUnreadable:
        print(
          "  Error: existing \(voxPath) for \(member.character) could not be opened. "
            + "Refusing to overwrite — re-run with --force-regenerate to discard it."
        )
        skippedCount += 1
        continue

      case .generate:
        if verbose, fileExists, !forceRegenerate {
          print(
            "[verbose] \(member.character) — \(voxPath) exists but lacks \(ttsModelVariant); will append embedding"
          )
        }
        membersToGenerate.append((index, member, voxPath, voxURL))
      }
    }

    guard !membersToGenerate.isEmpty else {
      return GenerateResult(updatedCast: updatedCast, generatedCount: 0, skippedCount: skippedCount)
    }

    // --- Phase A: Generate all candidate WAVs (VoiceDesign model loaded once) ---
    let totalCandidates = membersToGenerate.reduce(0) {
      $0 + castingLanguages(for: $1.member, explicitLanguages: explicitLanguages).count
    }
    print(
      "Phase A: Generating candidate audio (\(membersToGenerate.count) characters, \(totalCandidates) candidate(s), VoiceDesign 1.7B)..."
    )
    fflush(stdout)

    var candidates: [CandidateResult] = []

    for item in membersToGenerate {
      if verbose {
        print("[verbose] --- Generating voice: \(item.member.character) ---")
      }

      // One candidate per (member, language). Each language uses a same-language
      // reference sentence so the clone prompt is extracted from matching audio.
      // Prompt selection is per-language: use the localized voice prompt when available,
      // falling back to the base voiceDescription.
      for language in castingLanguages(for: item.member, explicitLanguages: explicitLanguages) {
        // Select the prompt for this specific language, then compose --accent onto it.
        // localizedVoicePrompt(for:language:) tries the exact tag then its base subtag
        // (so es-MX picks up a documented voices["es"] entry), and returns nil only when
        // no localized prompt exists at all — at which point we fall back to
        // voiceDescription. If neither exists (castableLanguages already filtered this
        // member in), skip this language gracefully.
        guard
          let selectedPrompt = localizedVoicePrompt(for: item.member, language: language)
            ?? item.member.voiceDescription
        else {
          if verbose {
            print(
              "[verbose] Skipping \(item.member.character) [\(language)] — no prompt available for this language"
            )
          }
          continue
        }
        let voicePrompt = composeVoicePrompt(base: selectedPrompt, accent: accent)

        // The in-language audition sentence comes exclusively from the on-device
        // Foundation Model. A configuration failure (Apple Intelligence off,
        // unsupported locale) propagates out to abort the whole run rather than
        // being swallowed as a per-character skip below.
        let sampleSentence = try await FoundationModelSentence.auditionSentence(language: language)
        if verbose {
          print("[verbose] Language: \(language) — prompt: \(voicePrompt)")
          print("[verbose] Language: \(language) — sample sentence: \(sampleSentence)")
        }

        do {
          let candidateWAV = try await Self.generateCandidateWithPrompt(
            voicePrompt: voicePrompt,
            modelManager: modelManager,
            sampleSentence: sampleSentence,
            language: try TTSLanguage(languageCode: language),
            verbose: verbose
          )

          if verbose {
            print("[verbose] Generated candidate WAV (\(candidateWAV.count) bytes)")
          }

          candidates.append(
            CandidateResult(
              index: item.index,
              member: item.member,
              voicePrompt: voicePrompt,
              candidateWAV: candidateWAV,
              sampleSentence: sampleSentence,
              language: language,
              voxPath: item.voxPath,
              voxURL: item.voxURL
            ))

        } catch {
          print("  Error generating voice for \(item.member.character) [\(language)]: \(error)")
          skippedCount += 1
        }
      }
    }

    // Unload VoiceDesign model before loading Base model
    await modelManager.unloadModel()

    // --- Phase B: Create voice locks and export .vox bundles (Base model loaded once) ---
    let modelRepo = try resolvedModelRepo()
    print(
      "Phase B: Creating voice locks (\(candidates.count) characters, Base \(ttsModelVariant))...")
    fflush(stdout)

    // Tracks `.vox` paths written during THIS run so that subsequent languages
    // (and, under --force-regenerate, the 2nd+ language for a member) append to
    // the freshly-written bundle instead of clobbering the prior language.
    var writtenThisRun: Set<String> = []

    for candidate in candidates {
      let languageTag = voxLanguageTag(for: candidate.language)
      if verbose {
        print(
          "[verbose] --- Locking voice: \(candidate.member.character) [\(candidate.language)] ---")
      }

      do {
        let voiceLock = try await VoiceLockManager.createLock(
          characterName: candidate.member.character,
          candidateAudio: candidate.candidateWAV,
          designInstruction: candidate.voicePrompt,
          modelManager: modelManager,
          sampleSentence: candidate.sampleSentence,
          modelRepo: modelRepo,
          language: try TTSLanguage(languageCode: candidate.language)
        )

        if verbose {
          print(
            "[verbose] Created voice lock for \(candidate.member.character) (model: \(ttsModelVariant), language: \(candidate.language))"
          )
        }

        let vox: VoxFile
        let fileExists = FileManager.default.fileExists(atPath: candidate.voxURL.path)
        let appendToExisting =
          writtenThisRun.contains(candidate.voxPath) || (!forceRegenerate && fileExists)
        if appendToExisting {
          vox = try VoxFile(contentsOf: candidate.voxURL)
          if verbose {
            print(
              "[verbose] Opened existing \(candidate.voxPath) to add \(ttsModelVariant) embedding [\(candidate.language)]"
            )
          }
        } else {
          vox = VoxFile(name: candidate.member.character, description: candidate.voicePrompt)
          vox.manifest.provenance = VoxManifest.Provenance(
            method: "synthesized",
            engine: "qwen3-tts",
            license: "CC0-1.0",
            notes:
              "Voice generated from text prompt via echada cast command (echada \(SwiftEchada.version))."
          )
        }

        try VoxExporter.addClonePrompt(
          to: vox, data: voiceLock.clonePromptData, modelRepo: modelRepo, language: languageTag)
        try VoxExporter.addSampleAudio(
          to: vox, data: candidate.candidateWAV, modelRepo: modelRepo, language: languageTag)
        try vox.write(to: candidate.voxURL)
        writtenThisRun.insert(candidate.voxPath)

        if verbose {
          print("[verbose] Exported \(candidate.voxPath) [\(candidate.language)]")
        }

        updatedCast[candidate.index].voices = {
          var v = candidate.member.voices
          v["voxalta"] = [candidate.voxPath]
          return v
        }()
        generatedCount += 1

      } catch {
        print(
          "  Error locking voice for \(candidate.member.character) [\(candidate.language)]: \(error)"
        )
        skippedCount += 1
      }
    }

    return GenerateResult(
      updatedCast: updatedCast,
      generatedCount: generatedCount,
      skippedCount: skippedCount
    )
  }

  /// Generate candidate audio using a voice prompt string directly.
  private static func generateCandidateWithPrompt(
    voicePrompt: String,
    modelManager: VoxAltaModelManager,
    sampleSentence: String,
    language: TTSLanguage = .english,
    verbose: Bool = false
  ) async throws -> Data {
    let model = try await modelManager.loadModel(.voiceDesign1_7B)

    guard let qwenModel = model as? Qwen3TTSModel else {
      throw VoiceDesignerError.modelCastFailed
    }

    logLanguageAudit(
      language, model: qwenModel, site: "cast.generateCandidateWithPrompt", verbose: verbose)

    let audioArray = try await qwenModel.generate(
      text: sampleSentence,
      voice: voicePrompt,
      language: language.modelName,
      generationParameters: GenerateParameters()
    )

    Stream.defaultStream(.gpu).synchronize()
    Memory.clearCache()

    return try AudioConversion.mlxArrayToWAVData(audioArray, sampleRate: qwenModel.sampleRate)
  }
}
