import Testing
@testable import SwiftEchada

@Test func versionIsSet() {
    #expect(!SwiftEchada.version.isEmpty)
}

@Test func elevenLabsDefaultsAccessibleFromSwiftOnce() {
    // ElevenLabsDefaults is re-exported by SwiftEchada, sourced from SwiftOnce
    #expect(ElevenLabsDefaults.defaultVoiceId == "Gsndh0O5AnuI2Hj3YUlA")
    #expect(ElevenLabsDefaults.providerScheme == "elevenlabs")
    #expect(ElevenLabsDefaults.defaultVoiceURI() == "elevenlabs://en/Gsndh0O5AnuI2Hj3YUlA")
}
