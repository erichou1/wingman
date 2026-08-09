import Foundation
import IMsgCore
import WingmanHistoryCore

enum SelfTestFailure: LocalizedError {
  case failed(String)

  var errorDescription: String? {
    switch self {
    case .failed(let message): message
    }
  }
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else { throw SelfTestFailure.failed(message) }
}

func testMessageNormalization() throws {
  let sentAt = Date(timeIntervalSince1970: 1_700_000_000)
  let readAt = sentAt.addingTimeInterval(15)
  let message = Message(
    rowID: 42,
    chatID: 7,
    sender: "+15555550123",
    text: "Want to get coffee?",
    date: sentAt,
    isFromMe: false,
    service: "iMessage",
    handleID: 3,
    attachmentsCount: 1,
    guid: "message-guid",
    routing: Message.RoutingMetadata(
      replyToGUID: "parent-guid",
      threadOriginatorGUID: "thread-guid",
      destinationCallerID: "+15555550999"
    ),
    balloonBundleID: "com.apple.messages.URLBalloonProvider",
    isRead: true,
    dateRead: readAt
  )
  let attachment = AttachmentMeta(
    filename: "~/Library/Messages/Attachments/photo.heic",
    transferName: "photo.heic",
    uti: "public.heic",
    mimeType: "image/heic",
    totalBytes: 1_024,
    isSticker: false,
    originalPath: "/Users/example/Library/Messages/Attachments/photo.heic",
    missing: false
  )

  let record = MessageRecord(message: message, attachments: [attachment])
  try require(record.rowID == 42, "row ID was not preserved")
  try require(record.chatRowID == 7, "chat edge was not preserved")
  try require(record.text == "Want to get coffee?", "message text was not preserved")
  try require(record.replyToGUID == "parent-guid", "reply edge was not preserved")
  try require(record.threadOriginatorGUID == "thread-guid", "thread edge was not preserved")
  try require(record.attachments.count == 1, "attachment edge was not preserved")
  try require(record.attachments[0].mimeType == "image/heic", "attachment type was not preserved")
}

func testInvalidBatchSize() throws {
  do {
    _ = try HistoryExporter(databasePath: "/tmp/chat.db", batchSize: 0)
    throw SelfTestFailure.failed("zero batch size was accepted")
  } catch let error as HistoryExportError {
    try require(error == .invalidBatchSize(0), "wrong invalid-batch error")
  }
}

func testOverwriteProtection() throws {
  let outputURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("wingman-existing-\(UUID().uuidString).ndjson")
  FileManager.default.createFile(atPath: outputURL.path, contents: Data())
  defer { try? FileManager.default.removeItem(at: outputURL) }

  let exporter = try HistoryExporter(databasePath: "/does/not/matter/chat.db")
  do {
    _ = try exporter.export(to: outputURL)
    throw SelfTestFailure.failed("existing export was overwritten")
  } catch let error as HistoryExportError {
    try require(error == .outputAlreadyExists(outputURL.path), "wrong overwrite error")
  }
}

private func withTemporaryDirectory<T>(_ body: (URL) throws -> T) rethrows -> T {
  let directoryURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("wingman-watch-state-\(UUID().uuidString)")
  defer { try? FileManager.default.removeItem(at: directoryURL) }
  return try body(directoryURL)
}

func testWatchStoreStartsEmpty() throws {
  try withTemporaryDirectory { directoryURL in
    let store = try HistoryWatchStore(stateDirectory: directoryURL.path)
    try require(store.load() == nil, "a fresh state directory should have no checkpoint")
  }
}

func testWatchStoreRoundTrip() throws {
  try withTemporaryDirectory { directoryURL in
    let store = try HistoryWatchStore(stateDirectory: directoryURL.path)
    try store.save(HistoryWatchState(lastImportedRowID: 42))
    let loaded = try require(store.load(), "checkpoint should persist across an in-process reload")
    try require(loaded.lastImportedRowID == 42, "wrong row ID after round trip")
  }
}

func testWatchStoreSurvivesRestart() throws {
  try withTemporaryDirectory { directoryURL in
    do {
      let store = try HistoryWatchStore(stateDirectory: directoryURL.path)
      try store.save(HistoryWatchState(lastImportedRowID: 7))
    }
    // A new instance pointed at the same directory simulates the daemon
    // being killed and relaunched by launchd: it must resume from the
    // saved row ID rather than replaying from the start.
    let restarted = try HistoryWatchStore(stateDirectory: directoryURL.path)
    let loaded = try require(restarted.load(), "checkpoint should survive a fresh HistoryWatchStore instance")
    try require(loaded.lastImportedRowID == 7, "checkpoint row ID did not survive restart")
  }
}

