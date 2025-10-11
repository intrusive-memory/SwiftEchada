# Binary Data Storage Imperative - Conflicts & Migration Plan

**Document Date**: 2025-10-11
**Project**: SwiftEchada
**Related**: REQUIREMENTS.md Section 7.3, METHODOLOGY.md Phase 4

## Overview

This document identifies all conflicts between the current Phase 1-3 implementation and the binary data storage imperative introduced in REQUIREMENTS.md Section 7.3.

### The Imperative

> All binary data (images, audio, video, documents) MUST be stored directly within SwiftData objects using `Data` types. File-based storage is ONLY used during import/export operations.

**Key Requirements**:
- Store binary data as `Data` within SwiftData models
- Use `@Attribute(.externalStorage)` for large binary data
- No file system references or file paths in database
- File operations ONLY at import/export boundaries
- Self-contained, portable database

## Conflicts Identified

### ⚠️ Actor Model - Critical Conflicts

**File**: `Sources/SwiftEchada/Models.swift`
**Lines**: 103, 106

#### Current Implementation (VIOLATES IMPERATIVE)

```swift
@Model
public final class Actor {
    // ...

    /// Primary headshot/profile photo path
    public var photoPath: String?              // ❌ FILE PATH - VIOLATES IMPERATIVE

    /// Additional portfolio images paths
    public var additionalPhotos: [String]      // ❌ FILE PATHS - VIOLATES IMPERATIVE

    // ... external URLs are OK (not binary storage)
    public var resumeURL: String?              // ✅ External link - acceptable
    public var reelURL: String?                // ✅ External link - acceptable
    public var websiteURL: String?             // ✅ External link - acceptable
    public var imdbLink: String?               // ✅ External link - acceptable
}
```

#### Required Changes (Phase 4)

```swift
@Model
public final class Actor {
    // ...

    /// Primary headshot/profile photo data
    @Attribute(.externalStorage)
    public var photoData: Data?                // ✅ Binary data storage

    /// Thumbnail for primary photo (smaller, cached)
    public var thumbnailData: Data?            // ✅ Smaller binary data

    /// Additional portfolio images (binary data)
    @Attribute(.externalStorage)
    public var additionalPhotosData: [Data]    // ✅ Binary data array

    /// Thumbnails for additional photos
    public var additionalThumbnailsData: [Data] // ✅ Smaller versions

    // ... external URLs remain unchanged
    public var resumeURL: String?              // ✅ External link
    public var reelURL: String?                // ✅ External link
    public var websiteURL: String?             // ✅ External link
    public var imdbLink: String?               // ✅ External link
}
```

### Impact Analysis

#### What Breaks

1. **Actor Initialization**
   - Parameters `photoPath: String?` and `additionalPhotos: [String]` must be removed
   - New parameters added: `photoData: Data?`, `additionalPhotosData: [Data]`

2. **TestFixtures**
   - `TestFixtures.createProfessionalActor()` uses `photoPath: "headshot.jpg"`
   - Must be updated to use `photoData: nil` or test binary data

3. **All Tests Using Actor Photos**
   - Any test that sets or reads `photoPath` will fail
   - Currently: Only TestFixtures.swift line ~60+

4. **Repository Methods**
   - No repository methods currently use photo properties
   - Phase 4 will add import/export methods

#### What Doesn't Break

1. **Character Model** - No photo properties, unaffected
2. **Casting Relationships** - No photo handling
3. **SwiftGuion Parser** - No photo parsing
4. **All Phase 0-3 Tests** - No photo reading/writing in tests
5. **External URLs** - `resumeURL`, `reelURL`, etc. remain unchanged

### Migration Strategy

#### Phase 4 Implementation Plan

**Step 1: Update Actor Model**
- Remove `photoPath: String?`
- Remove `additionalPhotos: [String]`
- Add `photoData: Data?` with `@Attribute(.externalStorage)`
- Add `thumbnailData: Data?`
- Add `additionalPhotosData: [Data]` with `@Attribute(.externalStorage)`
- Add `additionalThumbnailsData: [Data]`

