import Foundation

public enum MatchEngine {
  public static func compare(_ first: ApprovedProfile, _ second: ApprovedProfile) -> MatchInsight {
    let relationshipKinds = first.lookingFor.intersection(second.lookingFor).sorted {
      $0.rawValue < $1.rawValue
    }
    let sharedValues = intersection(first.values, second.values)
    let sharedInterests = intersection(first.interests, second.interests)
    let sharedLifestyle = intersection(first.lifestyle, second.lifestyle)

    var resonance: [String] = []
    if !sharedValues.isEmpty {
      resonance.append("You both care about \(naturalList(sharedValues)).")
    }
    if !sharedInterests.isEmpty {
      resonance.append("You could connect over \(naturalList(sharedInterests)).")
    }
    if !sharedLifestyle.isEmpty {
      resonance.append("Your day-to-day lives both include \(naturalList(sharedLifestyle)).")
    }
    if resonance.isEmpty {
      resonance.append(
        "Your approved profiles leave room for discovery instead of assuming compatibility.")
    }

    var friction: [String] = []
    if relationshipKinds.isEmpty {
      friction.append("You are not currently open to the same relationship category.")
    }
    if let firstStyle = first.communicationStyle, let secondStyle = second.communicationStyle,
      normalized(firstStyle) != normalized(secondStyle)
    {
      friction.append(
        "Your communication styles differ: \(firstStyle) and \(secondStyle). Name that early.")
    }
    if !first.boundaries.isEmpty || !second.boundaries.isEmpty {
      friction.append("Both profiles include boundaries worth discussing before making plans.")
    }
    if friction.isEmpty {
      friction.append(
        "No obvious friction appears in the approved fields; real chemistry still needs a conversation."
      )
    }

    let starterSource =
      sharedInterests.first ?? sharedValues.first ?? "what has your attention lately"
    let starters = [
      "What do you enjoy most about \(starterSource)?",
      "What kind of connection would feel worthwhile right now?",
      "What is something your profile cannot capture about you?",
    ]

    return MatchInsight(
      firstProfileID: first.id,
      secondProfileID: second.id,
      relationshipKinds: relationshipKinds,
      resonance: resonance,
      friction: friction,
      conversationStarters: starters
    )
  }

  private static func intersection(_ first: [String], _ second: [String]) -> [String] {
    let secondValues = Set(second.map(normalized))
    return first.filter { secondValues.contains(normalized($0)) }
  }

  private static func normalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private static func naturalList(_ values: [String]) -> String {
    let visible = Array(values.prefix(3))
    return switch visible.count {
    case 0: ""
    case 1: visible[0]
    case 2: "\(visible[0]) and \(visible[1])"
    default: "\(visible.dropLast().joined(separator: ", ")), and \(visible.last!)"
    }
  }
}

public enum IntroductionError: LocalizedError, Equatable {
  case consentRequired
  case profileMismatch

  public var errorDescription: String? {
    switch self {
    case .consentRequired: "Both humans must approve this introduction."
    case .profileMismatch: "The insight does not belong to these profiles."
    }
  }
}

public enum IntroductionFactory {
  public static func makeCard(
    first: ApprovedProfile,
    second: ApprovedProfile,
    insight: MatchInsight,
    consent: IntroductionConsent
  ) throws -> IntroductionCard {
    let expectedIDs = Set([first.id, second.id])
    let insightIDs = Set([insight.firstProfileID, insight.secondProfileID])
    guard expectedIDs == insightIDs, consent.matchID == insight.id else {
      throw IntroductionError.profileMismatch
    }
    guard consent.canIntroduce else {
      throw IntroductionError.consentRequired
    }

    return IntroductionCard(
      matchID: insight.id,
      firstName: first.displayName,
      secondName: second.displayName,
      relationshipLabel: insight.relationshipKinds.map(\.title).joined(separator: " or ").nilIfEmpty
        ?? "A new connection",
      resonance: insight.resonance.first ?? "There may be something worth exploring.",
      friction: insight.friction.first ?? "Let the conversation test the fit.",
      conversationStarter: insight.conversationStarters.first
        ?? "What would you like to know about each other?",
      createdAt: Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
    )
  }
}

extension String {
  fileprivate var nilIfEmpty: String? { isEmpty ? nil : self }
}
