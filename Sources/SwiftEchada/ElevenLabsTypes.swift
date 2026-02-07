import SwiftOnce

/// Typealiases to avoid name collisions between SwiftHablare and SwiftOnce modules.
/// Both modules define a `Voice` type, and both have a top-level type with the same
/// name as the module, making fully-qualified names impossible.
public typealias ElevenLabsClient = SwiftOnce
public typealias ElevenLabsHTTPClient = HTTPClient
typealias ElevenLabsVoice = Voice