**Step 2: Update Actor Initializer**
- Remove `photoPath` parameter
- Remove `additionalPhotos` parameter
- Add `photoData: Data? = nil`
- Add `thumbnailData: Data? = nil`
- Add `additionalPhotosData: [Data] = []`
- Add `additionalThumbnailsData: [Data] = []`

**Step 3: Update TestFixtures**
- Change `photoPath: "headshot.jpg"` to `photoData: nil`
- Add test helper to create sample binary data if needed
- Keep tests simple (nil data is fine for Phase 3)

**Step 4: Add Repository Import/Export Methods**

```swift
extension ActorRepository {
    /// Import photo from file URL, compress, and store as Data
    func importPhoto(for actor: Actor, from url: URL) throws {
        let imageData = try Data(contentsOf: url)
        // Compress image
        let compressed = compressImage(imageData)
        actor.photoData = compressed
        actor.thumbnailData = generateThumbnail(compressed)
        actor.touch()
    }

    /// Export photo Data to file URL
    func exportPhoto(for actor: Actor, to url: URL) throws {
        guard let photoData = actor.photoData else {
            throw ExportError.noPhoto
        }
        try photoData.write(to: url)
    }

    // Similar methods for additionalPhotos
}
```

**Step 5: Add Image Processing Utilities**
- Compression function (JPEG at 80% quality)
- Thumbnail generation (max 200x200)
- Format detection and validation
- Size limit enforcement (e.g., warn if > 5MB)

**Step 6: Test Suite Updates**
- Add Phase4Tests.swift
- Test binary data storage/retrieval
- Test import from file → Data
- Test export from Data → file
- Test compression reduces size
- Test SwiftData persists binary data correctly

### Data Migration Script (When Needed)

If any production data exists with `photoPath` values:

```swift
func migratePhotoPathsToData(context: ModelContext) async throws {
    let actors = try context.fetch(FetchDescriptor<Actor>())

    for actor in actors {
        // If old photoPath exists and file is accessible
        if let photoPath = actor.photoPath,
           let url = URL(string: photoPath),
           FileManager.default.fileExists(atPath: url.path) {

            // Read file, compress, store as Data
            let imageData = try Data(contentsOf: url)
            let compressed = compressImage(imageData)
            actor.photoData = compressed
            actor.thumbnailData = generateThumbnail(compressed)

            // Clear old path (field will be removed later)
            actor.photoPath = nil
        }

        // Similar for additionalPhotos array
        actor.additionalPhotos = [] // Clear old paths

        actor.touch()
    }

    try context.save()
    print("Migrated \(actors.count) actors from file paths to binary data")
}
```

## Documentation Updates

### Updated Files

1. ✅ **REQUIREMENTS.md** - Added Section 7.3 with binary data imperative
2. ✅ **METHODOLOGY.md** - Updated Phase 4 to align with imperative
3. ✅ **METHODOLOGY.md** - Added conflict warning in Phase 1.2
4. ✅ **METHODOLOGY.md** - Updated Risk Management section

### Pending Documentation

Phase 4 completion will create:
- `Docs/PHASE4_COMPLETE.md` - Full phase report with migration details
- Update README.md with binary data storage approach
- API documentation for import/export repository methods

## Gate Criteria Alignment

### Phase 4 Gate Criteria (Updated)

Original criteria that violated imperative have been updated:

| Original (File-Based) | Updated (Binary Data) | Status |
|-----------------------|----------------------|--------|
| ❌ Orphaned files cleaned up properly | ✅ Binary data persists correctly with SwiftData | Updated |
| ❌ File operations tested (upload, delete, replace) | ✅ Import/export operations tested thoroughly | Updated |
| ⚠️ Storage usage is reasonable | ✅ Database size reasonable (compression effective) | Enhanced |

All other gate criteria remain valid and aligned.

