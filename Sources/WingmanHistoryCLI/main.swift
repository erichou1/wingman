import Foundation
import WingmanHistoryCore

enum CLIError: LocalizedError {
  case invalidArguments(String)
  case sensitiveDataAcknowledgementRequired

  var errorDescription: String? {
    switch self {
    case .invalidArguments(let message):
      return message
    case .sensitiveDataAcknowledgementRequired:
      return
        "Export requires --acknowledge-sensitive-data because the output contains private messages and identifiers."
    }
  }
}

struct CLIArguments {
  enum Command {
    case accessCheck
    case export(outputPath: String, acknowledgedSensitiveData: Bool)
    case watch(acknowledgedSensitiveData: Bool)
    case buildGraph(outputPath: String)
  }

  let command: Command
  let databasePath: String
  let batchSize: Int
  let stateDirectory: String
  let logPath: String
  let graphOutputPath: String

  static func parse(_ arguments: [String]) throws -> CLIArguments {
    guard let commandName = arguments.first else {
      throw CLIError.invalidArguments(usage)
    }
    if commandName == "--help" || commandName == "-h" {
      throw CLIError.invalidArguments(usage)
    }

    var databasePath = HistoryExporter.defaultDatabasePath
    var batchSize = 1_000
    var outputPath: String?
    var acknowledgedSensitiveData = false
    var stateDirectory = HistoryWatchStore.defaultStateDirectory
    var logPath = defaultWatchLogPath
    var graphOutputPath = defaultGraphOutputPath
    var index = 1

    while index < arguments.count {
      switch arguments[index] {
      case "--database":
        index += 1
        guard index < arguments.count else {
          throw CLIError.invalidArguments("--database requires a path.\n\n\(usage)")
        }
        databasePath = arguments[index]
      case "--output":
        index += 1
        guard index < arguments.count else {
          throw CLIError.invalidArguments("--output requires a path.\n\n\(usage)")
        }
        outputPath = arguments[index]
      case "--batch-size":
        index += 1
        guard index < arguments.count, let parsed = Int(arguments[index]) else {
          throw CLIError.invalidArguments("--batch-size requires an integer.\n\n\(usage)")
        }
        batchSize = parsed
      case "--state-dir":
        index += 1
        guard index < arguments.count else {
          throw CLIError.invalidArguments("--state-dir requires a path.\n\n\(usage)")
        }
        stateDirectory = arguments[index]
      case "--log":
        index += 1
        guard index < arguments.count else {
          throw CLIError.invalidArguments("--log requires a path.\n\n\(usage)")
        }
        logPath = arguments[index]
      case "--graph-output":
        index += 1
        guard index < arguments.count else {
          throw CLIError.invalidArguments("--graph-output requires a path.\n\n\(usage)")
        }
        graphOutputPath = arguments[index]
      case "--acknowledge-sensitive-data":
        acknowledgedSensitiveData = true
      default:
        throw CLIError.invalidArguments("Unknown argument: \(arguments[index])\n\n\(usage)")
      }
      index += 1
    }

    let command: Command
    switch commandName {
    case "access-check":
      command = .accessCheck
    case "export":
      guard let outputPath else {
        throw CLIError.invalidArguments("export requires --output.\n\n\(usage)")
      }
      guard acknowledgedSensitiveData else {
        throw CLIError.sensitiveDataAcknowledgementRequired
      }
      command = .export(
        outputPath: outputPath,
        acknowledgedSensitiveData: acknowledgedSensitiveData
      )
    case "watch":
      guard acknowledgedSensitiveData else {
        throw CLIError.sensitiveDataAcknowledgementRequired
      }
      command = .watch(acknowledgedSensitiveData: acknowledgedSensitiveData)
    case "build-graph":
      command = .buildGraph(outputPath: graphOutputPath)
    default:
      throw CLIError.invalidArguments("Unknown command: \(commandName)\n\n\(usage)")
    }

    return CLIArguments(
      command: command,
      databasePath: databasePath,
      batchSize: batchSize,
      stateDirectory: stateDirectory,
      logPath: logPath,
      graphOutputPath: graphOutputPath
    )
  }

  static var defaultWatchLogPath: String {
    NSString(string: "~/Library/Application Support/Wingman/history-watch.ndjson").expandingTildeInPath
  }

  static var defaultGraphOutputPath: String {
    NSString(string: "~/Library/Application Support/Wingman/relationship-graph.json").expandingTildeInPath
  }

