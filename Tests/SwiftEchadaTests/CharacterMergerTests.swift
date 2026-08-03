import SwiftReparto
import Testing

@testable import SwiftEchada

@Suite("CharacterMerger Tests")
struct CharacterMergerTests {

  let merger = CharacterMerger()

  @Test func dedupSameNameDifferentCase() {
    let extracted: [[CharacterInfo]] = [
      [CharacterInfo(name: "NARRATOR", description: "desc1")],
      [CharacterInfo(name: "narrator", description: "desc2")],
      [CharacterInfo(name: "Narrator", description: "desc3")],
    ]
    let result = merger.merge(extracted: extracted, existingCast: nil)
    #expect(result.count == 1)
    #expect(result[0].character == "NARRATOR")
  }

  @Test func preservesExistingVoiceAssignments() {
    let existing = [
      CastMember(
        character: "NARRATOR", actor: "John",
        voices: ["apple": ["com.apple.voice.premium.en-US.Ava"]]
      )
    ]
    let extracted: [[CharacterInfo]] = [
      [CharacterInfo(name: "NARRATOR", description: "desc")]
    ]
    let result = merger.merge(extracted: extracted, existingCast: existing)
    #expect(result.count == 1)
    #expect(result[0].voices == ["apple": ["com.apple.voice.premium.en-US.Ava"]])
    #expect(result[0].actor == "John")
  }

  @Test func newCharactersGetEmptyVoices() {
    let extracted: [[CharacterInfo]] = [
      [CharacterInfo(name: "BOB", description: "A friend")]
    ]
    let result = merger.merge(extracted: extracted, existingCast: nil)
    #expect(result.count == 1)
    #expect(result[0].voices.isEmpty)
    #expect(result[0].actor == nil)
  }

  @Test func alphabeticalSort() {
    let extracted: [[CharacterInfo]] = [
      [
        CharacterInfo(name: "ZELDA"),
        CharacterInfo(name: "ALICE"),
        CharacterInfo(name: "MIKE"),
      ]
    ]
    let result = merger.merge(extracted: extracted, existingCast: nil)
    #expect(result.map(\.character) == ["ALICE", "MIKE", "ZELDA"])
  }

  @Test func multipleFilesMerged() {
    let extracted: [[CharacterInfo]] = [
      [CharacterInfo(name: "ALICE"), CharacterInfo(name: "BOB")],
      [CharacterInfo(name: "BOB"), CharacterInfo(name: "CHARLIE")],
      [CharacterInfo(name: "ALICE"), CharacterInfo(name: "DAVE")],
    ]
    let result = merger.merge(extracted: extracted, existingCast: nil)
    #expect(result.count == 4)
    #expect(result.map(\.character) == ["ALICE", "BOB", "CHARLIE", "DAVE"])
  }

  @Test func voiceDescriptionFlowsThrough() {
    let extracted: [[CharacterInfo]] = [
      [
        CharacterInfo(
          name: "NARRATOR", description: "Storyteller", voiceDescription: "Deep warm baritone")
      ]
    ]
    let result = merger.merge(extracted: extracted, existingCast: nil)
    #expect(result.count == 1)
    #expect(result[0].voiceDescription == "Deep warm baritone")
  }

  @Test func existingCastNotInExtractedPreserved() {
    let existing = [
      CastMember(character: "OLD_CHAR", actor: nil, voices: ["voice": ["x"]])
    ]
    let extracted: [[CharacterInfo]] = [
      [CharacterInfo(name: "NEW_CHAR")]
    ]
    let result = merger.merge(extracted: extracted, existingCast: existing)
    #expect(result.count == 2)
    #expect(result.contains(where: { $0.character == "OLD_CHAR" }))
    #expect(result.contains(where: { $0.character == "NEW_CHAR" }))
  }

  /// Regression guard for the CastWriter bug (X-1): a merge driven by a single
  /// screenplay's discovered characters must NEVER prune the existing roster.
  /// One discovered character against a twelve-character existing cast must
  /// yield twelve members, every one of them intact.
  @Test func mergingOneDiscoveryAgainstTwelveExistingNeverPrunes() {
    let existing = (1...12).map { index in
      CastMember(
        character: "CHARACTER_\(index)",
        actor: "Actor \(index)",
        voicePrompt: "Prompt \(index)",
        voices: ["apple": ["voice-\(index)"]]
      )
    }
    let extracted: [[CharacterInfo]] = [
      [CharacterInfo(name: "CHARACTER_5", description: "Only one in this episode")]
    ]
    let result = merger.merge(extracted: extracted, existingCast: existing)
    #expect(result.count == 12)
    for index in 1...12 {
      let member = result.first(where: { $0.character == "CHARACTER_\(index)" })
      #expect(member != nil)
      #expect(member?.actor == "Actor \(index)")
      #expect(member?.voicePrompt == "Prompt \(index)")
      #expect(member?.voices == ["apple": ["voice-\(index)"]])
    }
  }

  /// The reconciliation seam is SwiftReparto's `merging(_:)` (RQ-14), which
  /// gap-fills: a matched existing member missing `voicePrompt` gains the
  /// discovered voice description, while fields it already has are untouched.
  @Test func matchedExistingMemberGainsMissingVoicePrompt() {
    let existing = [
      CastMember(character: "NARRATOR", actor: "John", voices: ["apple": ["ava"]])
    ]
    let extracted: [[CharacterInfo]] = [
      [CharacterInfo(name: "NARRATOR", voiceDescription: "Deep warm baritone")]
    ]
    let result = merger.merge(extracted: extracted, existingCast: existing)
    #expect(result.count == 1)
    #expect(result[0].voicePrompt == "Deep warm baritone")
    #expect(result[0].actor == "John")
    #expect(result[0].voices == ["apple": ["ava"]])
  }
}
