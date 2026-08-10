import Foundation

/// The contract between the ChatGPT export crawler and the app.
///
/// The crawl itself is specified in `docs/CHATGPT_CONTEXT_CRAWL.md` and is not
/// implemented for the MVP — `DemoAccounts` constructs these literally instead.
/// The shape is what matters: a real import decodes this same struct from a
/// derived file, so swapping a hardcoded packet for a crawled one is a data
/// change with no code downstream of it.
///
/// Everything here is *derived*. Raw conversation text never reaches this type,
/// which is what keeps transcript content out of the sync gateway and out of any
/// model prompt (see the privacy boundary in the doc).
public struct ChatGPTContextPacket: Codable, Equatable, Sendable, Identifiable {
  /// One packet per account, so the account it belongs to is its identity.
  public var id: String { accountEmail }

  /// A subject the person returns to, counted across conversations rather than
  /// mentions, so one long thread does not outweigh a sustained interest.
  public struct Topic: Codable, Equatable, Sendable {
    public var name: String
    public var conversationCount: Int
    public var lastDiscussedAt: Date

    public init(name: String, conversationCount: Int, lastDiscussedAt: Date) {
      self.name = name
      self.conversationCount = conversationCount
      self.lastDiscussedAt = lastDiscussedAt
    }
  }

  /// Frequency facts only. Deliberately not "personality" — nothing here is an
  /// inference about the person.
  public struct Cadence: Codable, Equatable, Sendable {
    public var conversationsPerWeek: Double
    public var averageUserTurnLength: Int
    public var mostActiveHour: Int

    public init(conversationsPerWeek: Double, averageUserTurnLength: Int, mostActiveHour: Int) {
      self.conversationsPerWeek = conversationsPerWeek
      self.averageUserTurnLength = averageUserTurnLength
      self.mostActiveHour = mostActiveHour
    }
  }

  /// Binds a packet to one account. A real import rejects an export whose
  /// `user.json` email does not match the signed-in account.
  public var accountEmail: String
  public var exportGeneratedAt: Date
  public var conversationCount: Int
  public var userTurnCount: Int
  public var earliestConversationAt: Date

  /// Verbatim custom instructions from the export's `user_editable_context`
  /// node. Self-authored, so this is testimony rather than inference — the
  /// highest-signal thing in the whole export.
  public var customInstructions: [String]

  public var topics: [Topic]
  public var recurringEntities: [String]
  public var cadence: Cadence

  /// Stage-3 model output. Named `proposed` because these land unapproved and
  /// stay out of `HumanProfile.publicSnapshot` until the person ticks each one.
  public var proposedInterests: [String]
  public var proposedValues: [String]
  public var proposedBio: String

  public init(
    accountEmail: String,
    exportGeneratedAt: Date,
    conversationCount: Int,
    userTurnCount: Int,
    earliestConversationAt: Date,
    customInstructions: [String] = [],
    topics: [Topic] = [],
    recurringEntities: [String] = [],
    cadence: Cadence,
    proposedInterests: [String] = [],
    proposedValues: [String] = [],
    proposedBio: String = ""
  ) {
    self.accountEmail = accountEmail
    self.exportGeneratedAt = exportGeneratedAt
    self.conversationCount = conversationCount
    self.userTurnCount = userTurnCount
    self.earliestConversationAt = earliestConversationAt
    self.customInstructions = customInstructions
    self.topics = topics
    self.recurringEntities = recurringEntities
    self.cadence = cadence
    self.proposedInterests = proposedInterests
    self.proposedValues = proposedValues
    self.proposedBio = proposedBio
  }

  /// One-line provenance for the Memories and agent-settings screens.
  public var summaryLine: String {
    "\(conversationCount) ChatGPT conversations · \(userTurnCount) of your turns · \(topics.count) recurring topics"
  }
}

extension MemoryFact {
  /// Converts a packet into replaceable `.chatGPT` memory facts, mirroring
  /// `macGraphFacts(from:)`: deterministic statements the person can read and
  /// delete, never a synthesized narrative about them.
  public static func chatGPTFacts(from packet: ChatGPTContextPacket) -> [MemoryFact] {
    var facts: [MemoryFact] = []
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none

    for instruction in packet.customInstructions {
      facts.append(MemoryFact(text: "You told ChatGPT: \(instruction)", source: .chatGPT))
    }

    for topic in packet.topics.sorted(by: { $0.conversationCount > $1.conversationCount }).prefix(12)
    {
      facts.append(
        MemoryFact(
          text:
            "\(topic.name): \(topic.conversationCount) conversations, last on \(dateFormatter.string(from: topic.lastDiscussedAt)).",
          source: .chatGPT
        )
      )
    }

    if !packet.recurringEntities.isEmpty {
      facts.append(
        MemoryFact(
          text: "Names that keep coming up: \(packet.recurringEntities.joined(separator: ", ")).",
          source: .chatGPT
        )
      )
    }

    if packet.cadence.conversationsPerWeek > 0 {
      facts.append(
        MemoryFact(
          text:
            "About \(Int(packet.cadence.conversationsPerWeek.rounded())) ChatGPT conversations a week, most often around \(packet.cadence.mostActiveHour):00.",
          source: .chatGPT
        )
      )
    }

    if packet.cadence.averageUserTurnLength > 0 {
      facts.append(
        MemoryFact(
          text: "Average message to ChatGPT: \(packet.cadence.averageUserTurnLength) characters.",
          source: .chatGPT
        )
      )
    }

    return facts
  }
}
