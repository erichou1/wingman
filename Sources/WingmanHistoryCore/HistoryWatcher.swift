import Foundation
import IMsgCore

public struct HistoryWatchSummary: Sendable, Equatable {
  public let messagesWritten: Int
  public let lastImportedRowID: Int64
}

/// Live "auto read" pipeline for the Mac companion daemon.
///
/// Wraps `IMsgCore.MessageWatcher` (a kqueue file-watch + fallback poll over
/// `chat.db`/`-wal`/`-shm` that Wingman's exporter never used) so new
/// Messages are picked up as they arrive instead of requiring a manual
/// `wingman-history export` run. Every message is appended to a local NDJSON
/// log and the checkpoint is persisted after each one, so an abrupt process
/// exit (e.g. `launchd` stopping the daemon) never loses more than the
/// message currently in flight — this is intentionally a long-running loop:
/// callers that need to stop it should terminate the process rather than try
/// to cancel it cooperatively (see `Sources/WingmanHistoryCLI/main.swift`,
/// which measured that `Task.cancel()` does not interrupt an in-progress
/// `AsyncThrowingStream` iteration here).
public final class HistoryWatcher: @unchecked Sendable {
  private let databasePath: String
  private let logURL: URL
  private let watchStore: HistoryWatchStore
  private let configuration: MessageWatcherConfiguration

  public init(
    databasePath: String = HistoryExporter.defaultDatabasePath,
    logURL: URL,
    watchStore: HistoryWatchStore,
    configuration: MessageWatcherConfiguration = MessageWatcherConfiguration(includeReactions: true)
  ) {
    self.databasePath = NSString(string: databasePath).expandingTildeInPath
    self.logURL = logURL
    self.watchStore = watchStore
    self.configuration = configuration
  }

  /// Runs until the process is terminated. Never returns normally.
  public func run(progress: (@Sendable (HistoryWatchSummary) -> Void)? = nil) async throws {
    let store = try MessageStore(path: databasePath)

    let fileManager = FileManager.default
    let parentURL = logURL.deletingLastPathComponent()
    try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
    if !fileManager.fileExists(atPath: logURL.path) {
      fileManager.createFile(atPath: logURL.path, contents: nil)
    }
    let fileHandle = try FileHandle(forWritingTo: logURL)
    defer { try? fileHandle.close() }
    fileHandle.seekToEndOfFile()

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

    let startRowID: Int64
    if let checkpoint = watchStore.load() {
      startRowID = checkpoint.lastImportedRowID
    } else {
      startRowID = try store.maxRowID()
    }
    var cursor = startRowID
    var written = 0

    let watcher = MessageWatcher(store: store)
    for try await message in watcher.stream(sinceRowID: startRowID, configuration: configuration) {
      let attachments = try store.attachments(for: [message.rowID])[message.rowID] ?? []
      let record = MessageRecord(message: message, attachments: attachments)
      var data = try encoder.encode(record)
      data.append(0x0A)
      try fileHandle.write(contentsOf: data)

      cursor = max(cursor, message.rowID)
      written += 1
      try watchStore.save(HistoryWatchState(lastImportedRowID: cursor))
      progress?(HistoryWatchSummary(messagesWritten: written, lastImportedRowID: cursor))
    }
  }
}