  static let usage = """
    Usage:
      wingman-history access-check [--database PATH]
      wingman-history export --output PATH --acknowledge-sensitive-data [--database PATH] [--batch-size N]
      wingman-history watch --acknowledge-sensitive-data [--database PATH] [--state-dir PATH] [--log PATH]
      wingman-history build-graph [--log PATH] [--graph-output PATH]

    watch runs until the process is stopped (Ctrl-C, or `launchctl stop`) and
    appends newly seen messages to --log, persisting a checkpoint under
    --state-dir so a restart resumes instead of re-reading history.

    build-graph reads that log and writes a deterministic, frequency-based
    RelationshipGraph JSON (contact summaries + writing-style signal) that
    you can bring onto your iPhone yourself and import in the Memories
    screen — there is no automatic Mac-to-iPhone sync yet.

    The exporter and watcher are read-only. They never send, edit, or delete
    Messages data.
    """
}

func stderr(_ message: String) {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
}

do {
  let arguments = try CLIArguments.parse(Array(CommandLine.arguments.dropFirst()))

  switch arguments.command {
  case .accessCheck:
    let exporter = try HistoryExporter(databasePath: arguments.databasePath, batchSize: arguments.batchSize)
    try exporter.checkAccess()
    print("Messages history access: available")
  case .export(let outputPath, _):
    let exporter = try HistoryExporter(databasePath: arguments.databasePath, batchSize: arguments.batchSize)
    let outputURL = URL(fileURLWithPath: NSString(string: outputPath).expandingTildeInPath)
    let summary = try exporter.export(to: outputURL) { summary in
      stderr(
        "Imported \(summary.messages) messages and \(summary.attachments) attachments across \(summary.chats) chats"
      )
    }
    print(
      "Export complete: chats=\(summary.chats) messages=\(summary.messages) attachments=\(summary.attachments)"
    )
  case .watch:
    runWatch(arguments: arguments)
  case .buildGraph(let outputPath):
    let logURL = URL(fileURLWithPath: arguments.logPath)
    let graph = try RelationshipGraphBuilder.build(logURL: logURL)
    let outputURL = URL(fileURLWithPath: NSString(string: outputPath).expandingTildeInPath)
    try FileManager.default.createDirectory(
      at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    try encoder.encode(graph).write(to: outputURL, options: .atomic)
    print(
      "Graph written to \(outputURL.path): \(graph.contacts.count) contacts, \(graph.writingStyle.commonOpeners.count) common openers found"
    )
  }
} catch {
  stderr("Error: \(error.localizedDescription)")
  exit(1)
}

/// `AsyncThrowingStream` iteration does not stop when the consuming `Task` is
/// cancelled (verified empirically: `Task.cancel()` on an in-progress `for
/// try await` over such a stream leaves it suspended indefinitely rather than
/// throwing `CancellationError`). Since `HistoryWatcher` persists its
/// checkpoint after every message, it's safe to just `exit()` straight from
/// the signal handler instead of trying to unwind the async loop cooperatively.
func runWatch(arguments: CLIArguments) -> Never {
  do {
    let watchStore = try HistoryWatchStore(stateDirectory: arguments.stateDirectory)
    let watcher = HistoryWatcher(
      databasePath: arguments.databasePath,
      logURL: URL(fileURLWithPath: arguments.logPath),
      watchStore: watchStore
    )

    stderr("Watching \(arguments.databasePath) — appending new messages to \(arguments.logPath)")

    var signalSources: [DispatchSourceSignal] = []
    func installShutdownHandler(_ signalNumber: Int32) {
      signal(signalNumber, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
      source.setEventHandler {
        stderr("Stopping watch (checkpoint already saved through the last processed message).")
        exit(0)
      }
      source.resume()
      // Kept alive for the process lifetime; the process only ever exits via
      // the handler above or an unrecoverable error.
      signalSources.append(source)
    }
    installShutdownHandler(SIGINT)
    installShutdownHandler(SIGTERM)

    Task {
      do {
        try await watcher.run { summary in
          stderr("Imported message rowID=\(summary.lastImportedRowID) (total this run: \(summary.messagesWritten))")
        }
      } catch {
        stderr("Error: \(error.localizedDescription)")
        exit(1)
      }
    }

    dispatchMain()
  } catch {
    stderr("Error: \(error.localizedDescription)")
    exit(1)
  }
}
