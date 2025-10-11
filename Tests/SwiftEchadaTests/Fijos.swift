import Foundation

/// Fijos - Fixture manager for consistent file handling across tests
/// Provides centralized access to test fixture files
public enum Fijos {
    /// Base directory for all fixtures
    private static var fixturesDirectory: URL {
        guard let resourceURL = Bundle.module.resourceURL else {
            fatalError("Failed to locate test bundle resources")
        }
        return resourceURL.appendingPathComponent("fixtures", isDirectory: true)
    }

    // MARK: - Fountain Script Fixtures

    /// Sample screenplay with multiple characters
    public static var sampleScreenplay: URL {
        fixture(named: "sample.fountain")
    }

    /// Sample screenplay (alternative name)
    public static var sampleScreenplayAlt: URL {
        fixture(named: "sample_screenplay.fountain")
    }

    /// Screenplay with a lead character (20+ dialogue, 10+ scenes)
    public static var leadCharacter: URL {
        fixture(named: "lead_character.fountain")
    }

    /// Screenplay with a supporting character (10+ dialogue OR 5+ scenes)
    public static var supportingCharacter: URL {
        fixture(named: "supporting_character.fountain")
    }

    /// Screenplay with a background character (appears but minimal dialogue)
    public static var backgroundCharacter: URL {
        fixture(named: "background_character.fountain")
    }

    /// Screenplay with an extra character (minimal presence)
    public static var extraCharacter: URL {
        fixture(named: "extra_character.fountain")
    }

    /// Screenplay for testing all character classifications
    public static var classificationTest: URL {
        fixture(named: "classification_test.fountain")
    }

    // MARK: - Generic Fixture Access

    /// Get a fixture file by name
    /// - Parameter name: The filename (including extension)
    /// - Returns: URL to the fixture file
    public static func fixture(named name: String) -> URL {
        let url = fixturesDirectory.appendingPathComponent(name)

        // Verify the file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            fatalError("Fixture file not found: \(name) at path: \(url.path)")
        }

        return url
    }

    /// Check if a fixture exists
    /// - Parameter name: The filename (including extension)
    /// - Returns: True if the fixture exists
    public static func fixtureExists(named name: String) -> Bool {
        let url = fixturesDirectory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// List all available fixtures
    /// - Returns: Array of fixture filenames
    public static func listFixtures() -> [String] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: fixturesDirectory,
                includingPropertiesForKeys: nil
            )
            return contents
                .filter { !$0.hasDirectoryPath }
                .map { $0.lastPathComponent }
                .sorted()
        } catch {
            print("Warning: Failed to list fixtures: \(error)")
            return []
        }
    }
}
