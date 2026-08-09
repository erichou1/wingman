import Foundation

/// Thin client for NVIDIA NIM's OpenAI-compatible chat-completions endpoint.
/// Foundation-only (no UIKit/SwiftUI), so it's safe in this cross-platform
/// target the same way everything else here is.
public enum NIMError: LocalizedError, Equatable {
  case missingAPIKey
  case invalidResponse
  case httpError(status: Int, body: String)
  case decodingFailed

  public var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      return "No NVIDIA_API_KEY found in the app bundle. Add one to Secrets.xcconfig and rebuild."
    case .invalidResponse:
      return "NVIDIA NIM returned an unexpected response."
    case .httpError(let status, let body):
      return "NVIDIA NIM request failed (HTTP \(status)): \(body)"
    case .decodingFailed:
      return "Could not decode NVIDIA NIM's response."
    }
  }
}

public struct NIMChatMessage: Encodable, Sendable {
  public let role: String
  public let content: String

  public init(role: String, content: String) {
    self.role = role
    self.content = content
  }
}

public final class NIMClient: Sendable {
  /// A small, fast instruct model — good fit for short reply drafts.
  public static let defaultModel = "meta/llama-3.1-8b-instruct"

  private static let endpoint = URL(string: "https://integrate.api.nvidia.com/v1/chat/completions")!

  private let session: URLSession
  private let apiKey: String?

  public init(session: URLSession = .shared, apiKey: String? = NIMClient.apiKeyFromBundle()) {
    self.session = session
    self.apiKey = apiKey
  }

  /// Reads the key injected into Info.plist from Secrets.xcconfig at build
  /// time. Guards against the unsubstituted `$(NVIDIA_API_KEY)` placeholder
  /// (no Secrets.xcconfig present) and the example file's dummy value.
  public static func apiKeyFromBundle(_ bundle: Bundle = .main) -> String? {
    guard let value = bundle.object(forInfoDictionaryKey: "NVIDIA_API_KEY") as? String else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.hasPrefix("$("), trimmed != "nvapi-REPLACE_ME" else {
      return nil
    }
    return trimmed
  }

  public var hasAPIKey: Bool { apiKey != nil }

  public func complete(
    system: String,
    user: String,
    model: String = NIMClient.defaultModel,
    maxTokens: Int = 220,
    temperature: Double = 0.7
  ) async throws -> String {
    guard let apiKey else { throw NIMError.missingAPIKey }

    let requestBody = ChatCompletionRequest(
      model: model,
      messages: [
        NIMChatMessage(role: "system", content: system),
        NIMChatMessage(role: "user", content: user),
      ],
      max_tokens: maxTokens,
      temperature: temperature
    )

    var request = URLRequest(url: Self.endpoint)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(requestBody)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw NIMError.invalidResponse
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? "<no body>"
      throw NIMError.httpError(status: httpResponse.statusCode, body: body)
    }

    guard let decoded = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data),
      let content = decoded.choices.first?.message.content
    else {
      throw NIMError.decodingFailed
    }
    return content.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

private struct ChatCompletionRequest: Encodable {
  let model: String
  let messages: [NIMChatMessage]
  let max_tokens: Int
  let temperature: Double
}

private struct ChatCompletionResponse: Decodable {
  struct Choice: Decodable {
    struct ResponseMessage: Decodable {
      let role: String
      let content: String
    }
    let message: ResponseMessage
  }
  let choices: [Choice]
}
