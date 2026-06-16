import Foundation
import SwiftProyecto
import Testing

@testable import EchadaCLICore

/// Covers `castingLanguages(for:explicitLanguages:)` — the per-member language
/// resolution that lets a single `echada cast` voice each character in its own
/// declared `member.language` instead of forcing the whole stack to English.
@Suite("Per-member casting-language resolution")
struct CastingLanguageResolutionTests {

  @Test("Explicit --language override wins and applies to every member")
  func explicitOverrideWins() {
    let maestra = CastMember(character: "MAESTRA", voiceDescription: "voz", language: "es-MX")
    // Even though the member declares es-MX, an explicit override replaces it.
    #expect(castingLanguages(for: maestra, explicitLanguages: ["fr", "it"]) == ["fr", "it"])
  }

  @Test("No override → member is cast in its own declared language")
  func fallsBackToMemberLanguage() {
    let maestra = CastMember(character: "MAESTRA", voiceDescription: "voz", language: "es-MX")
    // The es-MX tag is normalized (trimmed + lowercased) to match the --language path.
    #expect(castingLanguages(for: maestra, explicitLanguages: []) == ["es-mx"])
  }

  @Test("No override + no member language → defaults to English")
  func defaultsToEnglishWhenUnspecified() {
    let member = CastMember(character: "GHOST", voiceDescription: "spooky", language: nil)
    #expect(castingLanguages(for: member, explicitLanguages: []) == ["en"])
  }

  @Test("Whitespace-only member language is treated as absent → English")
  func blankMemberLanguageDefaultsToEnglish() {
    let member = CastMember(character: "GHOST", voiceDescription: "spooky", language: "   ")
    #expect(castingLanguages(for: member, explicitLanguages: []) == ["en"])
  }

  @Test("English narrator and Spanish teacher resolve independently in one pass")
  func mixedCastResolvesPerMember() {
    let narrador = CastMember(character: "NARRADOR", voiceDescription: "baritone", language: "en")
    let maestra = CastMember(character: "MAESTRA", voiceDescription: "voz", language: "es-MX")
    #expect(castingLanguages(for: narrador, explicitLanguages: []) == ["en"])
    #expect(castingLanguages(for: maestra, explicitLanguages: []) == ["es-mx"])
  }
}
