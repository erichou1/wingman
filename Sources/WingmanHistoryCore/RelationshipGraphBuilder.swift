import Foundation

/// The on-device relationship graph (P1 milestone): deterministic, purely
/// frequency-based facts derived from the Mac watch log
/// (`HistoryWatcher`/`MessageRecord`), never a fabricated "AI insight." The
/// iPhone app has no way to reach this file automatically yet (see
/// docs/MESSAGE_HISTORY_ARCHITECTURE.md) — the user brings the output JSON
/// over themselves and imports it in the Memories screen.
public struct RelationshipGraph: Codable, Equatable, Sendable {
  public struct ContactSummary: Codable, Equatable, Sendable {
    public var identifier: String
    public var messageCount: Int
    public var lastMessageAt: Date
    public var topSentPhrases: [String]
  }

  public struct WritingStyleSignal: Codable, Equatable, Sendable {
    public var averageMessageLength: Double
    public var commonOpeners: [String]
    public var commonSignOffs: [String]
    public var emojiUsageRate: Double
  }

  public var generatedAt: Date
  public var sourceLogPath: String
  public var contacts: [ContactSummary]
  public var writingStyle: WritingStyleSignal

  public init(
    generatedAt: Date,
    sourceLogPath: String,
    contacts: [ContactSummary],
    writingStyle: WritingStyleSignal
  ) {
    self.generatedAt = generatedAt
    self.sourceLogPath = sourceLogPath
    self.contacts = contacts
    self.writingStyle = writingStyle
  }
}

public enum RelationshipGraphError: LocalizedError, Equatable {
  case logNotFound(String)
  case noMessagesFound(String)

  public var errorDescription: String? {
    switch self {
    case .logNotFound(let path):
      return "No watch log found at \(path). Run `wingman-history watch` first."
    case .noMessagesFound(let path):
      return "\(path) contains no readable message records."
    }
  }
}

public enum RelationshipGraphBuilder {
  public static func build(logURL: URL, generatedAt: Date = Date()) throws -> RelationshipGraph {
    guard FileManager.default.fileExists(atPath: logURL.path) else {
      throw RelationshipGraphError.logNotFound(logURL.path)
    }
    let data = try Data(contentsOf: logURL)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    var byContact: [String: ContactAccumulator] = [:]
    var sentTexts: [String] = []

    for line in data.split(separator: 0x0A) {
      guard !line.isEmpty, let record = try? decoder.decode(MessageRecord.self, from: Data(line)),
        record.kind == "message"
      else { continue }

      let text = record.text.trimmingCharacters(in: .whitespacesAndNewlines)

      if !record.isFromMe {
        var accumulator = byContact[record.sender] ?? ContactAccumulator()
        accumulator.messageCount += 1
        if record.sentAt > accumulator.lastMessageAt { accumulator.lastMessageAt = record.sentAt }
        byContact[record.sender] = accumulator
      } else if !text.isEmpty {
        sentTexts.append(text)
      }
    }

    guard !byContact.isEmpty || !sentTexts.isEmpty else {
      throw RelationshipGraphError.noMessagesFound(logURL.path)
    }

    // Naive phrase frequency: exact-match repeats of short sent messages,
    // grouped per contact isn't available from an inbound-only accumulator,
    // so top phrases are computed globally and attached to every contact
    // summary as "how the user tends to reply" context.
    let topPhrases = topFrequent(sentTexts.filter { $0.count <= 60 }, minimumCount: 2, limit: 5)

    let contacts = byContact.map { identifier, accumulator in
      RelationshipGraph.ContactSummary(
        identifier: identifier,
        messageCount: accumulator.messageCount,
        lastMessageAt: accumulator.lastMessageAt,
        topSentPhrases: topPhrases
      )
    }.sorted { $0.messageCount > $1.messageCount }

    let writingStyle = RelationshipGraph.WritingStyleSignal(
      averageMessageLength: averageLength(sentTexts),
      commonOpeners: topFrequent(sentTexts.compactMap { firstWords($0, count: 2) }, minimumCount: 2, limit: 5),
      commonSignOffs: topFrequent(sentTexts.compactMap { lastWords($0, count: 2) }, minimumCount: 2, limit: 5),
      emojiUsageRate: emojiRate(sentTexts)
    )

    return RelationshipGraph(
      generatedAt: generatedAt,
      sourceLogPath: logURL.path,
      contacts: contacts,
      writingStyle: writingStyle
    )
  }

  private struct ContactAccumulator {
    var messageCount = 0
    var lastMessageAt = Date.distantPast
  }

  private static func topFrequent(_ values: [String], minimumCount: Int, limit: Int) -> [String] {
    var counts: [String: Int] = [:]
    for value in values { counts[value, default: 0] += 1 }
    return
      counts
      .filter { $0.value >= minimumCount }
      .sorted { $0.value > $1.value }
      .prefix(limit)
      .map(\.key)
  }

  private static func firstWords(_ text: String, count: Int) -> String? {
    let words = text.split(separator: " ").prefix(count)
    guard words.count == count else { return nil }
    return words.joined(separator: " ").lowercased()
  }

  private static func lastWords(_ text: String, count: Int) -> String? {
    let words = text.split(separator: " ").suffix(count)
    guard words.count == count else { return nil }
    return words.joined(separator: " ").lowercased()
  }

  private static func averageLength(_ texts: [String]) -> Double {
    guard !texts.isEmpty else { return 0 }
    let total = texts.reduce(0) { $0 + $1.count }
    return Double(total) / Double(texts.count)
  }

  private static func emojiRate(_ texts: [String]) -> Double {
    guard !texts.isEmpty else { return 0 }
    let withEmoji = texts.filter { text in
      text.unicodeScalars.contains { $0.properties.isEmojiPresentation }
    }
    return Double(withEmoji.count) / Double(texts.count)
  }
}
