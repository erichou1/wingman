import Foundation

public enum RelationshipKind: String, Codable, CaseIterable, Identifiable, Sendable {
  case dating
  case friendship
  case family
  case professional
  case community
  case newConnection

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .dating: "Dating"
    case .friendship: "Friendship"
    case .family: "Family"
    case .professional: "Professional"
    case .community: "Community"
    case .newConnection: "New connection"
    }
  }
}

public enum ProfileField: String, Codable, CaseIterable, Identifiable, Sendable {
  case displayName
  case bio
  case lookingFor
  case values
  case interests
  case lifestyle
  case communicationStyle
  case boundaries

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .displayName: "Name"
    case .bio: "About me"
    case .lookingFor: "Open to"
    case .values: "Values"
    case .interests: "Interests"
    case .lifestyle: "How I live"
    case .communicationStyle: "How I communicate"
    case .boundaries: "Boundaries"
    }
  }
}

public struct HumanProfile: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var displayName: String
  public var bio: String
  public var lookingFor: Set<RelationshipKind>
  public var values: [String]
  public var interests: [String]
  public var lifestyle: [String]
  public var communicationStyle: String
  public var boundaries: [String]
  public var approvedFields: Set<ProfileField>
  public var updatedAt: Date

  public init(
    id: UUID = UUID(),
    displayName: String = "",
    bio: String = "",
    lookingFor: Set<RelationshipKind> = [],
    values: [String] = [],
    interests: [String] = [],
    lifestyle: [String] = [],
    communicationStyle: String = "",
    boundaries: [String] = [],
    approvedFields: Set<ProfileField> = [],
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.displayName = displayName
    self.bio = bio
    self.lookingFor = lookingFor
    self.values = values
    self.interests = interests
    self.lifestyle = lifestyle
    self.communicationStyle = communicationStyle
    self.boundaries = boundaries
    self.approvedFields = approvedFields
    self.updatedAt = updatedAt
  }

  public var isReadyForIntroductions: Bool {
    approvedFields.contains(.displayName)
      && approvedFields.contains(.lookingFor)
      && (!approvedValues.isEmpty || !approvedInterests.isEmpty)
  }

  public var publicSnapshot: ApprovedProfile {
    ApprovedProfile(
      id: id,
      displayName: approvedFields.contains(.displayName)
        ? displayName.trimmed : "Someone on Wingman",
      bio: approvedFields.contains(.bio) ? bio.trimmed : nil,
      lookingFor: approvedFields.contains(.lookingFor) ? lookingFor : [],
      values: approvedValues,
      interests: approvedInterests,
      lifestyle: approvedFields.contains(.lifestyle) ? lifestyle.cleaned : [],
      communicationStyle: approvedFields.contains(.communicationStyle)
        ? communicationStyle.trimmed.nilIfEmpty : nil,
      boundaries: approvedFields.contains(.boundaries) ? boundaries.cleaned : []
    )
  }

  private var approvedValues: [String] {
    approvedFields.contains(.values) ? values.cleaned : []
  }

  private var approvedInterests: [String] {
    approvedFields.contains(.interests) ? interests.cleaned : []
  }
}

public struct ApprovedProfile: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let displayName: String
  public let bio: String?
  public let lookingFor: Set<RelationshipKind>
  public let values: [String]
  public let interests: [String]
  public let lifestyle: [String]
  public let communicationStyle: String?
  public let boundaries: [String]
}

public struct MatchInsight: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let firstProfileID: UUID
  public let secondProfileID: UUID
  public let relationshipKinds: [RelationshipKind]
  public let resonance: [String]
  public let friction: [String]
  public let conversationStarters: [String]

  public init(
    id: UUID = UUID(),
    firstProfileID: UUID,
    secondProfileID: UUID,
    relationshipKinds: [RelationshipKind],
    resonance: [String],
    friction: [String],
    conversationStarters: [String]
  ) {
    self.id = id
    self.firstProfileID = firstProfileID
    self.secondProfileID = secondProfileID
    self.relationshipKinds = relationshipKinds
    self.resonance = resonance
    self.friction = friction
    self.conversationStarters = conversationStarters
  }
}

public struct IntroductionConsent: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let matchID: UUID
  public var firstHumanApproved: Bool
  public var secondHumanApproved: Bool
  public var updatedAt: Date

  public init(
    id: UUID = UUID(),
    matchID: UUID,
    firstHumanApproved: Bool = false,
    secondHumanApproved: Bool = false,
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.matchID = matchID
    self.firstHumanApproved = firstHumanApproved
    self.secondHumanApproved = secondHumanApproved
    self.updatedAt = updatedAt
  }

  public var canIntroduce: Bool {
    firstHumanApproved && secondHumanApproved
  }
}

