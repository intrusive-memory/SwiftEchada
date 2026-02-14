import SwiftProyecto

extension CastMember {

    /// Returns `true` if this cast member already has a voice assigned for the given provider.
    func hasVoice(for providerId: String) -> Bool {
        let target = providerId.lowercased()
        return voices.keys.contains { $0.lowercased() == target }
    }

    /// Returns an updated voices dictionary where the voice for `providerId` is set to `voiceId`.
    /// If a voice for that provider already exists, it is replaced. Other providers are preserved.
    func voicesReplacingProvider(_ providerId: String, with voiceId: String) -> [String: String] {
        var updated = voices
        updated[providerId] = voiceId
        return updated
    }
}
