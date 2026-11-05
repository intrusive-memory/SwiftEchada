import EchadaVoice
import Foundation
import SwiftHablare
import SwiftProyecto
import SwiftReparto

/// Typed failures of `echada voices design` (EL-4.2, EL-4.3, EL-4.6).
enum VoicesDesignError: LocalizedError, Equatable {
  case noCharacters(String)
  case unknownCharacter(String, available: [String])
  case missingVoicePrompt(character: String)
  case noSampleText(character: String)
  case invalidSampleText(character: String, count: Int)
  case slotShortfall(needed: Int, free: Int, limit: Int, used: Int, characters: [String])
  case slotsUnavailable
  case designRejected(character: String, reason: String)
  case candidatesDirRequired
  case pickNeedsCandidatesDir
  case pickNotFound(id: String, dir: String)
  case pickAmbiguousCharacter(id: String, characters: [String])
  case pickNeedsFreeSlot(character: String)
  case previewMissing(path: String)
  case oldVoiceNotDeleted(character: String, voiceId: String, reason: String)

  var errorDescription: String? {
    switch self {
    case .noCharacters(let why):
      return "No characters to design: \(why)"
    case .unknownCharacter(let name, let available):
      return
        "Character '\(name)' not found in CAST.md. Available: \(available.joined(separator: ", "))"
    case .missingVoicePrompt(let character):
      return "\(character): no voicePrompt in CAST.md; run `echada generate prompt` first."
    case .noSampleText(let character):
      return
        "\(character): no dialogue line of 100-1,000 characters found in the project's episodes, "
        + "and no --sample-text was given. echada never invents sample text."
    case .invalidSampleText(let character, let count):
      return
        "\(character): ElevenLabs needs sample text of 100-1,000 characters; --sample-text has \(count)."
    case .slotShortfall(let needed, let free, let limit, let used, let characters):
      let short = needed - free
      return """
        Refusing to design \(needed) voice(s): only \(free) free voice slot(s) \
        (voice_limit \(limit) - voice_slots_used \(used)); short by \(short).
        Characters: \(characters.joined(separator: ", "))
        Cheapest fixes:
          - leave minor roles on VoxAlta (omit them, or use --role to narrow the set)
          - delete unused voices in your ElevenLabs account to free \(short) slot(s)
        """
    case .slotsUnavailable:
      return "ElevenLabs did not report voice slot usage for this account."
    case .designRejected(let character, let reason):
      return "\(character): ElevenLabs rejected the voice design: \(reason)"
    case .candidatesDirRequired:
      return
        "--candidates-dir <dir> is required: previews are written there so a person can listen "
        + "before `--pick <generated_voice_id>` spends a voice slot."
    case .pickNeedsCandidatesDir:
      return "--pick needs --candidates-dir to find the persisted preview."
    case .pickNotFound(let id, let dir):
      return "No candidate with generated_voice_id '\(id)' in \(dir)/index.json."
    case .pickAmbiguousCharacter(let id, let characters):
      return
        "generated_voice_id '\(id)' appears for several characters (\(characters.joined(separator: ", "))); name the CHARACTER."
    case .pickNeedsFreeSlot(let character):
      return
        "\(character): no free voice slot to save the new voice (the old voice is deleted only "
        + "after the new one is saved). Delete an unused voice in your ElevenLabs account first."
    case .previewMissing(let path):
      return "Persisted preview not found: \(path)"
    case .oldVoiceNotDeleted(let character, let voiceId, let reason):
      return
        "\(character): the new voice was saved and CAST.md updated, but the previous ElevenLabs "
        + "voice \(voiceId) could not be deleted (\(reason)); delete it by hand to free the slot."
    }
  }
}

/// The index `--candidates-dir` writes next to the preview WAVs.
struct VoiceCandidateIndex: Codable, Equatable {
  struct Entry: Codable, Equatable {
    var character: String
    var generatedVoiceId: String
    var previewFile: String
    var promptSent: String
    var designModel: String
    var sampleText: String

    enum CodingKeys: String, CodingKey {
      case character
      case generatedVoiceId = "generated_voice_id"
      case previewFile = "preview_file"
      case promptSent = "prompt_sent"
      case designModel = "design_model"
      case sampleText = "sample_text"
    }
  }

  static let fileName = "index.json"
  var project: String
  var candidates: [Entry]

