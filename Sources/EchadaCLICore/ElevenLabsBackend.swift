import Foundation
import SwiftHablare
import SwiftHablareOnce
import SwiftOnce

/// Voice-slot counts from `GET /v1/user/subscription`.
struct VoiceSlots: Equatable, Sendable {
  var limit: Int
  var used: Int
  var free: Int { limit - used }
}

/// Everything `echada voices design` needs from ElevenLabs, behind one seam so
/// tests inject a fake and never touch the network (EL-4).
protocol ElevenLabsBackend: Sendable {
  /// The account's voice-slot usage.
  func slots() async throws -> VoiceSlots
  /// Remaining credits, when the account reports them.
  func remainingCredits() async -> Int?
  /// Estimated credits for one design call whose sample text has `characters` characters.
  func estimateDesignCost(characters: Int) -> Int
  /// A designer whose `save` names the ElevenLabs voice `voiceName`.
  func designer(voiceName: String, designModel: String) -> any VoiceDesigner
  /// Rebuilds a candidate from persisted data so `save` runs in a later process than `design`.
  func candidate(
    generatedVoiceId: String, previewWAV: Data, designModel: String, sampleText: String,
    description: String
  ) throws -> VoiceCandidate
}

/// The live backend: SwiftHablareOnce's `ElevenLabsPlugin` plus a SwiftOnce
/// client for the subscription's slot counts (the plugin keeps its client internal).
struct LiveElevenLabsBackend: ElevenLabsBackend {
  private let plugin: ElevenLabsPlugin
  private let keys: any APIKeyStoring

  init() async throws {
    let keys = ChainedAPIKeyStore.default
    self.keys = keys
    let context = PluginContext(keys: keys, registry: PluginRegistry.default)
    self.plugin = try await ElevenLabsPlugin(context: context)
  }

  func slots() async throws -> VoiceSlots {
    guard let key = keys.apiKey(for: ElevenLabsPlugin.id) else {
      throw HablareError.missingCredential(
        pluginId: ElevenLabsPlugin.id,
        environmentVariable: CredentialRequirement.elevenLabs.primaryEnvironmentVariable)
    }
    let subscription = try await SwiftOnce(apiKey: key).subscription()
    guard let limit = subscription.voiceLimit, let used = subscription.voiceSlotsUsed else {
      throw VoicesDesignError.slotsUnavailable
    }
    return VoiceSlots(limit: limit, used: used)
  }

  func remainingCredits() async -> Int? { await plugin.remainingCredits() }

  func estimateDesignCost(characters: Int) -> Int {
    ElevenLabsPlugin.estimateCost(characters: characters, model: ElevenLabsModels.defaultModelId)
  }

  func designer(voiceName: String, designModel: String) -> any VoiceDesigner {
    plugin.designer(voiceName: voiceName, designModel: designModel)
  }

  func candidate(
    generatedVoiceId: String, previewWAV: Data, designModel: String, sampleText: String,
    description: String
  ) throws -> VoiceCandidate {
    try ElevenLabsDesigner.candidate(
      generatedVoiceId: generatedVoiceId, previewWAV: previewWAV, designModel: designModel,
      sampleText: sampleText, description: description)
  }
}
