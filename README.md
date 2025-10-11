# SwiftEchada

[![Build](https://github.com/stovak/SwiftEchada/actions/workflows/tests.yml/badge.svg)](https://github.com/stovak/SwiftEchada/actions/workflows/tests.yml)
[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey.svg)](https://www.apple.com/macos)

**Screenplay Character Manager & Casting Library for Swift**

SwiftEchada is a Swift-based character management and casting system for screenplays that integrates with [SwiftGuion](https://github.com/stovak/SwiftGuion) for script parsing. The system manages both fictional character data and real-world casting information, with planned support for AI-generated content.

## Current Status

**Phases 0-4 Complete** ✅ | Version: 0.2.0 | **152 Tests Passing** | **97.20% Coverage**

- ✅ **Phase 0**: Foundation & Setup
- ✅ **Phase 1**: Core Data Models (Character, Actor, Casting)
- ✅ **Phase 2**: SwiftGuion Integration (Screenplay parsing)
- ✅ **Phase 3**: Casting Relationship & Workflow
- ✅ **Phase 4**: Test Coverage & Quality Assurance (97.20%)
- 🔄 **Phase 5**: UI & SwiftUI Integration (Next)

See [METHODOLOGY.md](METHODOLOGY.md) for detailed phase information.

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

All 152 tests should pass (Phases 0-4):

- ✅ **16** Phase 0 tests (Foundation)
- ✅ **74** Phase 1 tests (Core Models)
- ✅ **23** Phase 3 tests (Casting Workflow)
- ✅ **46** Phase 4 tests (Coverage & QA)
- ✅ SwiftData persistence and queries
- ✅ SwiftGuion screenplay parsing
- ✅ Casting relationship management
- ✅ Binary data import/export operations
- ✅ Comprehensive edge case coverage
- ✅ Full end-to-end workflows

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

## Key Features (Phases 0-4)

### ✅ Complete
- **Character Management**: Full CRUD operations with SwiftData
- **Actor Management**: Professional profiles with skills, availability, and experience
- **Screenplay Parsing**: Automatic character extraction from Fountain scripts
- **Casting Workflow**: Status-based casting with auditions, callbacks, and final casting
- **Binary Data Storage**: Photos stored as `Data` with `@Attribute(.externalStorage)`
- **Binary Data Operations**: Complete import/export photo lifecycle tested
- **Relationship Management**: Many-to-many Character-Actor relationships
- **Repository Pattern**: Clean data access with 40+ query operations
- **152 Comprehensive Tests**: 97.20% code coverage, production-ready quality
- **Edge Case Handling**: Boundary conditions, nil values, validation thoroughly tested

## Roadmap

SwiftEchada follows a phased development approach:

- ✅ **Phase 0**: Foundation & Setup
- ✅ **Phase 1**: Core Data Models (Character, Actor, relationships)
- ✅ **Phase 2**: SwiftGuion Integration (screenplay parsing)
- ✅ **Phase 3**: Casting Relationship & Workflow
- ✅ **Phase 4**: Test Coverage & Quality Assurance (97.20%)
- 🔄 **Phase 5**: UI & SwiftUI Integration (Next)
- 📋 **Phase 6**: AI Integration - Foundation
- 📋 **Phase 7**: AI Integration - Advanced Features
- 📋 **Phase 8**: Advanced UI & Polish
- 📋 **Phase 9**: Extended Testing & Documentation
- 📋 **Phase 10**: Release & Iteration

See [METHODOLOGY.md](METHODOLOGY.md) for detailed phase information and [Docs/](Docs/) for phase completion reports.

## Documentation

- [REQUIREMENTS.md](REQUIREMENTS.md) - Complete feature requirements
- [METHODOLOGY.md](METHODOLOGY.md) - Development methodology and phases
- [Docs/PHASE0_COMPLETE.md](Docs/PHASE0_COMPLETE.md) - Phase 0 completion report
- [Docs/PHASE1_COMPLETE.md](Docs/PHASE1_COMPLETE.md) - Phase 1 completion report
- [Docs/PHASE2_COMPLETE.md](Docs/PHASE2_COMPLETE.md) - Phase 2 completion report
- [Docs/PHASE3_COMPLETE.md](Docs/PHASE3_COMPLETE.md) - Phase 3 completion report
- [Docs/PHASE4_COMPLETE.md](Docs/PHASE4_COMPLETE.md) - Phase 4 completion report (97.20% coverage)

## Dependencies

- [SwiftGuion](https://github.com/stovak/SwiftGuion) - Screenplay parsing library
- SwiftData - Apple's data persistence framework
- Swift Testing - Modern testing framework

## Contributing

This project is currently in active development. Phases 0-4 are complete with 97.20% code coverage. Phase 5 (UI & SwiftUI Integration) is next.

## License

[License information to be added]

## Contact

[Contact information to be added]

---

**Note**: SwiftEchada requires macOS 26+ and Swift 6.2+. Binary data (photos) is stored using SwiftData `@Attribute(.externalStorage)` for optimal performance. Production-ready with 97.20% test coverage.

*Updated for Phases 0-4 Complete*
*Last Updated: 2025-10-11*
*Version: 0.2.0*
*Test Coverage: 97.20% (152/152 tests passing)*