public struct IntroductionCard: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let matchID: UUID
  public let firstName: String
  public let secondName: String
  public let relationshipLabel: String
  public let resonance: String
  public let friction: String
  public let conversationStarter: String
  public let createdAt: Date

  public init(
    id: UUID = UUID(),
    matchID: UUID,
    firstName: String,
    secondName: String,
    relationshipLabel: String,
    resonance: String,
    friction: String,
    conversationStarter: String,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.matchID = matchID
    self.firstName = firstName
    self.secondName = secondName
    self.relationshipLabel = relationshipLabel
    self.resonance = resonance
    self.friction = friction
    self.conversationStarter = conversationStarter
    self.createdAt = createdAt
  }
}

public struct ReplyRequest: Codable, Equatable, Sendable {
  public var incomingMessage: String
  public var relationship: RelationshipKind
  public var context: String
  public var goal: String

  public init(
    incomingMessage: String,
    relationship: RelationshipKind,
    context: String = "",
    goal: String = ""
  ) {
    self.incomingMessage = incomingMessage
    self.relationship = relationship
    self.context = context
    self.goal = goal
  }
}

public struct ReplySuggestion: Codable, Equatable, Identifiable, Sendable {
  public enum Tone: String, Codable, CaseIterable, Sendable {
    case warm
    case direct
    case light

    public var title: String { rawValue.capitalized }
  }

  public let id: UUID
  public let tone: Tone
  public let text: String
  public let rationale: String

  public init(id: UUID = UUID(), tone: Tone, text: String, rationale: String) {
    self.id = id
    self.tone = tone
    self.text = text
    self.rationale = rationale
  }
}

public enum MemorySource: String, Codable, Sendable {
  case userEntered
  case macGraph
}

public struct MemoryFact: Codable, Equatable, Identifiable, Sendable {
  public var id: UUID
  public var text: String
  public var source: MemorySource
  public var createdAt: Date

  public init(id: UUID = UUID(), text: String, source: MemorySource, createdAt: Date = Date()) {
    self.id = id
    self.text = text
    self.source = source
    self.createdAt = createdAt
  }
}

public struct WritingStyleProfile: Codable, Equatable, Sendable {
  public var toneNotes: String
  public var grammarPreferences: String
  public var signaturePhrases: [String]
  public var thingsToAvoid: [String]

  public init(
    toneNotes: String = "",
    grammarPreferences: String = "",
    signaturePhrases: [String] = [],
    thingsToAvoid: [String] = []
  ) {
    self.toneNotes = toneNotes
    self.grammarPreferences = grammarPreferences
    self.signaturePhrases = signaturePhrases
    self.thingsToAvoid = thingsToAvoid
  }
}

public struct WingmanState: Codable, Equatable, Sendable {
  public static let schemaVersion = 2

  public var version: Int
  public var currentProfile: HumanProfile
  public var candidates: [HumanProfile]
  public var insights: [MatchInsight]
  public var consents: [IntroductionConsent]
  public var writingStyle: WritingStyleProfile
  public var memories: [MemoryFact]
  public var updatedAt: Date

  public init(
    version: Int = WingmanState.schemaVersion,
    currentProfile: HumanProfile = HumanProfile(),
    candidates: [HumanProfile] = [],
    insights: [MatchInsight] = [],
    consents: [IntroductionConsent] = [],
    writingStyle: WritingStyleProfile = WritingStyleProfile(),
    memories: [MemoryFact] = [],
    updatedAt: Date = Date()
  ) {
    self.version = version
    self.currentProfile = currentProfile
    self.candidates = candidates
    self.insights = insights
    self.consents = consents
    self.writingStyle = writingStyle
    self.memories = memories
    self.updatedAt = updatedAt
  }

  public static let empty = WingmanState()

  // Custom decoding so state saved before schema v2 (no writingStyle/memories
  // keys) still loads instead of tripping SharedStateStore's decode-failure
  // fallback to `.empty`, which would otherwise wipe an existing local profile.
  private enum CodingKeys: String, CodingKey {
    case version, currentProfile, candidates, insights, consents, writingStyle, memories, updatedAt
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    version = try container.decode(Int.self, forKey: .version)
    currentProfile = try container.decode(HumanProfile.self, forKey: .currentProfile)
    candidates = try container.decode([HumanProfile].self, forKey: .candidates)
    insights = try container.decode([MatchInsight].self, forKey: .insights)
    consents = try container.decode([IntroductionConsent].self, forKey: .consents)
    writingStyle =
      try container.decodeIfPresent(WritingStyleProfile.self, forKey: .writingStyle)
      ?? WritingStyleProfile()
    memories = try container.decodeIfPresent([MemoryFact].self, forKey: .memories) ?? []
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
  }
}

extension String {
  fileprivate var trimmed: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }

  fileprivate var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}

extension Array where Element == String {
  fileprivate var cleaned: [String] {
    map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }
}
