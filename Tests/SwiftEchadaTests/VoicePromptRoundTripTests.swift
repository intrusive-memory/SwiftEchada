import Foundation
import SwiftReparto
import Testing

/// Tests that complex voice prompts survive the full pipeline from CAST.md YAML
/// through parse and re-serialization — the exact seam the `generate` stages
/// read the roster through since the CAST.md extraction (EC-12).
///
/// Regression test for: voicePrompt field was silently dropped during CastMember
/// deserialization (CodingKeys mismatch), causing all voices to be generated with
/// generic fallback descriptions like "A adult person with a MITCH voice".
@Suite("Voice Prompt Round-Trip Tests")
struct VoicePromptRoundTripTests {

  // MARK: - YAML → CastMember deserialization

  @Test func voicePromptFieldSurvivesYAMLParsing() throws {
    let yaml = """
      ---
      type: cast
      cast:
        - character: MITCH
          voicePrompt: "A warm, sardonic American male voice in his late 40s, smooth baritone with dry wit."
          voices:
            voxalta: voices/MITCH.vox
      ---
      """

    let document = try CastMarkdownParser().parse(content: yaml)

    let cast = document.cast
    #expect(cast.count == 1)

    let mitch = cast[0]
    #expect(mitch.character == "MITCH")

    // This is the critical assertion: voicePrompt must NOT be nil
    let prompt = try #require(
      mitch.voicePrompt,
      "voicePrompt was silently dropped during YAML parsing — CodingKeys mismatch")
    #expect(prompt.contains("sardonic"))
    #expect(prompt.contains("baritone"))
  }

  @Test func voiceDescriptionFieldAlsoWorks() throws {
    let yaml = """
      ---
      type: cast
      cast:
        - character: GILD
          voiceDescription: "A gruff detective voice, deep baritone."
          voices:
            voxalta: voices/GILD.vox
      ---
      """

    let document = try CastMarkdownParser().parse(content: yaml)

    let gild = try #require(document.cast.first)
    let prompt = try #require(
      gild.voicePrompt,
      "Legacy voiceDescription field should still be parsed")
    #expect(prompt.contains("gruff"))
    // The alias reads back through both spellings.
    #expect(gild.voiceDescription == gild.voicePrompt)
  }

  // MARK: - Serialization round-trip

  @Test func voicePromptSurvivesWriteAndReparse() throws {
    let yaml = """
      ---
      type: cast
      cast:
        - character: BILLY
          voicePrompt: "A flamboyant, theatrical gay male voice in his mid 40s, born into wealth. Bright, warm tenor with dramatic flair."
          voices:
            voxalta: voices/BILLY.vox
      ---
      """

    let parser = CastMarkdownParser()

    // Parse original
    let document = try parser.parse(content: yaml)
    let originalPrompt = try #require(document.cast.first?.voicePrompt)
    #expect(originalPrompt.contains("flamboyant"))

    // Re-serialize through the one writer allowed to emit CAST.md (D8)
    let regenerated = try parser.generate(document: document)

    // Re-parse the regenerated content
    let reparsed = try parser.parse(content: regenerated)
    let roundTrippedPrompt = try #require(
      reparsed.cast.first?.voicePrompt,
      "voicePrompt must survive write → re-parse round-trip")
    #expect(
      roundTrippedPrompt.contains("flamboyant"),
      "Rich prompt content lost during serialization round-trip")
    #expect(roundTrippedPrompt.contains("theatrical"))
  }
}
