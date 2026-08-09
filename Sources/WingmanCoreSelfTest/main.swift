import Foundation
import WingmanCore

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

func approvedProfile(
  id: UUID,
  name: String,
  kinds: Set<RelationshipKind>,
  values: [String],
  interests: [String],
  style: String
) -> HumanProfile {
  HumanProfile(
    id: id,
    displayName: name,
    bio: "A real human, not a compatibility score.",
    lookingFor: kinds,
    values: values,
    interests: interests,
    lifestyle: ["walks", "creative work"],
    communicationStyle: style,
    boundaries: ["Ask before inviting extra people"],
    approvedFields: Set(ProfileField.allCases)
  )
}

func testVisibilityAndMatching() throws -> (ApprovedProfile, ApprovedProfile, MatchInsight) {
  var first = approvedProfile(
    id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
    name: "Avery",
    kinds: [.friendship, .community],
    values: ["Curiosity", "Kindness"],
    interests: ["Hiking", "Live music"],
    style: "Talk it through"
  )
  first.approvedFields.remove(.boundaries)
  let second = approvedProfile(
    id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
    name: "Jordan",
    kinds: [.friendship],
    values: ["Kindness"],
    interests: ["Hiking", "Cooking"],
    style: "Reflect, then talk"
  )

  let firstPublic = first.publicSnapshot
  let secondPublic = second.publicSnapshot
  try require(firstPublic.boundaries.isEmpty, "unapproved boundary escaped the profile")
  try require(first.isReadyForIntroductions, "approved profile was not ready")

  let insight = MatchEngine.compare(firstPublic, secondPublic)
  try require(insight.relationshipKinds == [.friendship], "relationship overlap was incorrect")
  try require(
    insight.resonance.contains(where: { $0.contains("Kindness") }), "shared value was missed")
  try require(
    insight.resonance.contains(where: { $0.contains("Hiking") }), "shared interest was missed")
  try require(!insight.friction.isEmpty, "friction explanation was omitted")
  return (firstPublic, secondPublic, insight)
}

func testConsentAndPayload() throws {
  let (first, second, insight) = try testVisibilityAndMatching()
  let missingConsent = IntroductionConsent(matchID: insight.id, firstHumanApproved: true)
  do {
    _ = try IntroductionFactory.makeCard(
      first: first,
      second: second,
      insight: insight,
      consent: missingConsent
    )
    throw SelfTestFailure.failed("one-sided consent produced a card")
  } catch let error as IntroductionError {
    try require(error == .consentRequired, "wrong consent failure")
  }

  let consent = IntroductionConsent(
    matchID: insight.id,
    firstHumanApproved: true,
    secondHumanApproved: true
  )
  let card = try IntroductionFactory.makeCard(
    first: first,
    second: second,
    insight: insight,
    consent: consent
  )
  let url = try MessagePayloadCodec.encode(card)
  let decoded = try MessagePayloadCodec.decode(url)
  try require(decoded == card, "introduction message payload did not round-trip")
}

func testReplySuggestions() throws {
  let suggestions = ReplyAssistant.suggest(
    for: ReplyRequest(
      incomingMessage: "I felt left out when plans changed without me.",
      relationship: .friendship,
      context: "We usually talk directly",
      goal: "clear the air"
    )
  )
  try require(suggestions.count == 3, "expected three reply choices")
  try require(Set(suggestions.map(\.tone)).count == 3, "reply tones were duplicated")
  try require(suggestions.allSatisfy { !$0.text.isEmpty }, "empty reply was generated")
  try require(
    ReplyAssistant.suggest(for: ReplyRequest(incomingMessage: "", relationship: .family)).isEmpty,
    "blank input produced a reply"
  )
}

func testSharedStore() throws {
  let suiteName = "wingman-selftest-\(UUID().uuidString)"
  guard let defaults = UserDefaults(suiteName: suiteName) else {
    throw SelfTestFailure.failed("could not create isolated defaults")
  }
  defer { defaults.removePersistentDomain(forName: suiteName) }
  let store = SharedStateStore(defaults: defaults)
  var state = WingmanState.empty
  let stableDate = Date(timeIntervalSince1970: 1_700_000_000)
  state.currentProfile.displayName = "Avery"
  state.currentProfile.updatedAt = stableDate
  state.updatedAt = stableDate
  try store.save(state)
  let reloadedState = try store.load()
  try require(reloadedState == state, "shared state did not round-trip")
  store.erase()
  let erasedState = try store.load()
  try require(erasedState == .empty, "shared state erase failed")
}

do {
  _ = try testVisibilityAndMatching()
  try testConsentAndPayload()
  try testReplySuggestions()
  try testSharedStore()
  print("wingman-core self-test: 4 passed")
} catch {
  FileHandle.standardError.write(
    Data("wingman-core self-test failed: \(error.localizedDescription)\n".utf8))
  exit(1)
}
