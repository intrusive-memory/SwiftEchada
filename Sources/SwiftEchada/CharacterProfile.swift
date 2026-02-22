import Foundation
import SwiftProyecto

/// A detailed voice profile for a screenplay character, used to drive voice design.
public struct CharacterProfile: Codable, Sendable, Equatable {
    /// Character name (typically uppercase).
    public let name: String

    /// Character gender.
    public let gender: Gender

    /// Approximate age range (e.g. "30s", "elderly", "young adult").
    public let ageRange: String

    /// Full voice description text.
    public let description: String

    /// Individual voice traits (e.g. ["gravelly", "low pitch", "warm"]).
    public let voiceTraits: [String]

    /// Concise one-sentence summary for voice synthesis.
    public let summary: String

    public init(
        name: String,
        gender: Gender,
        ageRange: String,
        description: String,
        voiceTraits: [String],
        summary: String
    ) {
        self.name = name
        self.gender = gender
        self.ageRange = ageRange
        self.description = description
        self.voiceTraits = voiceTraits
        self.summary = summary
    }
}

/// Evidence gathered from screenplay text to support a character profile.
public struct CharacterEvidence: Codable, Sendable, Equatable {
    /// Key dialogue lines that reveal character traits.
    public let keyDialogue: [String]

    /// Stage directions / parentheticals mentioning the character.
    public let stageDirections: [String]

    /// Inferred emotional range from the text.
    public let emotionalRange: [String]

    public init(
        keyDialogue: [String] = [],
        stageDirections: [String] = [],
        emotionalRange: [String] = []
    ) {
        self.keyDialogue = keyDialogue
        self.stageDirections = stageDirections
        self.emotionalRange = emotionalRange
    }
}

extension CharacterProfile {
    /// The VoxFormat-compatible gender string ("male", "female", "nonbinary", "neutral").
    public var voxFormatGender: String {
        switch gender {
        case .male: "male"
        case .female: "female"
        case .nonBinary: "nonbinary"
        case .notSpecified: "neutral"
        }
    }
}
