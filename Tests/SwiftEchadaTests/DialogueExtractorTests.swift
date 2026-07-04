import Foundation
import SwiftProyecto
import Testing

@testable import EchadaCLICore

@Suite("DialogueExtractor")
struct DialogueExtractorTests {

  let sampleScript = """
    INT. STUDY - NIGHT

    A desk with an open book.

    UNCLE FU
    The Tao that can be spoken is not the eternal Tao.

    NARRATOR (V.O.)
    He paused, weighing the silence.

    UNCLE FU (CONT'D)
    (softly)
    The name that can be named is not the eternal name.

    MAESTRA
    Io porto i libri a scuola.
    """

  @Test("extracts a character's dialogue lines in order")
  func extractsDialogue() {
    let evidence = DialogueExtractor.evidence(for: "UNCLE FU", in: sampleScript)
    #expect(
      evidence.dialogue == [
        "The Tao that can be spoken is not the eternal Tao.",
        "The name that can be named is not the eternal name.",
      ])
    #expect(evidence.blockCount == 2)
  }

  @Test("captures in-block parentheticals and cue extensions")
  func capturesParentheticals() {
    let evidence = DialogueExtractor.evidence(for: "UNCLE FU", in: sampleScript)
    #expect(evidence.parentheticals.contains("softly"))
    #expect(evidence.parentheticals.contains("CONT'D"))
    // The (softly) parenthetical must NOT leak into the spoken dialogue.
    #expect(!evidence.dialogue.contains { $0.contains("softly") })
  }

  @Test("does not attribute other characters' lines")
  func ignoresOtherCharacters() {
    let evidence = DialogueExtractor.evidence(for: "UNCLE FU", in: sampleScript)
    #expect(!evidence.dialogue.contains("Io porto i libri a scuola."))
    #expect(!evidence.dialogue.contains("He paused, weighing the silence."))
  }

  @Test("matches character names case- and whitespace-insensitively")
  func caseInsensitiveMatch() {
    let lower = DialogueExtractor.evidence(for: "uncle fu", in: sampleScript)
    #expect(lower.dialogue.count == 2)
    let padded = DialogueExtractor.evidence(for: "  UNCLE   FU ", in: sampleScript)
    #expect(padded.dialogue.count == 2)
  }

  @Test("V.O. cue extension is captured for the narrator")
  func narratorVoiceOver() {
    let evidence = DialogueExtractor.evidence(for: "NARRATOR", in: sampleScript)
    #expect(evidence.dialogue == ["He paused, weighing the silence."])
    #expect(evidence.parentheticals.contains("V.O."))
  }

  @Test("unknown character yields empty evidence")
  func unknownCharacter() {
    let evidence = DialogueExtractor.evidence(for: "GHOST", in: sampleScript)
    #expect(evidence.isEmpty)
    #expect(evidence.blockCount == 0)
  }

  @Test("a line that only looks like a cue but has no dialogue is not a false match")
  func requiresFollowingDialogue() {
    // "UNCLE FU" here is followed immediately by a blank line, so it is not a cue.
    let script = """
      UNCLE FU

      Some action paragraph that is not dialogue.
      """
    let evidence = DialogueExtractor.evidence(for: "UNCLE FU", in: script)
    #expect(evidence.isEmpty)
  }

  @Test("merge accumulates evidence across files")
  func mergeAccumulates() {
    var a = DialogueExtractor.evidence(for: "MAESTRA", in: sampleScript)
    let b = DialogueExtractor.evidence(for: "MAESTRA", in: sampleScript)
    a.merge(b)
    #expect(a.dialogue.count == 2)
    #expect(a.blockCount == 2)
  }
}

@Suite("VoicePromptSynthesizer pure logic")
struct VoicePromptSynthesizerTests {

