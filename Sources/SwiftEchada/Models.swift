import Foundation
import SwiftData

// MARK: - Character Model (Expanded for Phase 1)

/// Represents a character from a screenplay with comprehensive attributes
@Model
public final class Character {
    // MARK: - Identity

    /// Unique identifier for the character
    @Attribute(.unique) public var id: UUID

    /// Character's name as it appears in the screenplay
    public var name: String

    /// Alternative names or nicknames
    public var aliases: [String]

    /// When the character was created/imported
    public var createdAt: Date

    /// When the character was last modified
    public var updatedAt: Date

    // MARK: - Character Description (Fictional)

    /// Character's age or age range (e.g., "30s", "45", "Teen")
    public var age: String?

    /// Character's gender identity
    public var gender: String?

    /// Physical description (height, build, distinguishing features)
    public var physicalDescription: String?

    /// Key personality traits and behaviors
    public var personalityTraits: String?

    /// Character background and history
    public var background: String?

    /// Relationships to other characters (text description for Phase 1)
    public var relationships: String?

    /// Brief description of character journey
    public var characterArc: String?

    // MARK: - Script Integration

    /// Scene/page number where character first appears
    public var firstAppearance: String?

    /// Scene/page number where character last appears
    public var lastAppearance: String?

    /// Total number of scenes featuring this character
    public var totalScenes: Int

    /// Count of dialogue lines
    public var dialogueCount: Int

    /// Notable quotes or dialogue samples
    public var notableDialogue: [String]

    /// Character type classification
    public var characterType: CharacterType

    // MARK: - Casting Information

    /// Current casting status
    public var castingStatus: CastingStatus

    /// Casting director notes about the role
    public var castingNotes: String?

    /// Age range for casting (may differ from character age)
    public var castingAgeRange: String?

    /// Special skills required
    public var requiredSkills: [String]

    /// Physical requirements for the role
    public var physicalRequirements: String?

    /// Union requirements (SAG-AFTRA, etc.)
    public var unionRequirements: String?

    /// Availability dates required
    public var availabilityDates: String?

    // MARK: - Relationships

    /// Actors who have auditioned for or been cast in this role
    @Relationship(deleteRule: .nullify, inverse: \Actor.characters)
    public var actors: [Actor]?

    // MARK: - Computed Properties

    /// Whether this character has been cast
    public var isCast: Bool {
        castingStatus == .cast
    }

    /// Whether this character is a speaking role
    public var isSpeakingRole: Bool {
        dialogueCount > 0
    }

    /// Importance score (0-100) based on scenes and dialogue
    public var importanceScore: Int {
        let sceneWeight = min(totalScenes * 2, 50)
        let dialogueWeight = min(dialogueCount, 50)
        return sceneWeight + dialogueWeight
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        aliases: [String] = [],
        age: String? = nil,
        gender: String? = nil,
        physicalDescription: String? = nil,
        personalityTraits: String? = nil,
        background: String? = nil,
        relationships: String? = nil,
        characterArc: String? = nil,
        firstAppearance: String? = nil,
        lastAppearance: String? = nil,
        totalScenes: Int = 0,
        dialogueCount: Int = 0,
        notableDialogue: [String] = [],
        characterType: CharacterType = .featured,
        castingStatus: CastingStatus = .notCast,
        castingNotes: String? = nil,
        castingAgeRange: String? = nil,
        requiredSkills: [String] = [],
        physicalRequirements: String? = nil,
        unionRequirements: String? = nil,
        availabilityDates: String? = nil,
        actors: [Actor]? = nil
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.createdAt = Date()
        self.updatedAt = Date()
        self.age = age
        self.gender = gender
        self.physicalDescription = physicalDescription
        self.personalityTraits = personalityTraits
        self.background = background
        self.relationships = relationships
        self.characterArc = characterArc
        self.firstAppearance = firstAppearance
        self.lastAppearance = lastAppearance
        self.totalScenes = totalScenes
        self.dialogueCount = dialogueCount
        self.notableDialogue = notableDialogue
        self.characterType = characterType
        self.castingStatus = castingStatus
        self.castingNotes = castingNotes
        self.castingAgeRange = castingAgeRange
        self.requiredSkills = requiredSkills
        self.physicalRequirements = physicalRequirements
        self.unionRequirements = unionRequirements
        self.availabilityDates = availabilityDates
        self.actors = actors
    }

