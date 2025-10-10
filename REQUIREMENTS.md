# SwiftEchada - Screenplay Character Manager & Casting Library

## Project Overview
A Swift-based character management and casting system for screenplays that integrates with SwiftGuion for script parsing. The system manages both fictional character data and real-world casting information, with support for AI-generated content.

## Core Requirements

### 1. Character Model (SwiftData)

#### 1.1 Character Identity
- **Name**: Character's name as it appears in the screenplay
- **Aliases**: Alternative names, nicknames, or pseudonyms used in the script
- **Character ID**: Unique identifier for tracking across scripts
- **Script Reference**: Link to source script (SwiftGuion integration)
- **First Appearance**: Scene/page number where character first appears
- **Last Appearance**: Scene/page number where character last appears
- **Total Scenes**: Count of scenes featuring this character

#### 1.2 Character Description (Fictional)
- **Age**: Character's age or age range
- **Gender**: Character's gender identity
- **Physical Description**: Height, build, distinguishing features
- **Personality Traits**: Key character traits and behaviors
- **Background**: Character history and backstory
- **Relationships**: Connections to other characters in the script
- **Character Arc**: Brief description of character journey
- **Dialogue Lines**: Count or notable quotes
- **Character Type**: Lead, Supporting, Featured, Background, Extra

#### 1.3 AI-Generated Content
- **AI Physical Description**: AI-generated detailed physical attributes
- **AI Personality Profile**: AI-analyzed character psychology
- **AI Casting Suggestions**: AI-recommended actor types or specific actors
- **AI Visual Reference**: AI-generated character image/concept art
- **AI Voice Description**: Suggested voice characteristics
- **AI Generation Metadata**:
  - Model used (GPT-4, Claude, Midjourney, etc.)
  - Generation date
  - Prompt used
  - Version/iteration number
- **AI Analysis**:
  - Character complexity score
  - Emotional range requirements
  - Physical demands of role
  - Dialogue complexity

#### 1.4 Casting Information
- **Casting Status**: Not Cast, Auditioned, Offered, Cast, Declined
- **Actor ID**: Reference to cast actor
- **Audition Date**: When auditions occurred
- **Callback Status**: Whether actor received callbacks
- **Screen Test**: Links to screen test recordings/notes
- **Contract Status**: Pending, Signed, Declined
- **Casting Director Notes**: Professional notes about the role
- **Casting Requirements**:
  - Union requirements (SAG-AFTRA, etc.)
  - Age range for casting
  - Special skills required (singing, dancing, stunts, accents)
  - Physical requirements
  - Availability dates

### 2. Actor Model (SwiftData)

#### 2.1 Basic Information
- **Actor ID**: Unique identifier
- **Full Name**: Legal name
- **Stage Name**: Professional name (if different)
- **Photo**: Primary headshot/profile photo
- **Additional Photos**: Portfolio images, character stills
- **Date of Birth**: For age verification
- **Gender**: Actor's gender identity
- **Ethnicity**: Self-identified ethnicity
- **Height**: Physical measurements
- **Build**: Body type description

#### 2.2 Professional Information
- **Union Status**: SAG-AFTRA, non-union, etc.
- **Agent Information**:
  - Agent name
  - Agency
  - Contact information
- **Manager Information**: If applicable
- **Resume/CV**: Link or embedded document
- **Reel**: Link to demo reel
- **IMDB Link**: Professional profile
- **Social Media**: Professional accounts
- **Website**: Personal or professional website

#### 2.3 Skills & Capabilities
- **Special Skills**: Dancing, singing, martial arts, stunts, etc.
- **Languages**: Languages spoken and proficiency level
- **Accents/Dialects**: Accents actor can perform
- **Training**: Acting schools, workshops, certifications
- **Experience Level**: Beginner, Intermediate, Professional, Star
- **Genre Experience**: Comedy, Drama, Action, Horror, etc.

#### 2.4 Availability & Logistics
- **Current Availability**: Dates available
- **Location**: Current city/region
- **Willing to Relocate**: Boolean
- **Willing to Travel**: Boolean
- **Visa/Work Authorization**: For international productions
- **Rate**: Typical day rate or project rate
- **Conflicts**: Other booked projects

### 3. Character-Actor Relationship (Casting)

#### 3.1 Casting Link
- **Character ID**: Reference to character
- **Actor ID**: Reference to actor
- **Status**: Auditioned, Callback, Offered, Cast, Declined
- **Audition Date**: Date of audition
- **Audition Notes**: Director/casting notes
- **Audition Recording**: Link to video/audio
- **Chemistry Tests**: Notes on pairings with other actors
- **Fit Score**: Numerical or qualitative rating
- **Director Approval**: Boolean and notes
- **Producer Approval**: Boolean and notes

