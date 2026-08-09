import Foundation

/// Persisted checkpoint for the live watch pipeline (`HistoryWatcher`).
///
/// `HistoryExporter`'s one-shot `export` always starts its cursor at 0
/// (`HistoryExporter.swift`), which is fine for a single manual export but
/// wrong for a daemon that may be killed and relaunched by launchd — without
/// a persisted checkpoint it would either replay the entire Messages history
/// on every restart or lose track of where it left off.
public struct HistoryWatchState: Codable, Equatable, Sendable {
  public var lastImportedRowID: Int64
  public var updatedAt: Date

  public init(lastImportedRowID: Int64, updatedAt: Date = Date()) {
    self.lastImportedRowID = lastImportedRowID
    self.updatedAt = updatedAt
  }
}

public enum HistoryWatchStoreError: LocalizedError, Equatable {
  case invalidStateDirectory(String)

  public var errorDescription: String? {
    switch self {
    case .invalidStateDirectory(let path):
      return "Could not create or access the watch state directory at \(path)."
    }
  }
}

public final class HistoryWatchStore: @unchecked Sendable {
  public static var defaultStateDirectory: String {
    NSString(string: "~/Library/Application Support/Wingman").expandingTildeInPath
  }

  private let stateFileURL: URL
  private let fileManager = FileManager.default

  public init(stateDirectory: String = HistoryWatchStore.defaultStateDirectory) throws {
    let directoryURL = URL(fileURLWithPath: NSString(string: stateDirectory).expandingTildeInPath)
    do {
      try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    } catch {
      throw HistoryWatchStoreError.invalidStateDirectory(directoryURL.path)
    }
    self.stateFileURL = directoryURL.appendingPathComponent("history-watch-state.json")
  }

  public func load() -> HistoryWatchState? {
    guard let data = try? Data(contentsOf: stateFileURL) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(HistoryWatchState.self, from: data)
  }

  public func save(_ state: HistoryWatchState) throws {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(state)
    let temporaryURL = stateFileURL.appendingPathExtension("partial-\(UUID().uuidString)")
    try data.write(to: temporaryURL, options: .atomic)
    _ = try fileManager.replaceItemAt(stateFileURL, withItemAt: temporaryURL)
  }
}