    // MARK: - Validation

    /// Validate the character model
    /// - Throws: ValidationError if validation fails
    public func validate() throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyName
        }

        guard totalScenes >= 0 else {
            throw ValidationError.invalidSceneCount
        }

        guard dialogueCount >= 0 else {
            throw ValidationError.invalidDialogueCount
        }
    }

    /// Update the modified timestamp
    public func touch() {
        updatedAt = Date()
    }
}

// MARK: - Actor Model

/// Represents a real-world actor with professional information
@Model
public final class Actor {
    // MARK: - Identity

    /// Unique identifier
    @Attribute(.unique) public var id: UUID

    /// Legal name
    public var fullName: String

    /// Professional name (if different from legal name)
    public var stageName: String?

    /// When the record was created
    public var createdAt: Date

    /// When the record was last modified
    public var updatedAt: Date

    // MARK: - Basic Information

    /// Primary headshot/profile photo data (stored as binary in SwiftData)
    @Attribute(.externalStorage)
    public var photoData: Data?

    /// Thumbnail for primary photo (smaller, for performance)
    public var thumbnailData: Data?

    /// Additional portfolio images (stored as binary in SwiftData)
    @Attribute(.externalStorage)
    public var additionalPhotosData: [Data]

    /// Thumbnails for additional photos
    public var additionalThumbnailsData: [Data]

    /// Date of birth for age verification
    public var dateOfBirth: Date?

    /// Actor's gender identity
    public var gender: String?

    /// Self-identified ethnicity
    public var ethnicity: String?

    /// Height in inches
    public var heightInches: Int?

    /// Body type description
    public var build: String?

    // MARK: - Professional Information

    /// Union status (e.g., "SAG-AFTRA", "Non-union")
    public var unionStatus: String?

    /// Agent name
    public var agentName: String?

    /// Agency name
    public var agencyName: String?

    /// Agent contact information
    public var agentContact: String?

    /// Manager information
    public var managerInfo: String?

    /// Link to resume/CV
    public var resumeURL: String?

    /// Link to demo reel
    public var reelURL: String?

    /// IMDB profile link
    public var imdbLink: String?

    /// Professional social media
    public var socialMedia: [String: String]

    /// Personal or professional website
    public var websiteURL: String?

    // MARK: - Skills & Capabilities

    /// Special skills (dancing, singing, martial arts, stunts, etc.)
    public var specialSkills: [String]

    /// Languages spoken with proficiency level
    public var languages: [String: String]

    /// Accents/dialects actor can perform
    public var accents: [String]

    /// Acting training and education
    public var training: String?

    /// Experience level
    public var experienceLevel: ExperienceLevel

    /// Genre experience
    public var genreExperience: [String]

    // MARK: - Availability & Logistics

    /// Current availability dates
    public var availabilityStart: Date?
    public var availabilityEnd: Date?

    /// Current city/region
    public var location: String?

    /// Willing to relocate
    public var willingToRelocate: Bool

    /// Willing to travel
    public var willingToTravel: Bool

    /// Visa/work authorization notes
    public var workAuthorization: String?

    /// Typical day rate
    public var dayRate: Decimal?

    /// Other booked projects (conflicts)
    public var conflicts: String?

    // MARK: - Relationships

    /// Characters this actor has auditioned for or been cast in
    @Relationship(deleteRule: .nullify)
    public var characters: [Character]?

    // MARK: - Computed Properties

    /// Display name (stage name if available, otherwise full name)
    public var displayName: String {
        stageName ?? fullName
    }

