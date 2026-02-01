/// A character extracted from a screenplay file.
public struct CharacterInfo: Codable, Sendable, Equatable {
    public let name: String
    public let description: String?
    public let voiceDescription: String?

    public init(name: String, description: String? = nil, voiceDescription: String? = nil) {
        self.name = name
        self.description = description
        self.voiceDescription = voiceDescription
    }
}
