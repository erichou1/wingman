import Foundation

public enum WingmanConfiguration {
  public static let appGroupIdentifier = "group.com.naitikgupta.wingman"
  public static let appBundleIdentifier = "com.naitikgupta.wingman"
  public static let messagesBundleIdentifier = "com.naitikgupta.wingman.messages"
}

public enum StateStoreError: LocalizedError {
  case appGroupUnavailable
  case unsupportedSchema(Int)
  case decodingFailed

  public var errorDescription: String? {
    switch self {
    case .appGroupUnavailable: "Wingman could not open its shared App Group."
    case .unsupportedSchema(let version): "Wingman data uses unsupported schema version \(version)."
    case .decodingFailed: "Wingman could not read its shared data."
    }
  }
}

public struct SharedStateStore {
  private static let stateKey = "wingman.state.v1"
  private let defaults: UserDefaults

  public init(appGroupIdentifier: String = WingmanConfiguration.appGroupIdentifier) throws {
    guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
      throw StateStoreError.appGroupUnavailable
    }
    self.defaults = defaults
  }

  public init(defaults: UserDefaults) {
    self.defaults = defaults
  }

  public func load() throws -> WingmanState {
    guard let data = defaults.data(forKey: Self.stateKey) else { return .empty }
    do {
      let state = try JSONDecoder.wingman.decode(WingmanState.self, from: data)
      // Older saves migrate forward: every field added since v1 decodes with
      // `decodeIfPresent` and a default, so an equality check here would reject
      // state the decoder can already read — wiping a real profile on upgrade,
      // which is the exact failure that decoder was written to avoid. Newer
      // schemas are still refused, since this build cannot know their shape.
      guard state.version <= WingmanState.schemaVersion else {
        throw StateStoreError.unsupportedSchema(state.version)
      }
      var migrated = state
      migrated.version = WingmanState.schemaVersion
      return migrated
    } catch let error as StateStoreError {
      throw error
    } catch {
      throw StateStoreError.decodingFailed
    }
  }

  public func save(_ state: WingmanState) throws {
    let data = try JSONEncoder.wingman.encode(state)
    defaults.set(data, forKey: Self.stateKey)
  }

  public func erase() {
    defaults.removeObject(forKey: Self.stateKey)
  }
}

extension JSONEncoder {
  fileprivate static var wingman: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }
}

extension JSONDecoder {
  fileprivate static var wingman: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
  }
}
