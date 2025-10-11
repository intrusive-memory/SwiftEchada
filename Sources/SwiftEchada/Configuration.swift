import Foundation
import SwiftData

// MARK: - SwiftData Configuration

/// Configuration for SwiftData persistent storage (Phase 1)
public struct SwiftEchadaConfiguration {
    /// The model container for SwiftData
    public let modelContainer: ModelContainer

    /// Create a new configuration with default settings
    /// - Parameter inMemory: If true, uses in-memory storage (useful for testing)
    /// - Throws: Error if container cannot be created
    public init(inMemory: Bool = false) throws {
        let schema = Schema([
            Character.self,
            Actor.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )

        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }

    /// Create repositories for the given context
    /// - Parameter context: The ModelContext to use
    /// - Returns: A tuple containing all repository instances
    public static func createRepositories(context: ModelContext) -> (
        characters: CharacterRepository,
        actors: ActorRepository,
        casting: CastingRepository
    ) {
        return (
            characters: CharacterRepository(context: context),
            actors: ActorRepository(context: context),
            casting: CastingRepository(context: context)
        )
    }
}