func testWatchStoreOverwritesPreviousCheckpoint() throws {
  try withTemporaryDirectory { directoryURL in
    let store = try HistoryWatchStore(stateDirectory: directoryURL.path)
    try store.save(HistoryWatchState(lastImportedRowID: 1))
    try store.save(HistoryWatchState(lastImportedRowID: 2))
    let loaded = try require(store.load(), "checkpoint missing after second save")
    try require(loaded.lastImportedRowID == 2, "second save should replace the first checkpoint, not append")
  }
}

@discardableResult
private func require<T>(_ value: T?, _ message: String) throws -> T {
  guard let value else { throw SelfTestFailure.failed(message) }
  return value
}

private func syntheticMessageRecord(
  rowID: Int64, sender: String, text: String, isFromMe: Bool, sentAt: Date
) -> MessageRecord {
  let message = Message(
    rowID: rowID,
    chatID: 1,
    sender: sender,
    text: text,
    date: sentAt,
    isFromMe: isFromMe,
    service: "iMessage",
    handleID: 1,
    attachmentsCount: 0,
    guid: "guid-\(rowID)",
    routing: Message.RoutingMetadata(replyToGUID: nil, threadOriginatorGUID: nil, destinationCallerID: nil),
    balloonBundleID: nil,
    isRead: nil,
    dateRead: nil
  )
  return MessageRecord(message: message, attachments: [])
}

func testGraphBuilderMissingLog() throws {
  let missingURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("wingman-missing-\(UUID().uuidString).ndjson")
  do {
    _ = try RelationshipGraphBuilder.build(logURL: missingURL)
    throw SelfTestFailure.failed("building a graph from a missing log should throw")
  } catch let error as RelationshipGraphError {
    try require(error == .logNotFound(missingURL.path), "wrong missing-log error")
  }
}

func testGraphBuilderDerivesContactsAndStyle() throws {
  try withTemporaryDirectory { directoryURL in
    let logURL = directoryURL.appendingPathComponent("history-watch.ndjson")
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let base = Date(timeIntervalSince1970: 1_700_000_000)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    let records: [MessageRecord] = [
      syntheticMessageRecord(rowID: 1, sender: "+15551234567", text: "hey are we still on for dinner?", isFromMe: false, sentAt: base),
      syntheticMessageRecord(rowID: 2, sender: "+15551234567", text: "yes! sounds good 🎉 see you soon", isFromMe: true, sentAt: base.addingTimeInterval(60)),
      syntheticMessageRecord(rowID: 3, sender: "+15551234567", text: "perfect, see you then", isFromMe: false, sentAt: base.addingTimeInterval(3_600)),
      syntheticMessageRecord(rowID: 4, sender: "+15559876543", text: "yes! sounds good, works for me", isFromMe: true, sentAt: base.addingTimeInterval(7_200)),
    ]

    var ndjson = Data()
    for record in records {
      ndjson.append(try encoder.encode(record))
      ndjson.append(0x0A)
    }
    try ndjson.write(to: logURL)

    let graph = try RelationshipGraphBuilder.build(logURL: logURL, generatedAt: base)

    try require(graph.contacts.count == 1, "only the inbound sender should appear as a contact")
    let contact = try require(graph.contacts.first, "missing contact summary")
    try require(contact.identifier == "+15551234567", "wrong contact identifier")
    try require(contact.messageCount == 2, "wrong inbound message count")
    try require(
      contact.lastMessageAt == base.addingTimeInterval(3_600), "wrong last-message timestamp")

    try require(
      graph.writingStyle.commonOpeners.contains("yes! sounds"),
      "repeated opener across two sent messages should surface as a common opener")
    try require(graph.writingStyle.emojiUsageRate == 0.5, "wrong emoji usage rate")
  }
}

do {
  try testMessageNormalization()
  try testInvalidBatchSize()
  try testOverwriteProtection()
  try testWatchStoreStartsEmpty()
  try testWatchStoreRoundTrip()
  try testWatchStoreSurvivesRestart()
  try testWatchStoreOverwritesPreviousCheckpoint()
  try testGraphBuilderMissingLog()
  try testGraphBuilderDerivesContactsAndStyle()
  print("wingman-history self-test: 9 passed")
} catch {
  FileHandle.standardError.write(
    Data("wingman-history self-test failed: \(error.localizedDescription)\n".utf8))
  exit(1)
}