## Testing Strategy

### Phase 3 Tests (Current)
- ✅ **Status**: All 106 tests passing
- ✅ **Photo Usage**: TestFixtures uses `photoPath: "headshot.jpg"` but never reads it
- ✅ **Impact**: Minimal - changing to `photoData: nil` won't break tests

### Phase 4 Tests (Planned)

**Binary Data Storage Tests** (10+ tests):
1. Store `Data` in Actor model
2. Retrieve `Data` from Actor model
3. `@Attribute(.externalStorage)` works correctly
4. SwiftData persists large binary data
5. Multiple photos (array of `Data`)
6. Nil photo data handled correctly
7. Memory usage acceptable with binary data

**Import/Export Tests** (10+ tests):
1. Import image file → compress → store as `Data`
2. Export `Data` → write to file
3. Compression reduces file size
4. Thumbnail generation works
5. Multiple format support (JPG, PNG, HEIC)
6. Invalid file handling
7. Size limit enforcement
8. Batch import operations

**Integration Tests** (5+ tests):
1. Full workflow: Import → Store → Retrieve → Export
2. Actor with multiple photos
3. Portfolio management
4. Database portability (export/import entire database)

**Target**: 25+ Phase 4 tests, bringing total to 131+ tests

## Risk Assessment

### Low Risk
- ✅ Character model unaffected (no photos)
- ✅ Casting relationships unaffected
- ✅ Parser integration unaffected
- ✅ Current tests easily updated

### Medium Risk
- ⚠️ SwiftData `@Attribute(.externalStorage)` behavior with arrays
  - **Mitigation**: Test thoroughly, may need individual model objects
- ⚠️ Memory usage with large photo portfolios
  - **Mitigation**: Lazy loading, compression, size limits

### Mitigated Risks
- ✅ Orphaned files - **ELIMINATED** (no file storage)
- ✅ File synchronization - **ELIMINATED** (all in database)
- ✅ Backup complexity - **SIMPLIFIED** (single database file)

## Success Criteria

Phase 4 is successful when:

1. ✅ Actor model uses `Data` for all binary storage
2. ✅ No file paths stored in database
3. ✅ Import reads files and stores as `Data`
4. ✅ Export writes `Data` to files
5. ✅ Images compressed before storage
6. ✅ Thumbnails generated and stored
7. ✅ SwiftData persists binary data correctly
8. ✅ No memory leaks with large data
9. ✅ All Phase 4 tests passing (25+)
10. ✅ Database remains portable and self-contained

## Timeline

**Phase 4 Duration**: 1-2 weeks

**Week 1**:
- Update Actor model (remove paths, add Data properties)
- Update TestFixtures
- Add image processing utilities
- Implement import/export methods
- Write initial tests

**Week 2**:
- Complete test suite (25+ tests)
- Performance testing and optimization
- Memory leak testing
- Documentation
- Gate criteria verification

## Approval & Sign-off

- ✅ **Requirements Documented**: REQUIREMENTS.md Section 7.3
- ✅ **Methodology Updated**: METHODOLOGY.md Phase 4 and Phase 1.2
- ✅ **Conflicts Identified**: This document
- ✅ **Migration Plan**: Documented above
- ✅ **Risk Assessment**: Complete
- 🔄 **Implementation**: Pending Phase 4 start
- 🔄 **Testing**: Pending Phase 4
- 🔄 **Final Approval**: Pending Phase 4 completion

---

**Document Status**: ✅ APPROVED FOR PHASE 4 IMPLEMENTATION

**Next Action**: Begin Phase 4 development following migration plan

*Document Version: 1.0*
*SwiftEchada Version: 0.2.0 (Phases 0-3 Complete)*
*Related Documents*:
- REQUIREMENTS.md Section 7.3 (Binary Data Imperative)
- METHODOLOGY.md Phase 4 (Updated for Binary Data)
- Sources/SwiftEchada/Models.swift (Actor model - lines 103, 106)
