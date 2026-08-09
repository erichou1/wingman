import Foundation

public enum MessagePayloadError: LocalizedError, Equatable {
  case invalidURL
  case missingPayload
  case invalidPayload

  public var errorDescription: String? {
    switch self {
    case .invalidURL: "Could not create an introduction URL."
    case .missingPayload: "This message does not contain a Wingman introduction."
    case .invalidPayload: "This Wingman introduction is damaged or unsupported."
    }
  }
}

public enum MessagePayloadCodec {
  public static func encode(_ card: IntroductionCard) throws -> URL {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    let payload = try encoder.encode(card).base64URLEncodedString()
    var components = URLComponents()
    components.scheme = "wingman"
    components.host = "introduction"
    components.queryItems = [
      URLQueryItem(name: "v", value: "1"), URLQueryItem(name: "payload", value: payload),
    ]
    guard let url = components.url else { throw MessagePayloadError.invalidURL }
    return url
  }

  public static func decode(_ url: URL) throws -> IntroductionCard {
    guard url.scheme == "wingman", url.host == "introduction",
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
      throw MessagePayloadError.invalidURL
    }
    guard let payload = components.queryItems?.first(where: { $0.name == "payload" })?.value else {
      throw MessagePayloadError.missingPayload
    }
    guard let data = Data(base64URLEncoded: payload) else {
      throw MessagePayloadError.invalidPayload
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    do {
      return try decoder.decode(IntroductionCard.self, from: data)
    } catch {
      throw MessagePayloadError.invalidPayload
    }
  }
}

extension Data {
  fileprivate func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  fileprivate init?(base64URLEncoded value: String) {
    var base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(
      of: "_", with: "/")
    let padding = (4 - base64.count % 4) % 4
    base64 += String(repeating: "=", count: padding)
    self.init(base64Encoded: base64)
  }
}
