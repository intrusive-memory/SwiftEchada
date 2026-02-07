import SwiftOnce

/// Typealiases to avoid name collisions between SwiftHablare and SwiftOnce modules.
/// Both modules define a `Voice` type, and both have a top-level type with the same
/// name as the module, making fully-qualified names impossible.
public typealias ElevenLabsClient = SwiftOnce
public typealias ElevenLabsHTTPClient = HTTPClient
typealias ElevenLabsVoice = Voice

/// ElevenLabs provider constants.
public enum ElevenLabsDefaults {
    /// The default ElevenLabs voice ID used when no specific voice is assigned.
    public static let defaultVoiceId = "Gsndh0O5AnuI2Hj3YUlA"

    /// The provider scheme for ElevenLabs voice URIs.
    public static let providerScheme = "elevenlabs"

    /// Builds a full voice URI for the default voice with the given language code.
    public static func defaultVoiceURI(languageCode: String = "en") -> String {
        "\(providerScheme)://\(languageCode)/\(defaultVoiceId)"
    }
}
