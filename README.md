# SwiftEchada

**Screenplay Character Manager & Casting Library for Swift**

SwiftEchada is a Swift-based character management and casting system for screenplays that integrates with [SwiftGuion](https://github.com/stovak/SwiftGuion) for script parsing. The system manages both fictional character data and real-world casting information, with planned support for AI-generated content.

## Current Status

**Phase 0: Foundation & Setup** ✅ Complete

Version: 0.1.0

### Phase 0 Deliverables

- ✅ Project repository structure
- ✅ SwiftData environment setup
- ✅ SwiftGuion integration proof-of-concept
- ✅ Development environment configuration
- ✅ Testing framework setup (Swift Testing)
- ✅ Basic project documentation

## Requirements

- **macOS**: 26.0 or later (Sequoia)
- **Swift**: 6.2 or later
- **Xcode**: Latest version supporting Swift 6.2

## Installation

### Swift Package Manager

Add SwiftEchada to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/stovak/SwiftEchada.git", branch: "main")
]
```

Then add it to your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["SwiftEchada"]
    )
]
```

## Quick Start

### 1. Import SwiftEchada

```swift
import SwiftEchada
import SwiftData
```

### 2. Set up SwiftData Configuration

```swift
// Create an in-memory configuration for testing
let config = try SwiftEchadaConfiguration(inMemory: true)

// Or use persistent storage (default)
let config = try SwiftEchadaConfiguration(inMemory: false)

// Get the model context
let context = ModelContext(config.modelContainer)
```

### 3. Parse a Screenplay

```swift
// Create the parser service
let parser = ScreenplayParserService()

// Parse a Fountain format screenplay
let url = URL(fileURLWithPath: "path/to/screenplay.fountain")
let characters = try await parser.parseScreenplay(from: url)

// Characters are automatically extracted with:
// - Character names
// - Dialogue counts
// - Scene counts
// - Automatic type classification (Lead, Supporting, Featured, etc.)
```

### 4. Persist Characters to SwiftData

```swift
// Insert characters into SwiftData
for character in characters {
    context.insert(character)
}

// Save the context
try context.save()
```

### 5. Query Characters

```swift
// Fetch all characters
let allCharacters = try context.fetch(FetchDescriptor<Character>())

// Query by name
let descriptor = FetchDescriptor<Character>(
    predicate: #Predicate { $0.name == "SARAH" }
)
let results = try context.fetch(descriptor)
```

## Core Features (Phase 0)

### Character Model

The `Character` model represents a character from a screenplay with the following properties:

- **Identity**: `id`, `name`, `aliases`
- **Metadata**: `createdAt`, `updatedAt`
- **Description**: `age`, `gender`, `physicalDescription`
- **Script Data**: `firstAppearance`, `lastAppearance`, `totalScenes`, `dialogueCount`
- **Classification**: `characterType` (Lead, Supporting, Featured, Background, Extra)

### SwiftGuion Integration

- Automatically parse Fountain format screenplays
- Extract character names and dialogue
- Count scenes per character
- Classify character importance

### SwiftData Persistence

- Full SwiftData integration
- In-memory and persistent storage options
- Efficient querying and filtering
- Relationship support (ready for Phase 1+)

## Development Setup

### Clone the Repository

```bash
git clone https://github.com/stovak/SwiftEchada.git
cd SwiftEchada
```

### Build the Project

```bash
swift build
```

### Run Tests

```bash
swift test
```

All 13 Phase 0 tests should pass:

- ✅ Version information tests
- ✅ SwiftData configuration tests
- ✅ Character model tests
- ✅ Character persistence tests
- ✅ SwiftGuion parser integration tests
- ✅ Character extraction tests
- ✅ Full workflow integration test

## Architecture

```
SwiftEchada/
├── Sources/
│   └── SwiftEchada/
│       ├── SwiftEchada.swift              # Main library entry point
│       └── SwiftEchadaFoundation.swift    # Core models and services
├── Tests/
│   └── SwiftEchadaTests/
│       ├── SwiftEchadaTests.swift         # Test suite
│       └── Resources/
│           └── sample.fountain            # Sample screenplay for testing
├── Package.swift                          # Package manifest
├── README.md                              # This file
├── REQUIREMENTS.md                        # Detailed requirements
└── METHODOLOGY.md                         # Development methodology
```

## Example Usage

```swift
import SwiftEchada
import SwiftData

// Initialize
let config = try SwiftEchadaConfiguration(inMemory: true)
let context = ModelContext(config.modelContainer)

// Parse screenplay
let parser = ScreenplayParserService()
let scriptURL = URL(fileURLWithPath: "MyScript.fountain")
let characters = try await parser.parseScreenplay(from: scriptURL)

// Display results
for character in characters {
    print("\(character.name)")
    print("  Type: \(character.characterType)")
    print("  Scenes: \(character.totalScenes)")
    print("  Dialogue: \(character.dialogueCount) lines")
}

// Save to database
for character in characters {
    context.insert(character)
}
try context.save()

// Query leads
let leadDescriptor = FetchDescriptor<Character>(
    predicate: #Predicate { $0.characterType == .lead }
)
let leads = try context.fetch(leadDescriptor)
print("\nLead characters: \(leads.map { $0.name }.joined(separator: ", "))")
```

## Phase 0 Gate Criteria ✅

All Phase 0 gate criteria have been met:

- ✅ Project builds successfully
- ✅ SwiftGuion successfully parses test script
- ✅ SwiftData persistent store initializes
- ✅ 13 passing unit tests
- ✅ README with setup instructions complete
- ✅ Development environment documented

## Roadmap

SwiftEchada follows a phased development approach:

- **Phase 0**: Foundation & Setup ✅ **COMPLETE**
- **Phase 1**: Core Data Models (Character, Actor, relationships)
- **Phase 2**: SwiftGuion Integration (advanced parsing, synchronization)
- **Phase 3**: Casting Relationship & Workflow
- **Phase 4**: Media & File Management
- **Phase 5**: AI Integration - Foundation
- **Phase 6**: AI Integration - Advanced Features
- **Phase 7**: Basic User Interface (SwiftUI)
- **Phase 8**: Advanced UI & Polish
- **Phase 9**: Testing, Documentation & Hardening
- **Phase 10**: Release & Iteration

See [METHODOLOGY.md](METHODOLOGY.md) for detailed phase information.

## Documentation

- [REQUIREMENTS.md](REQUIREMENTS.md) - Complete feature requirements
- [METHODOLOGY.md](METHODOLOGY.md) - Development methodology and phases

## Dependencies

- [SwiftGuion](https://github.com/stovak/SwiftGuion) - Screenplay parsing library
- SwiftData - Apple's data persistence framework
- Swift Testing - Modern testing framework

## Contributing

This project is currently in active development. Phase 0 is complete and Phase 1 is next.

## License

[License information to be added]

## Contact

[Contact information to be added]

---

**Note**: SwiftEchada requires macOS 26+ and Swift 6.2+ as specified in Phase 0 requirements.

*Generated for Phase 0: Foundation & Setup*
*Last Updated: 2025-10-10*