    /// Current age (if date of birth is available)
    public var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        return ageComponents.year
    }

    /// Whether actor is currently available
    public var isAvailable: Bool {
        guard let start = availabilityStart, let end = availabilityEnd else {
            return false
        }
        let now = Date()
        return now >= start && now <= end
    }

    /// Height in feet and inches string
    public var heightFormatted: String? {
        guard let inches = heightInches else { return nil }
        let feet = inches / 12
        let remainingInches = inches % 12
        return "\(feet)'\(remainingInches)\""
    }

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        fullName: String,
        stageName: String? = nil,
        photoData: Data? = nil,
        thumbnailData: Data? = nil,
        additionalPhotosData: [Data] = [],
        additionalThumbnailsData: [Data] = [],
        dateOfBirth: Date? = nil,
        gender: String? = nil,
        ethnicity: String? = nil,
        heightInches: Int? = nil,
        build: String? = nil,
        unionStatus: String? = nil,
        agentName: String? = nil,
        agencyName: String? = nil,
        agentContact: String? = nil,
        managerInfo: String? = nil,
        resumeURL: String? = nil,
        reelURL: String? = nil,
        imdbLink: String? = nil,
        socialMedia: [String: String] = [:],
        websiteURL: String? = nil,
        specialSkills: [String] = [],
        languages: [String: String] = [:],
        accents: [String] = [],
        training: String? = nil,
        experienceLevel: ExperienceLevel = .intermediate,
        genreExperience: [String] = [],
        availabilityStart: Date? = nil,
        availabilityEnd: Date? = nil,
        location: String? = nil,
        willingToRelocate: Bool = false,
        willingToTravel: Bool = false,
        workAuthorization: String? = nil,
        dayRate: Decimal? = nil,
        conflicts: String? = nil,
        characters: [Character]? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.stageName = stageName
        self.createdAt = Date()
        self.updatedAt = Date()
        self.photoData = photoData
        self.thumbnailData = thumbnailData
        self.additionalPhotosData = additionalPhotosData
        self.additionalThumbnailsData = additionalThumbnailsData
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.ethnicity = ethnicity
        self.heightInches = heightInches
        self.build = build
        self.unionStatus = unionStatus
        self.agentName = agentName
        self.agencyName = agencyName
        self.agentContact = agentContact
        self.managerInfo = managerInfo
        self.resumeURL = resumeURL
        self.reelURL = reelURL
        self.imdbLink = imdbLink
        self.socialMedia = socialMedia
        self.websiteURL = websiteURL
        self.specialSkills = specialSkills
        self.languages = languages
        self.accents = accents
        self.training = training
        self.experienceLevel = experienceLevel
        self.genreExperience = genreExperience
        self.availabilityStart = availabilityStart
        self.availabilityEnd = availabilityEnd
        self.location = location
        self.willingToRelocate = willingToRelocate
        self.willingToTravel = willingToTravel
        self.workAuthorization = workAuthorization
        self.dayRate = dayRate
        self.conflicts = conflicts
        self.characters = characters
    }

    // MARK: - Validation

    /// Validate the actor model
    /// - Throws: ValidationError if validation fails
    public func validate() throws {
        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyName
        }

        if let height = heightInches, height < 24 || height > 96 {
            throw ValidationError.invalidHeight
        }

        if let start = availabilityStart, let end = availabilityEnd, start > end {
            throw ValidationError.invalidAvailability
        }
    }

    /// Update the modified timestamp
    public func touch() {
        updatedAt = Date()
    }
}

// MARK: - Enumerations

/// Character type classification
public enum CharacterType: String, Codable {
    case lead
    case supporting
    case featured
    case background
    case extra
}

/// Casting status workflow
public enum CastingStatus: String, Codable {
    case notCast = "Not Cast"
    case auditioned = "Auditioned"
    case callback = "Callback"
    case offered = "Offered"
    case cast = "Cast"
    case declined = "Declined"
}

/// Actor experience level
public enum ExperienceLevel: String, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case professional = "Professional"
    case star = "Star"
}

// MARK: - Validation Errors

/// Validation errors for models
public enum ValidationError: Error, LocalizedError {
    case emptyName
    case invalidSceneCount
    case invalidDialogueCount
    case invalidHeight
    case invalidAvailability

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Name cannot be empty"
        case .invalidSceneCount:
            return "Scene count must be non-negative"
        case .invalidDialogueCount:
            return "Dialogue count must be non-negative"
        case .invalidHeight:
            return "Height must be between 24 and 96 inches"
        case .invalidAvailability:
            return "Availability start date must be before end date"
        }
    }
}
