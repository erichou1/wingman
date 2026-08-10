import Foundation

public struct SyncedProfile: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  public let displayName: String
  public let bio: String?
  public let lookingFor: Set<RelationshipKind>
  public let values: [String]
  public let interests: [String]
  public let lifestyle: [String]
  public let communicationStyle: String?
  public let boundaries: [String]
  public let updatedAt: Date

  public init(profile: ApprovedProfile, updatedAt: Date) {
    id = profile.id
    displayName = profile.displayName
    bio = profile.bio
    lookingFor = profile.lookingFor
    values = profile.values
    interests = profile.interests
    lifestyle = profile.lifestyle
    communicationStyle = profile.communicationStyle
    boundaries = profile.boundaries
    self.updatedAt = updatedAt
  }

  public func asHumanProfile() -> HumanProfile {
    var approvedFields: Set<ProfileField> = [.displayName, .lookingFor]
    if bio != nil { approvedFields.insert(.bio) }
    if !values.isEmpty { approvedFields.insert(.values) }
    if !interests.isEmpty { approvedFields.insert(.interests) }
    if !lifestyle.isEmpty { approvedFields.insert(.lifestyle) }
    if communicationStyle != nil { approvedFields.insert(.communicationStyle) }
    if !boundaries.isEmpty { approvedFields.insert(.boundaries) }

    return HumanProfile(
      id: id,
      displayName: displayName,
      bio: bio ?? "",
      lookingFor: lookingFor,
      values: values,
      interests: interests,
      lifestyle: lifestyle,
      communicationStyle: communicationStyle ?? "",
      boundaries: boundaries,
      approvedFields: approvedFields,
      updatedAt: updatedAt
    )
  }
}

public struct WingmanSyncConfiguration: Equatable, Sendable {
  public let baseURL: URL

  public init?(baseURLString: String) {
    let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.hasPrefix("$("),
      let url = URL(string: trimmed),
      let scheme = url.scheme?.lowercased(),
      ["http", "https"].contains(scheme),
      url.host != nil
    else {
      return nil
    }
    baseURL = url
  }

  public static func fromBundle(_ bundle: Bundle = .main) -> WingmanSyncConfiguration? {
    guard let value = bundle.object(forInfoDictionaryKey: "WINGMAN_SYNC_BASE_URL") as? String else {
      return nil
    }
    return WingmanSyncConfiguration(baseURLString: value)
  }

  public func endpoint(path: String) -> URL? {
    URL(string: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")), relativeTo: baseURL)?.absoluteURL
  }
}

public enum WingmanSyncError: LocalizedError, Equatable {
  case invalidEndpoint
  case invalidResponse
  case httpError(status: Int, body: String)
  case decodingFailed

  public var errorDescription: String? {
    switch self {
    case .invalidEndpoint:
      return "Wingman sync URL is invalid."
    case .invalidResponse:
      return "Wingman sync server returned an invalid response."
    case .httpError(let status, let body):
      return "Wingman sync failed (HTTP \(status)): \(body)"
    case .decodingFailed:
      return "Wingman could not read the sync response."
    }
  }
}

public final class WingmanSyncClient: Sendable {
  private let configuration: WingmanSyncConfiguration
  private let session: URLSession
  private let token: String?

  public init(
    configuration: WingmanSyncConfiguration,
    session: URLSession = .shared,
    token: String? = nil
  ) {
    self.configuration = configuration
    self.session = session
    let trimmedToken = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    self.token = trimmedToken.isEmpty ? nil : trimmedToken
  }

  public static func tokenFromBundle(_ bundle: Bundle = .main) -> String? {
    guard let value = bundle.object(forInfoDictionaryKey: "WINGMAN_GATEWAY_TOKEN") as? String else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.hasPrefix("$("), trimmed != "wingman-REPLACE_ME" else {
      return nil
    }
    return trimmed
  }

  public func sync(profile: HumanProfile) async throws -> [HumanProfile] {
    let payload = SyncedProfile(profile: profile.publicSnapshot, updatedAt: profile.updatedAt)
    guard let uploadURL = configuration.endpoint(path: "/v1/profiles/\(payload.id.uuidString.lowercased())") else {
      throw WingmanSyncError.invalidEndpoint
    }

    var request = URLRequest(url: uploadURL)
    request.httpMethod = "PUT"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    request.httpBody = try JSONEncoder.wingmanSync.encode(payload)
    _ = try await perform(request, responseType: ProfileEnvelope.self)

    guard let feedURL = configuration.endpoint(path: "/v1/profiles") else {
      throw WingmanSyncError.invalidEndpoint
    }
    var components = URLComponents(url: feedURL, resolvingAgainstBaseURL: false)
    components?.queryItems = [URLQueryItem(name: "exclude", value: payload.id.uuidString.lowercased())]
    guard let resolvedFeedURL = components?.url else { throw WingmanSyncError.invalidEndpoint }
    var feedRequest = URLRequest(url: resolvedFeedURL)
    if let token { feedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    let feed = try await perform(feedRequest, responseType: ProfileFeed.self)
    return feed.profiles.map { $0.asHumanProfile() }
  }

  private func perform<Response: Decodable>(_ request: URLRequest, responseType: Response.Type) async throws -> Response {
    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw WingmanSyncError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw WingmanSyncError.httpError(
        status: httpResponse.statusCode,
        body: String(data: data, encoding: .utf8) ?? "<no body>"
      )
    }
    guard let decoded = try? JSONDecoder.wingmanSync.decode(Response.self, from: data) else {
      throw WingmanSyncError.decodingFailed
    }
    return decoded
  }
}

private struct ProfileEnvelope: Decodable {
  let profile: SyncedProfile
}

private struct ProfileFeed: Decodable {
  let profiles: [SyncedProfile]
}

private extension JSONEncoder {
  static var wingmanSync: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
  }
}

private extension JSONDecoder {
  static var wingmanSync: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