  @Test("selectedDialogue dedups and prefers substantive lines")
  func selectDialogue() {
    let lines = [
      "Yes.", "No.", "Hmm.",
      "The mountains hold their silence through every passing season.",
      "I have walked this road a thousand times before.",
      "Tell me again about the river and the stone.",
      "The mountains hold their silence through every passing season.",  // dup
      "We gather at dawn to begin the long climb.",
      "Nothing here is ever quite as still as it first appears.",
    ]
    let selected = VoicePromptSynthesizer.selectedDialogue(lines)
    // Duplicate removed.
    #expect(Set(selected).count == selected.count)
    // Enough substantive lines (>=5) → short interjections dropped.
    #expect(!selected.contains("Yes."))
    #expect(selected.contains("I have walked this road a thousand times before."))
  }

  @Test("selectedDialogue falls back to all lines when few are substantive")
  func selectDialogueFallback() {
    let lines = ["Yes.", "No.", "Maybe so."]
    let selected = VoicePromptSynthesizer.selectedDialogue(lines)
    #expect(selected == ["Yes.", "No.", "Maybe so."])
  }

  @Test("selectedDialogue caps at the line budget")
  func selectDialogueCap() {
    let lines = (0..<100).map { "This is substantive dialogue line number \($0) here." }
    let selected = VoicePromptSynthesizer.selectedDialogue(lines)
    #expect(selected.count == VoicePromptSynthesizer.maxDialogueLines)
  }

  @Test("selectedDeliveryNotes dedups and caps")
  func deliveryNotes() {
    let notes = ["softly", "Softly", "angrily", "V.O.", "V.O.", "whispering"]
    let selected = VoicePromptSynthesizer.selectedDeliveryNotes(notes)
    // Case-insensitive dedup ("softly"/"Softly" collapse; "V.O." collapses).
    #expect(selected.count == 4)
  }

  @Test("sanitize strips quotes, labels, and collapses whitespace")
  func sanitizeCleansOutput() {
    #expect(
      VoicePromptSynthesizer.sanitize("  \"A warm, gravelly baritone.\"  ")
        == "A warm, gravelly baritone.")
    #expect(
      VoicePromptSynthesizer.sanitize("Description:  A bright, clipped alto.")
        == "A bright, clipped alto.")
    #expect(
      VoicePromptSynthesizer.sanitize("A voice\nwith broken\nlines.")
        == "A voice with broken lines.")
    #expect(VoicePromptSynthesizer.sanitize("   ") == nil)
  }

  @Test("buildPrompt includes character, gender, dialogue and delivery notes")
  func buildPromptContents() {
    var evidence = CharacterDialogueEvidence()
    evidence.dialogue = ["The river remembers every stone it has ever carried downstream."]
    evidence.parentheticals = ["wearily"]
    let prompt = VoicePromptSynthesizer.buildPrompt(
      character: "UNCLE FU",
      gender: .male,
      language: "en",
      projectTitle: "Meditations",
      projectDescription: nil,
      genre: "philosophy",
      evidence: evidence
    )
    #expect(prompt.contains("Character: UNCLE FU"))
    #expect(prompt.contains("Gender: male"))
    #expect(prompt.contains("genre: philosophy"))
    #expect(prompt.contains("The river remembers"))
    #expect(prompt.contains("Delivery notes: wearily"))
    // English → no native-accent clause.
    #expect(!prompt.contains("native"))
  }

  @Test("buildPrompt adds a native-accent clause for non-English languages")
  func buildPromptNonEnglish() {
    var evidence = CharacterDialogueEvidence()
    evidence.dialogue = ["Io porto i libri a scuola ogni mattina presto."]
    let prompt = VoicePromptSynthesizer.buildPrompt(
      character: "MAESTRA",
      gender: .female,
      language: "it",
      projectTitle: "Lingua",
      projectDescription: nil,
      genre: nil,
      evidence: evidence
    )
    #expect(prompt.contains("Spoken language: Italian"))
    #expect(prompt.lowercased().contains("native italian speaker"))
  }
}
