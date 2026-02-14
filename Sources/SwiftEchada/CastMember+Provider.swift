import SwiftProyecto

extension CastMember {

    /// Extracts the provider scheme from a voice URI (e.g. "apple" from "apple://com.apple.voice.premium.en-US.Ava").
    /// Returns `nil` for malformed URIs without `://`.
    static func provider(from voiceURI: String) -> String? {
        guard let range = voiceURI.range(of: "://") else { return nil }
        let scheme = voiceURI[voiceURI.startIndex..<range.lowerBound]
        guard !scheme.isEmpty else { return nil }
        return scheme.lowercased()
    }

    /// Returns `true` if this cast member already has a voice assigned for the given provider.
    func hasVoice(for providerId: String) -> Bool {
        let target = providerId.lowercased()
        return voices.contains { Self.provider(from: $0) == target }
    }

    /// Returns an updated voices array where any existing voice for `providerId` is replaced
    /// by `newURI`, preserving all other voices. If no voice for that provider exists, appends
    /// `newURI` to the end.
    func voicesReplacingProvider(_ providerId: String, with newURI: String) -> [String] {
        let target = providerId.lowercased()
        var replaced = false
        var result: [String] = []

        for uri in voices {
            if Self.provider(from: uri) == target {
                if !replaced {
                    result.append(newURI)
                    replaced = true
                }
                // Skip additional voices for same provider (collapse to one)
            } else {
                result.append(uri)
            }
        }

        if !replaced {
            result.append(newURI)
        }

        return result
    }
}