#### 3.2 Comparison & Analysis
- **AI Similarity Score**: How well actor matches AI generation
- **Physical Match**: Comparison of physical attributes
- **Type Match**: How well actor fits character type
- **Experience Match**: Whether actor has suitable experience
- **Availability Match**: Whether schedules align
- **Budget Match**: Whether actor fits budget constraints

### 4. SwiftGuion Integration

#### 4.1 Script Parsing
- **Character Extraction**: Automatically extract character names from script
- **Scene Tracking**: Track which scenes each character appears in
- **Dialogue Extraction**: Pull character dialogue for analysis
- **Stage Directions**: Extract physical descriptions from stage directions
- **Character Relationships**: Infer relationships from scene pairings
- **Speaking vs. Non-Speaking**: Categorize character types

#### 4.2 Synchronization
- **Script Updates**: Handle changes when script is revised
- **Character Merging**: Handle when characters are consolidated
- **Character Splitting**: Handle when characters are split
- **Name Changes**: Update character references across database
- **Scene Changes**: Update appearance tracking when scenes change

### 5. Data Management Features

#### 5.1 Search & Filter
- Search characters by name, type, status
- Filter actors by availability, skills, union status
- Search casting by status, dates
- Full-text search across notes and descriptions

#### 5.2 Import/Export
- Import actor data from CSV/JSON
- Export casting sheets
- Export to production management tools
- Import from industry databases (IMDB, Breakdown Services)

#### 5.3 Reporting
- Casting progress reports
- Character breakdown reports
- Budget analysis based on cast
- Union compliance reports
- Production reports (who's needed when)

#### 5.4 Versioning & History
- Track changes to character descriptions
- Track casting decisions over time
- Maintain audit trail for legal/production purposes
- Version control for AI-generated content

### 6. User Interface Requirements

#### 6.1 Character Management Views
- Character list/grid view
- Character detail view
- Character comparison view
- Character-script cross-reference view

#### 6.2 Actor Management Views
- Actor database/search interface
- Actor profile view
- Actor portfolio/gallery view
- Actor comparison view

#### 6.3 Casting Workflow Views
- Casting board (drag-and-drop interface)
- Audition scheduler
- Side-by-side character/actor comparison
- Casting status dashboard

#### 6.4 AI Integration Views
- AI generation interface
- AI suggestion review interface
- AI vs. actual comparison views

### 7. Technical Requirements

#### 7.1 SwiftData Schema
- Character entity with relationships
- Actor entity with relationships
- Casting relationship entity
- Support for complex queries and relationships
- Efficient image/file storage strategy
- Support for versioning and history

#### 7.2 AI Integration
- API integration layer for AI services
- Prompt management system
- Response parsing and storage
- Cost tracking for AI API usage
- Rate limiting and error handling

#### 7.3 Media Handling
- Photo upload and storage
- Image compression and optimization
- Support for multiple image formats
- Video link storage and validation
- Document attachment support

#### 7.4 Performance
- Efficient queries for large casts
- Image caching strategy
- Background syncing with SwiftGuion
- Responsive UI for large datasets

### 8. Future Enhancements (Phase 2)

- **Scheduling Integration**: Link to production calendar
- **Budget Integration**: Track casting costs
- **Contract Management**: Store and track contracts
- **Communication Tools**: Email/message actors and agents
- **Collaboration Features**: Multi-user support for casting teams
- **Analytics**: ML-based casting recommendations
- **Mobile App**: iOS app for on-set reference
- **Cloud Sync**: Sync across devices and teams

## Success Criteria

1. Seamlessly parse characters from SwiftGuion scripts
2. Comprehensive character and actor data models
3. Efficient casting workflow management
4. AI integration for character visualization and analysis
5. Professional-grade casting tools suitable for production use
6. Extensible architecture for future enhancements

## Dependencies

- **SwiftGuion**: For script parsing (https://github.com/stovak/SwiftGuion)
- **SwiftData**: For data persistence
- **SwiftUI**: For user interface
- **AI Services**: OpenAI, Anthropic Claude, or similar for AI features
- **Image Processing**: For photo optimization and storage

## Compliance & Legal

- Union agreement compliance (SAG-AFTRA guidelines)
- Privacy compliance for actor personal information
- Photo rights and usage agreements
- Data retention policies
- GDPR/CCPA compliance if applicable

---

*Document Version: 1.0*
*Last Updated: 2025-10-10*
*Project: SwiftEchada*
