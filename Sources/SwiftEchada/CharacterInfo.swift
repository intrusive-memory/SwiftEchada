/// A character extracted from a screenplay file.
public struct CharacterInfo: Codable, Sendable, Equatable {
    public let name: String
    public let description: String?

    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}