  static func load(from dir: URL) throws -> VoiceCandidateIndex? {
    let url = dir.appendingPathComponent(fileName)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try JSONDecoder().decode(VoiceCandidateIndex.self, from: Data(contentsOf: url))
  }

  func write(to dir: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(self).write(
      to: dir.appendingPathComponent(Self.fileName), options: .atomic)
  }
}

/// The work of `echada voices design`, with the ElevenLabs seam injected so tests run offline.
struct VoicesDesignRunner {
  var projectURL: URL
  var castName: String
  var characters: [String]
  var roles: [String]
  var sampleTextOverride: String?
  var designModel: String
  var candidatesDir: String?
  var pick: String?
  var backend: any ElevenLabsBackend
  var log: @Sendable (String) -> Void = { print($0) }

  /// Outcome of a design run: characters whose design failed (the run continued past them).
  struct Outcome: Equatable {
    var designed: [String] = []
    var failures: [VoicesDesignError] = []
  }

  struct Context {
    var projectDir: URL
    var castURL: URL
    var title: String
    var frontMatter: ProjectFrontMatter
    var roster: [CastMember]
    var charactersDir: String
  }

  // MARK: - Entry

  @discardableResult
  func run() async throws -> Outcome {
    let context = try loadContext()
    if let pick {
      try await runPick(pick, context: context)
      return Outcome()
    }
    return try await runDesign(context: context)
  }

  private func loadContext() throws -> Context {
    let projectDir = projectURL.deletingLastPathComponent()
    let castURL = try CastFile.resolve(named: castName, in: projectDir)
    guard FileManager.default.fileExists(atPath: castURL.path) else {
      throw VoicesDesignError.noCharacters("cast file not found: \(castURL.path)")
    }
    let (frontMatter, _) = try ProjectMarkdownParser().parse(fileURL: projectURL)
    let document = try CastMarkdownParser().parse(fileURL: castURL)
    let charactersDir = try PersonajeSettings.read(fileURL: projectURL).resolvedCharactersDir
    return Context(
      projectDir: projectDir, castURL: castURL, title: frontMatter.title,
      frontMatter: frontMatter, roster: document.cast, charactersDir: charactersDir)
  }

  // MARK: - Selection (EL-4.2)

  static func provider(of member: CastMember) -> String? {
    guard let value = member[extra: "provider"], !value.isNull else { return nil }
    return try? value.decode(String.self)
  }

  private func select(from roster: [CastMember]) throws -> [CastMember] {
    var selected: [CastMember]
    if !characters.isEmpty {
      selected = []
      for name in characters {
        guard
          let member = roster.first(where: {
            $0.character.localizedCaseInsensitiveCompare(name) == .orderedSame
          })
        else {
          throw VoicesDesignError.unknownCharacter(name, available: roster.map(\.character))
        }
        if !selected.contains(where: { $0.character == member.character }) {
          selected.append(member)
        }
      }
    } else {
      selected = roster.filter { Self.provider(of: $0) == ElevenLabsProviderID.value }
    }
    if !roles.isEmpty {
      let wanted = Set(roles.map { $0.trimmingCharacters(in: .whitespaces).lowercased() })
      selected = selected.filter { member in
        member.role.map { wanted.contains($0.rawValue) } ?? false
      }
    }
    guard !selected.isEmpty else {
      throw VoicesDesignError.noCharacters(
        characters.isEmpty
          ? "no cast member has `provider: elevenlabs`"
            + (roles.isEmpty ? "" : " with role \(roles.joined(separator: ","))")
          : "none of the named characters match the --role filter")
    }
    return selected
  }

  // MARK: - Sample text (EL-4.3)

  /// The character's first dialogue line of 100-1,000 characters from the episodes, else
  /// `--sample-text`. Never invented.
  func sampleText(for member: CastMember, context: Context) throws -> String {
    let range = ElevenLabsSampleText.range
    for file in SourceMaterialLocator.episodeFiles(
      projectDirectory: context.projectDir, frontMatter: context.frontMatter)
    {
      guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
      let evidence = DialogueExtractor.evidence(for: member.character, in: text)
      if let line = evidence.dialogue.first(where: { range.contains($0.count) }) { return line }
    }
    if let override = sampleTextOverride {
      guard range.contains(override.count) else {
        throw VoicesDesignError.invalidSampleText(
          character: member.character, count: override.count)
      }
      return override
    }
    throw VoicesDesignError.noSampleText(character: member.character)
  }

