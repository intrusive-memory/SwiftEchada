import EchadaVoice
import Foundation
import SwiftReparto
import Testing

@testable import EchadaCLICore

/// EC-23 (where a `.vox` goes) and EC-24 (what it's called), offline.
@Suite("Voice location — EC-23 rules and EC-24 names (offline)")
struct VoiceLocationTests {

  private func makeCastDirectory() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("voice-location-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  // MARK: - EC-23 rules

  @Test("Rule 1: a manifest pointer puts the .vox in that bundle's voice/ folder")
  func manifestPointerWins() throws {
    let dir = try makeCastDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    var member = CastMember(character: "SHANE")
    member.manifest = "characters/SHANE.dossier/manifest.json"
    member.voices = ["voxalta": ["voices/SHANE.vox"]]  // the manifest outranks an old pointer

    let location = try VoiceLocation.resolve(for: member, castDirectory: dir)
    #expect(location.rule == .manifest)
    #expect(location.relativePath == "characters/SHANE.dossier/voice/SHANE.vox")
    #expect(location.url.path.hasSuffix("/characters/SHANE.dossier/voice/SHANE.vox"))
  }

  @Test("Rule 2: an existing voxalta pointer is regenerated in place, never moved")
  func existingPointerIsKept() throws {
    let dir = try makeCastDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    let member = CastMember(character: "NARRATOR", voices: ["voxalta": ["voices/NARRATOR.vox"]])

    let location = try VoiceLocation.resolve(for: member, castDirectory: dir)
    #expect(location.rule == .existingPointer)
    #expect(location.relativePath == "voices/NARRATOR.vox")
  }

  @Test("Rule 3: a new member gets characters/<NAME>.dossier/voice/<NAME>.vox")
  func newMemberGetsDossierPath() throws {
    let dir = try makeCastDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let location = try VoiceLocation.resolve(
      for: CastMember(character: "THE PRACTITIONER"), castDirectory: dir)
    #expect(location.rule == .newDossier)
    #expect(
      location.relativePath == "characters/THE PRACTITIONER.dossier/voice/THE PRACTITIONER.vox")
  }

  @Test("Rule 3 honours a custom charactersDir")
  func customCharactersDir() throws {
    let dir = try makeCastDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let location = try VoiceLocation.resolve(
      for: CastMember(character: "MAYA"), castDirectory: dir, charactersDir: "cast/people")
    #expect(location.relativePath == "cast/people/MAYA.dossier/voice/MAYA.vox")
  }

  @Test("A multi-word, punctuated name keeps its spaces and punctuation exactly")
  func punctuatedNameIsKept() throws {
    let dir = try makeCastDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }

    let location = try VoiceLocation.resolve(
      for: CastMember(character: "DR. O'NEILL"), castDirectory: dir)
    #expect(location.relativePath == "characters/DR. O'NEILL.dossier/voice/DR. O'NEILL.vox")
    #expect(location.url.lastPathComponent == "DR. O'NEILL.vox")
  }

  @Test("A manifest outside the CAST.md directory is refused")
  func manifestOutsideIsRefused() throws {
    let dir = try makeCastDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    var member = CastMember(character: "SHANE")
    member.manifest = "../elsewhere/SHANE.dossier/manifest.json"

    #expect(throws: VoiceLocationError.self) {
      try VoiceLocation.resolve(for: member, castDirectory: dir)
    }
  }

  @Test("A folder that differs only by case refuses the write")
  func caseCollisionIsRefused() throws {
    let dir = try makeCastDirectory()
    defer { try? FileManager.default.removeItem(at: dir) }
    try FileManager.default.createDirectory(
      at: dir.appendingPathComponent("characters/The Practitioner.dossier"),
      withIntermediateDirectories: true)

    do {
      _ = try VoiceLocation.resolve(
        for: CastMember(character: "THE PRACTITIONER"), castDirectory: dir)
      Issue.record("expected a case collision")
    } catch let error as VoiceLocationError {
      guard case .caseCollision(_, let existing, let wanted) = error else {
        Issue.record("wrong error: \(error)")
        return
      }
      #expect(existing == "The Practitioner.dossier")
      #expect(wanted == "THE PRACTITIONER.dossier")
    }
  }

  // MARK: - EC-24 names

  @Test(
    "Names with no canonical form fail for that member, naming it",
    arguments: ["AC/DC", "TIME: NOW", ".HIDDEN"])
  func invalidNamesFail(name: String) {
    do {
      _ = try VoiceLocation.fileName(for: name)
      Issue.record("expected \(name) to be refused")
    } catch let error as VoiceLocationError {
      guard case .invalidName(let character, _) = error else {
        Issue.record("wrong error: \(error)")
        return
      }
      #expect(character == name)
      #expect(error.localizedDescription.contains("Rename the character"))
    } catch {
      Issue.record("unexpected error: \(error)")
    }
  }

  @Test("A name that isn't canonical yet points at reparto canonicalize")
  func nonCanonicalNameFails() {
    do {
      _ = try VoiceLocation.fileName(for: "The Practitioner")
      Issue.record("expected a non-canonical refusal")
    } catch let error as VoiceLocationError {
      #expect(
        error == .nonCanonicalName(character: "The Practitioner", canonical: "THE PRACTITIONER"))
      #expect(error.localizedDescription.contains("reparto canonicalize"))
    } catch {
      Issue.record("unexpected error: \(error)")
    }
  }

  // MARK: - PROJECT.md personaje.charactersDir

  @Test("personaje.charactersDir is read from PROJECT.md, defaulting to characters")
  func charactersDirFromProjectMd() throws {
    let withBlock = """
      ---
      type: project
      title: Show
      personaje:
        artStyle: ink
        charactersDir: people
      ---
      """
    #expect(try PersonajeSettings.read(content: withBlock).resolvedCharactersDir == "people")

    let without = """
      ---
      type: project
      title: Show
      ---
      """
    #expect(try PersonajeSettings.read(content: without).resolvedCharactersDir == "characters")
    #expect(
      try PersonajeSettings.read(content: "no front matter").resolvedCharactersDir == "characters")
  }
}
