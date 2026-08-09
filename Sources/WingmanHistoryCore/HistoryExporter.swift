import Foundation
import IMsgCore

public struct HistoryExportSummary: Sendable, Equatable {
  public let chats: Int
  public let messages: Int
  public let attachments: Int

  public init(chats: Int, messages: Int, attachments: Int) {
    self.chats = chats
    self.messages = messages
    self.attachments = attachments
  }
}

public enum HistoryExportError: LocalizedError, Equatable {
  case invalidBatchSize(Int)
  case outputAlreadyExists(String)
  case cursorDidNotAdvance(Int64)

  public var errorDescription: String? {
    switch self {
    case .invalidBatchSize(let size):
      return "Batch size must be greater than zero; received \(size)."
    case .outputAlreadyExists(let path):
      return "Refusing to overwrite existing export at \(path)."
    case .cursorDidNotAdvance(let cursor):
      return
        "Message import stopped because the database cursor did not advance past row \(cursor)."
    }
  }
}

public final class HistoryExporter: Sendable {
  public static let defaultDatabasePath = MessageStore.defaultPath

  private let databasePath: String
  private let batchSize: Int

  public init(databasePath: String = MessageStore.defaultPath, batchSize: Int = 1_000) throws {
    guard batchSize > 0 else {
      throw HistoryExportError.invalidBatchSize(batchSize)
    }
    self.databasePath = NSString(string: databasePath).expandingTildeInPath
    self.batchSize = batchSize
  }

  public func checkAccess() throws {
    let store = try MessageStore(path: databasePath)
    _ = try store.listChats(limit: 1)
  }

  public func export(
    to outputURL: URL,
    progress: (@Sendable (HistoryExportSummary) -> Void)? = nil
  ) throws -> HistoryExportSummary {
    let fileManager = FileManager.default
    guard !fileManager.fileExists(atPath: outputURL.path) else {
      throw HistoryExportError.outputAlreadyExists(outputURL.path)
    }

    let parentURL = outputURL.deletingLastPathComponent()
    try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
    let temporaryURL = parentURL.appendingPathComponent(
      ".\(outputURL.lastPathComponent).partial-\(UUID().uuidString)")

    do {
      fileManager.createFile(atPath: temporaryURL.path, contents: nil)
      let fileHandle = try FileHandle(forWritingTo: temporaryURL)
      defer { try? fileHandle.close() }

      let store = try MessageStore(path: databasePath)
      let writer = NDJSONWriter(fileHandle: fileHandle)
      try writer.write(
        ManifestRecord(
          kind: "manifest",
          schemaVersion: 1,
          createdAt: Date(),
          source: "macOS Messages chat.db"
        )
      )

      let chats = try store.listChats(limit: Int.max)
      for chat in chats {
        try writer.write(
          ChatRecord(
            kind: "chat",
            rowID: chat.id,
            identifier: chat.identifier,
            name: chat.name,
            service: chat.service,
            participants: try store.participants(chatID: chat.id),
            lastMessageAt: chat.lastMessageAt
          )
        )
      }

      var cursor: Int64 = 0
      var messageCount = 0
      var attachmentCount = 0

      while true {
        let page = try store.messagesAfterPage(
          afterRowID: cursor,
          chatID: nil,
          limit: batchSize,
          includeReactions: true
        )
        let attachmentsByMessage = try store.attachments(
          for: page.messages.map(\.rowID)
        )

        for message in page.messages {
          let attachments = attachmentsByMessage[message.rowID, default: []]
          try writer.write(MessageRecord(message: message, attachments: attachments))
          messageCount += 1
          attachmentCount += attachments.count
        }

        let summary = HistoryExportSummary(
          chats: chats.count,
          messages: messageCount,
          attachments: attachmentCount
        )
        progress?(summary)

        guard page.hasMore else { break }
        guard page.nextRowID > cursor else {
          throw HistoryExportError.cursorDidNotAdvance(cursor)
        }
        cursor = page.nextRowID
      }

      try fileHandle.synchronize()
      try fileManager.moveItem(at: temporaryURL, to: outputURL)
      return HistoryExportSummary(
        chats: chats.count,
        messages: messageCount,
        attachments: attachmentCount
      )
    } catch {
      try? fileManager.removeItem(at: temporaryURL)
      throw error
    }
  }
}

private struct ManifestRecord: Encodable {
  let kind: String
  let schemaVersion: Int
  let createdAt: Date
  let source: String
}

private struct ChatRecord: Encodable {
  let kind: String
  let rowID: Int64
  let identifier: String
  let name: String
  let service: String
  let participants: [String]
  let lastMessageAt: Date
}

public struct MessageRecord: Codable, Equatable {
  public let kind: String
  public let rowID: Int64
  public let chatRowID: Int64
  public let guid: String
  public let sender: String
  public let text: String
  public let sentAt: Date
  public let isFromMe: Bool
  public let service: String
  public let replyToGUID: String?
  public let threadOriginatorGUID: String?
  public let destinationCallerID: String?
  public let balloonBundleID: String?
  public let isReaction: Bool
  public let reactedToGUID: String?
  public let isRead: Bool?
  public let readAt: Date?
  public let attachments: [AttachmentRecord]

  public init(message: Message, attachments: [AttachmentMeta]) {
    self.kind = "message"
    self.rowID = message.rowID
    self.chatRowID = message.chatID
    self.guid = message.guid
    self.sender = message.sender
    self.text = message.text
    self.sentAt = message.date
    self.isFromMe = message.isFromMe
    self.service = message.service
    self.replyToGUID = message.replyToGUID
    self.threadOriginatorGUID = message.threadOriginatorGUID
    self.destinationCallerID = message.destinationCallerID
    self.balloonBundleID = message.balloonBundleID
    self.isReaction = message.isReaction
    self.reactedToGUID = message.reactedToGUID
    self.isRead = message.isRead
    self.readAt = message.dateRead
    self.attachments = attachments.map(AttachmentRecord.init)
  }
}

public struct AttachmentRecord: Codable, Equatable {
  public let filename: String
  public let transferName: String
  public let uniformTypeIdentifier: String
  public let mimeType: String
  public let byteCount: Int64
  public let isSticker: Bool
  public let originalPath: String
  public let missing: Bool

  public init(_ attachment: AttachmentMeta) {
    self.filename = attachment.filename
    self.transferName = attachment.transferName
    self.uniformTypeIdentifier = attachment.uti
    self.mimeType = attachment.mimeType
    self.byteCount = attachment.totalBytes
    self.isSticker = attachment.isSticker
    self.originalPath = attachment.originalPath
    self.missing = attachment.missing
  }
}

private final class NDJSONWriter {
  private let fileHandle: FileHandle
  private let encoder: JSONEncoder

  init(fileHandle: FileHandle) {
    self.fileHandle = fileHandle
    self.encoder = JSONEncoder()
    self.encoder.dateEncodingStrategy = .iso8601
    self.encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  }

  func write<Value: Encodable>(_ value: Value) throws {
    var data = try encoder.encode(value)
    data.append(0x0A)
    try fileHandle.write(contentsOf: data)
  }
}
