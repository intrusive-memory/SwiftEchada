import Foundation
import Testing

@testable import EchadaCLICore

@Suite("--language CLI surface")
struct LanguageOptionTests {

  // MARK: - voxLanguageTag (storage path mapping)

  @Test func englishMapsToLanguageLessDefault() {
    #expect(voxLanguageTag(for: "en") == nil)
    #expect(voxLanguageTag(for: "EN") == nil)
  }

  @Test func nonEnglishKeepsTag() {
    #expect(voxLanguageTag(for: "es") == "es")
    #expect(voxLanguageTag(for: "fr") == "fr")
  }

  // MARK: - CastCommand.resolvedLanguages normalization

  @Test func noFlagYieldsEmptyOverride() throws {
    // Empty == "no global override" → each member cast in its own member.language.
    let cmd = try CastCommand.parse([])
    #expect(try cmd.resolvedLanguages() == [])
  }

  @Test func repeatedFlagPreservesOrder() throws {
    let cmd = try CastCommand.parse(["--language", "es", "--language", "en"])
    #expect(try cmd.resolvedLanguages() == ["es", "en"])
  }

  @Test func lowercasesAndDeduplicates() throws {
    let cmd = try CastCommand.parse(["--language", "ES", "--language", "es", "--language", "EN"])
    #expect(try cmd.resolvedLanguages() == ["es", "en"])
  }

  @Test func emptyValueIsRejected() throws {
    let cmd = try CastCommand.parse(["--language", "  "])
    #expect(throws: (any Error).self) { try cmd.resolvedLanguages() }
  }
}
