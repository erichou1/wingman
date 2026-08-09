import Foundation

/// Mirrors the JSON shape written by `wingman-history build-graph`
/// (`RelationshipGraph` in the WingmanHistoryCore package). Duplicated here
/// rather than shared, because that package depends on IMsgCore, which
/// declares macOS-only platform support and cannot be linked into the iOS
/// app target. Keep field names/types in sync with
/// Sources/WingmanHistoryCore/RelationshipGraphBuilder.swift.
public struct ImportedRelationshipGraph: Decodable, Sendable {
  public struct ContactSummary: Decodable, Sendable {
    public var identifier: String
    public var messageCount: Int
    public var lastMessageAt: Date
    public var topSentPhrases: [String]
  }

  public struct WritingStyleSignal: Decodable, Sendable {
    public var averageMessageLength: Double
    public var commonOpeners: [String]
    public var commonSignOffs: [String]
    public var emojiUsageRate: Double
  }

  public var generatedAt: Date
  public var sourceLogPath: String
  public var contacts: [ContactSummary]
  public var writingStyle: WritingStyleSignal
}

extension MemoryFact {
  /// Converts an imported graph into replaceable `.macGraph` memory facts —
  /// deterministic, frequency-based summaries only, no fabricated insight.
  public static func macGraphFacts(from graph: ImportedRelationshipGraph) -> [MemoryFact] {
    var facts: [MemoryFact] = []
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none

    for contact in graph.contacts.sorted(by: { $0.messageCount > $1.messageCount }).prefix(20) {
      facts.append(
        MemoryFact(
          text: "\(contact.identifier): \(contact.messageCount) messages, last heard from \(dateFormatter.string(from: contact.lastMessageAt)).",
          source: .macGraph
        )
      )
    }

    if graph.writingStyle.averageMessageLength > 0 {
      facts.append(
        MemoryFact(
          text: "Average sent message length: \(Int(graph.writingStyle.averageMessageLength)) characters.",
          source: .macGraph
        )
      )
    }
    if !graph.writingStyle.commonOpeners.isEmpty {
      facts.append(
        MemoryFact(
          text: "Common openers: \(graph.writingStyle.commonOpeners.joined(separator: ", ")).",
          source: .macGraph
        )
      )
    }
    if !graph.writingStyle.commonSignOffs.isEmpty {
      facts.append(
        MemoryFact(
          text: "Common sign-offs: \(graph.writingStyle.commonSignOffs.joined(separator: ", ")).",
          source: .macGraph
        )
      )
    }
    if graph.writingStyle.emojiUsageRate > 0 {
      facts.append(
        MemoryFact(
          text: "Uses emoji in about \(Int(graph.writingStyle.emojiUsageRate * 100))% of sent messages.",
          source: .macGraph
        )
      )
    }

    return facts
  }
}
