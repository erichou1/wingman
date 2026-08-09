import Foundation

public enum RenderReplyError: LocalizedError, Equatable {
  case invalidEndpoint
  case invalidResponse
  case httpError(status: Int)
  case decodingFailed

  public var errorDescription: String? {
    switch self {
    case .invalidEndpoint:
      return "Render Workflow URL is invalid."
    case .invalidResponse:
      return "Render Workflow gateway returned an unexpected response."
    case .httpError(let status):
      return "Render Workflow gateway failed (HTTP \(status))."
    case .decodingFailed:
      return "Could not decode the Render Workflow response."
    }
  }
}

/// Calls the small Render web gateway that triggers Wingman's Render Workflow.
/// The Render API key stays on the gateway and is never shipped in the iOS app.
public final class RenderReplyClient: Sendable {
  private let session: URLSession
  private let endpoint: URL

  public init(session: URLSession = .shared, endpoint: URL) {
    self.session = session
    self.endpoint = endpoint
  }

  public static func endpointFromBundle(_ bundle: Bundle = .main) -> URL? {
    guard let value = bundle.object(forInfoDictionaryKey: "RENDER_WORKFLOW_URL") as? String else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.hasPrefix("$("), trimmed != "https://your-gateway.onrender.com",
      let url = URL(string: trimmed), let scheme = url.scheme, let host = url.host,
      scheme == "https" || (scheme == "http" && ["localhost", "127.0.0.1"].contains(host.lowercased()))
    else {
      return nil
    }
    return url.appendingPathComponent("v1/reply-drafts")
  }

  public func suggest(
    for request: ReplyRequest,
    writingStyle: WritingStyleProfile,
    memories: [MemoryFact]
  ) async throws -> [ReplySuggestion] {
    var urlRequest = URLRequest(url: endpoint)
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.httpBody = try JSONEncoder().encode(
      RenderReplyRequest(
        incomingMessage: request.incomingMessage,
        relationship: request.relationship.rawValue,
        context: request.context,
        goal: request.goal,
        writingStyle: writingStyle,
        memories: memories.map(\.text)
      )
    )

    let (data, response) = try await session.data(for: urlRequest)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw RenderReplyError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw RenderReplyError.httpError(status: httpResponse.statusCode)
    }

    guard let decoded = try? JSONDecoder().decode(RenderReplyResponse.self, from: data) else {
      throw RenderReplyError.decodingFailed
    }
    return decoded.drafts.map {
      ReplySuggestion(tone: $0.tone, text: $0.text, rationale: $0.rationale)
    }
  }
}

private struct RenderReplyRequest: Encodable {
  let incomingMessage: String
  let relationship: String
  let context: String
  let goal: String
  let writingStyle: WritingStyleProfile
  let memories: [String]
}

private struct RenderReplyResponse: Decodable {
  struct Draft: Decodable {
    let tone: ReplySuggestion.Tone
    let text: String
    let rationale: String
  }

  let drafts: [Draft]
}
