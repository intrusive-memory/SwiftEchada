import CryptoKit
import EchadaVoice
import Foundation
import SwiftReparto

/// Moves existing `.vox` files into the character record (EC-26).
///
/// ``plan(castURL:charactersDir:)`` is read-only and is the whole dry run.
/// ``apply(_:castURL:failAfter:)`` performs it in an order that never leaves a
/// half-migrated working copy: copy and verify every file, rewrite every
/// pointer in one CAST.md write, re-parse and check every new pointer, and
/// only then remove the old files. Any failure undoes the copies and restores
/// CAST.md byte for byte.
///
/// It never touches `manifest.json`; the next manifest refresh classifies the
/// moved files.
struct VoiceMigration {

  /// One member's planned move.
  struct Move: Equatable {
    let character: String
    /// Both relative to the CAST.md directory.
    let from: String
    let to: String
  }

  /// A pointer left alone, and why.
  struct Skip: Equatable {
    let character: String
    let path: String
    let reason: String
  }

  /// Something that stops the whole migration before anything is written.
  struct Blocker: Equatable {
    let character: String
    let reason: String
  }

  struct Plan: Equatable {
    var moves: [Move] = []
    var alreadyInPlace: [String] = []
    var skips: [Skip] = []
    var blockers: [Blocker] = []
    /// `.vox` files in a legacy `voices/` folder that no member points at.
    var strays: [String] = []

    var canApply: Bool { blockers.isEmpty }
  }

  /// The steps of ``apply(_:castURL:failAfter:)``, for injecting a failure in tests.
  enum Step: Equatable { case copied, pointersWritten, verified }

  enum MigrationError: LocalizedError, Equatable {
    case blocked([Blocker])
    case checksumMismatch(String)
    case pointerDoesNotResolve(String)
    case injected(Step)

    var errorDescription: String? {
      switch self {
      case .blocked(let blockers):
        return "Can't migrate: "
          + blockers.map { "\($0.character): \($0.reason)" }.joined(separator: "; ")
      case .checksumMismatch(let path):
        return "The copy of \(path) doesn't match the original."
      case .pointerDoesNotResolve(let path):
        return "After rewriting CAST.md, \(path) doesn't resolve to a file."
      case .injected(let step):
        return "Injected failure after \(step)."
      }
    }
  }

  // MARK: - Plan

  static func plan(
    castURL: URL, charactersDir: String, fileManager: FileManager = .default
  ) throws -> Plan {
    let castDir = castURL.deletingLastPathComponent().standardizedFileURL
    let cast = try CastMarkdownParser().parse(fileURL: castURL).cast
    var plan = Plan()
    var pointed: Set<String> = []
    var destinations: [String: String] = [:]

    for member in cast {
      guard let old = member.voices["voxalta"]?.first, !old.isEmpty else { continue }
      pointed.insert(old)

      // Shared voices outside the project aren't per-character assets.
      if old.hasPrefix("/") || old.split(separator: "/").contains("..") {
        plan.skips.append(
          Skip(character: member.character, path: old, reason: "outside the project folder"))
        continue
      }

      // The new path ignores the old pointer: rule 1 if there's a manifest,
      // otherwise rule 3.
      var unpointed = member
      unpointed.voices["voxalta"] = nil
      let location: VoiceLocation
      do {
        location = try VoiceLocation.resolve(
          for: unpointed, castDirectory: castDir, charactersDir: charactersDir,
          fileManager: fileManager)
      } catch {
        plan.blockers.append(
          Blocker(character: member.character, reason: error.localizedDescription))
        continue
      }

      let new = location.relativePath
      if new == old {
        plan.alreadyInPlace.append(member.character)
        continue
      }
      if let other = destinations[new] {
        plan.blockers.append(
          Blocker(character: member.character, reason: "maps to \(new), the same as \(other)"))
        continue
      }
      destinations[new] = member.character

      let source = castDir.appending(path: old)
      let target = castDir.appending(path: new)
      guard fileManager.fileExists(atPath: source.path) else {
        plan.skips.append(Skip(character: member.character, path: old, reason: "file not found"))
        continue
      }
      if fileManager.fileExists(atPath: target.path),
        try sha256(source) != sha256(target)
      {
        plan.blockers.append(
          Blocker(
            character: member.character,
            reason: "\(new) already exists with different contents"))
        continue
      }
      plan.moves.append(Move(character: member.character, from: old, to: new))
    }

    // EC-27's last check: a legacy voices/ folder still holding unclaimed files.
    let legacy = castDir.appending(path: "voices")
    if let names = try? fileManager.contentsOfDirectory(atPath: legacy.path) {
      plan.strays =
        names
        .filter { $0.hasSuffix(".vox") }
        .map { "voices/\($0)" }
        .filter { !pointed.contains($0) }
        .sorted()
    }
    return plan
  }

  // MARK: - Apply

  static func apply(
    _ plan: Plan, castURL: URL, fileManager: FileManager = .default, failAfter: Step? = nil
  ) throws {
    guard plan.canApply else { throw MigrationError.blocked(plan.blockers) }
    guard !plan.moves.isEmpty else { return }
    let castDir = castURL.deletingLastPathComponent().standardizedFileURL
    let originalCast = try Data(contentsOf: castURL)
    var copied: [URL] = []

    func rollback() {
      for url in copied { try? fileManager.removeItem(at: url) }
      try? originalCast.write(to: castURL, options: .atomic)
    }

    do {
      // 1. Copy each file and confirm the SHA-256 matches.
      for move in plan.moves {
        let source = castDir.appending(path: move.from)
        let target = castDir.appending(path: move.to)
        if fileManager.fileExists(atPath: target.path) { continue }  // identical, per plan
        try fileManager.createDirectory(
          at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: source, to: target)
        copied.append(target)
        guard try sha256(source) == sha256(target) else {
          throw MigrationError.checksumMismatch(move.from)
        }
      }
      if failAfter == .copied { throw MigrationError.injected(.copied) }

      // 2. Rewrite every pointer in one CastDocument write.
      let parser = CastMarkdownParser()
      var document = try parser.parse(fileURL: castURL)
      let newPath = Dictionary(uniqueKeysWithValues: plan.moves.map { ($0.character, $0.to) })
      for index in document.cast.indices {
        if let path = newPath[document.cast[index].character] {
          document.cast[index].voices["voxalta"] = [path]
        }
      }
      try parser.write(document: document, to: castURL)
      if failAfter == .pointersWritten { throw MigrationError.injected(.pointersWritten) }

      // 3. Re-parse and confirm every new pointer resolves.
      let reread = try parser.parse(fileURL: castURL).cast
      for move in plan.moves {
        guard
          let pointer = reread.first(where: { $0.character == move.character })?
            .voices["voxalta"]?.first,
          pointer == move.to,
          fileManager.fileExists(atPath: castDir.appending(path: pointer).path)
        else { throw MigrationError.pointerDoesNotResolve(move.to) }
      }
      if failAfter == .verified { throw MigrationError.injected(.verified) }
    } catch {
      rollback()
      throw error
    }

    // 4. Only then remove the old files.
    for move in plan.moves {
      try? fileManager.removeItem(at: castDir.appending(path: move.from))
    }
  }

  private static func sha256(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
  }
}