  // MARK: - Design (step 1)

  private func runDesign(context: Context) async throws -> Outcome {
    guard let candidatesDir else { throw VoicesDesignError.candidatesDirRequired }
    let selected = try select(from: context.roster)

    // Resolve every prompt and sample before spending anything.
    struct Job {
      var member: CastMember
      var prompt: String
      var sample: String
    }
    var jobs: [Job] = []
    var outcome = Outcome()
    for member in selected {
      guard let prompt = member.voicePrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
        !prompt.isEmpty
      else {
        outcome.failures.append(.missingVoicePrompt(character: member.character))
        continue
      }
      do {
        jobs.append(
          Job(member: member, prompt: prompt, sample: try sampleText(for: member, context: context))
        )
      } catch let error as VoicesDesignError {
        outcome.failures.append(error)
      }
    }

    // EL-4.2: refuse when designs exceed free slots.
    let slots = try await backend.slots()
    if jobs.count > slots.free {
      throw VoicesDesignError.slotShortfall(
        needed: jobs.count, free: slots.free, limit: slots.limit, used: slots.used,
        characters: jobs.map(\.member.character))
    }

    // EL-4.6: cost before the calls.
    let cost = jobs.reduce(0) { $0 + backend.estimateDesignCost(characters: $1.sample.count) }
    let remaining = await backend.remainingCredits()
    log(
      "Designing \(jobs.count) voice(s) with \(designModel): estimated \(cost) credits"
        + (remaining.map { " (\($0) remaining)" } ?? "")
        + "; \(slots.free) of \(slots.limit) voice slots free. Previews do not use a slot.")

    let dir = URL(fileURLWithPath: candidatesDir, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    var index =
      try VoiceCandidateIndex.load(from: dir)
      ?? VoiceCandidateIndex(project: context.title, candidates: [])
    index.project = context.title

    for job in jobs {
      let character = job.member.character
      let designer = backend.designer(
        voiceName: Self.voiceName(project: context.title, character: character),
        designModel: designModel)
      let candidates: [VoiceCandidate]
      do {
        candidates = try await designer.design(
          VoiceDesignRequest(description: job.prompt, sampleText: job.sample))
      } catch {
        let failure = VoicesDesignError.designRejected(
          character: character, reason: Self.describe(error))
        log("  ✗ \(failure.localizedDescription)")
        outcome.failures.append(failure)
        continue
      }
      let safe = try VoiceLocation.fileName(for: character)
      index.candidates.removeAll { $0.character == character }
      for (offset, candidate) in candidates.enumerated() {
        let id = candidate.handle.identifier
        let fileName = "\(safe)-\(offset + 1)-\(Self.fileSafe(id)).wav"
        try candidate.preview.data.write(to: dir.appendingPathComponent(fileName), options: .atomic)
        index.candidates.append(
          VoiceCandidateIndex.Entry(
            character: character, generatedVoiceId: id, previewFile: fileName,
            promptSent: candidate.promptSent, designModel: designModel, sampleText: job.sample))
        log("  \(character): \(id)  \(fileName)")
      }
      outcome.designed.append(character)
    }
    try index.write(to: dir)
    log(
      "Wrote \(index.candidates.count) candidate(s) and \(VoiceCandidateIndex.fileName) to \(dir.path)"
    )
    log(
      "Listen, then: echada voices design --candidates-dir \(candidatesDir) --pick <generated_voice_id>"
    )
    return outcome
  }

  // MARK: - Pick (step 2, EL-4.4/4.5)

  private func runPick(_ id: String, context: Context) async throws {
    guard let candidatesDir else { throw VoicesDesignError.pickNeedsCandidatesDir }
    let dir = URL(fileURLWithPath: candidatesDir, isDirectory: true)
    guard let index = try VoiceCandidateIndex.load(from: dir) else {
      throw VoicesDesignError.pickNotFound(id: id, dir: candidatesDir)
    }
    var matches = index.candidates.filter { $0.generatedVoiceId == id }
    if !characters.isEmpty {
      matches = matches.filter { entry in
        characters.contains { $0.localizedCaseInsensitiveCompare(entry.character) == .orderedSame }
      }
    }
    guard let entry = matches.first else {
      throw VoicesDesignError.pickNotFound(id: id, dir: candidatesDir)
    }
    guard Set(matches.map(\.character)).count == 1 else {
      throw VoicesDesignError.pickAmbiguousCharacter(id: id, characters: matches.map(\.character))
    }
    guard let member = context.roster.first(where: { $0.character == entry.character }) else {
      throw VoicesDesignError.unknownCharacter(
        entry.character, available: context.roster.map(\.character))
    }
    let character = member.character

    let slots = try await backend.slots()
    guard slots.free >= 1 else { throw VoicesDesignError.pickNeedsFreeSlot(character: character) }

    let previewURL = dir.appendingPathComponent(entry.previewFile)
    guard let wav = try? Data(contentsOf: previewURL) else {
      throw VoicesDesignError.previewMissing(path: previewURL.path)
    }
    let candidate = try backend.candidate(
      generatedVoiceId: entry.generatedVoiceId, previewWAV: wav, designModel: entry.designModel,
      sampleText: entry.sampleText, description: entry.promptSent)

    // Open the character's existing .vox so the qwen3-tts entries survive; create one if none.
    let location = try voxLocation(for: member, context: context)
    let voiceName = Self.voiceName(project: context.title, character: character)
    var asset: VoiceAsset
    if FileManager.default.fileExists(atPath: location.url.path) {
      asset = try VoiceAsset(contentsOf: location.url)
    } else {
      asset = VoiceAsset(
        name: voiceName, description: member.voicePrompt ?? entry.promptSent)
    }
    // Only a voice this tool designed (recorded in the .vox) is ever deleted on redesign;
    // a bare library id in CAST.md belongs to the library.
    let oldVoiceId =
      asset.extensionFields(forEngine: ElevenLabsProviderID.value)?["voice_id"] as? String

    let designer = backend.designer(voiceName: voiceName, designModel: entry.designModel)
    try await designer.save(candidate, into: &asset)
    try FileManager.default.createDirectory(
      at: location.url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try asset.write(to: location.url)
    let newVoiceId =
      asset.extensionFields(forEngine: ElevenLabsProviderID.value)?["voice_id"] as? String

    // CAST.md: parse → mutate one member → write.
    let castParser = CastMarkdownParser()
    var document = try castParser.parse(fileURL: context.castURL)
    guard let at = document.cast.firstIndex(where: { $0.character == character }) else {
      throw VoicesDesignError.unknownCharacter(character, available: document.cast.map(\.character))
    }
    document.cast[at].voices[ElevenLabsProviderID.value] = [location.relativePath]
    document.cast[at].setExtra(try AnyCodable(ElevenLabsProviderID.value), forKey: "provider")
    try castParser.write(document: document, to: context.castURL)
    log("\(character): saved \(voiceName) (\(newVoiceId ?? "?")) → \(location.relativePath)")

    // EL-4.5: the previous voice goes only after the new one is saved.
    if let oldVoiceId, oldVoiceId != newVoiceId {
      do {
        try await designer.delete(
          .catalog(pluginId: ElevenLabsProviderID.value, voiceId: oldVoiceId))
        log("\(character): deleted previous voice \(oldVoiceId)")
      } catch {
        throw VoicesDesignError.oldVoiceNotDeleted(
          character: character, voiceId: oldVoiceId, reason: Self.describe(error))
      }
    }
  }

  /// An existing ElevenLabs `.vox` pointer wins; otherwise the standard voice location.
  private func voxLocation(for member: CastMember, context: Context) throws -> (
    relativePath: String, url: URL
  ) {
    let castDir = context.castURL.deletingLastPathComponent()
    if let existing = member.voices[ElevenLabsProviderID.value]?.first, existing.hasSuffix(".vox") {
      let url =
        existing.hasPrefix("/")
        ? URL(fileURLWithPath: existing).standardizedFileURL
        : castDir.appending(path: existing).standardizedFileURL
      return (existing, url)
    }
    let resolved = try VoiceLocation.resolve(
      for: member, castDirectory: castDir, charactersDir: context.charactersDir)
    return (resolved.relativePath, resolved.url)
  }

  // MARK: - Helpers

  static func voiceName(project: String, character: String) -> String {
    "\(project) — \(character)"
  }

  static func describe(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? String(describing: error)
  }

  private static func fileSafe(_ id: String) -> String {
    String(id.map { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" ? $0 : "_" })
  }
}

enum ElevenLabsProviderID {
  static let value = "elevenlabs"
}

enum ElevenLabsSampleText {
  /// ElevenLabs requires the preview line to be 100-1,000 characters.
  static let range = 100...1000
}
