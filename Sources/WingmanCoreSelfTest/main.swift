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

/// A save written by an older build must survive an upgrade. Rejecting it would
/// wipe a real profile the decoder can already read.
func testOlderSchemaMigratesInsteadOfWiping() throws {
  let suiteName = "wingman-selftest-\(UUID().uuidString)"
  guard let defaults = UserDefaults(suiteName: suiteName) else {
    throw SelfTestFailure.failed("could not create isolated defaults")
  }
  defer { defaults.removePersistentDomain(forName: suiteName) }
  let store = SharedStateStore(defaults: defaults)

  var old = WingmanState.empty
  old.version = 3
  old.hasCompletedLogin = true
  old.currentProfile.displayName = "Avery"
  try store.save(old)

  let loaded = try store.load()
  try require(loaded.currentProfile.displayName == "Avery", "upgrade wiped an existing profile")
  try require(loaded.version == WingmanState.schemaVersion, "load did not migrate the version")
  try require(loaded.signedInEmail == nil, "migrated state invented a signed-in account")

  var future = WingmanState.empty
  future.version = WingmanState.schemaVersion + 1
  try store.save(future)
  do {
    _ = try store.load()
    throw SelfTestFailure.failed("a newer schema was accepted")
  } catch let error as StateStoreError {
    guard case .unsupportedSchema = error else {
      throw SelfTestFailure.failed("newer schema failed with the wrong error")
    }
  }
}

func testSyncedProfileUsesOnlyApprovedFields() throws {
  let profile = HumanProfile(
    id: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
    displayName: "Riley",
    bio: "Private biography",
    lookingFor: [.dating],
    values: ["Curiosity"],
    interests: ["Climbing"],
    communicationStyle: "Needs time to think",
    boundaries: ["No last-minute plans"],
    approvedFields: [.displayName, .lookingFor, .interests]
  )
  let synced = SyncedProfile(profile: profile.publicSnapshot, updatedAt: profile.updatedAt)
  try require(synced.displayName == "Riley", "approved name did not enter sync payload")
  try require(synced.interests == ["Climbing"], "approved interest did not enter sync payload")
  try require(synced.bio == nil, "unapproved bio entered sync payload")
  try require(synced.values.isEmpty, "unapproved values entered sync payload")
  try require(synced.communicationStyle == nil, "unapproved communication style entered sync payload")
  try require(synced.boundaries.isEmpty, "unapproved boundaries entered sync payload")
}

func testOnboardingStateRoundTrip() throws {
  var state = WingmanState.empty
  state.hasCompletedLogin = true
  state.connectedAgentProviders = [.claude, .openAI]
  let encoded = try JSONEncoder().encode(state)
  let decoded = try JSONDecoder().decode(WingmanState.self, from: encoded)
  try require(decoded.hasCompletedLogin, "completed login was not persisted")
  try require(
    decoded.connectedAgentProviders == [.claude, .openAI],
    "connected agent providers were not persisted"
  )
}

func testOnboardingProviders() throws {
  try require(
    AgentProvider.onboardingProviders == [.openAI, .claude],
    "onboarding must offer ChatGPT and Claude only"
  )
}

func testOnboardingRouteRequiresLoginThenAgentConnection() throws {
  var state = WingmanState.empty
  try require(state.onboardingRoute == .login, "fresh state did not begin with login")
  state.hasCompletedLogin = true
  try require(state.onboardingRoute == .connectAgent, "signed-in state did not request an agent connection")
  state.connectedAgentProviders = [.claude]
  try require(state.onboardingRoute == .connectAgent, "agent selection bypassed the setup review")
  state.hasCompletedAgentSetup = true
  try require(state.onboardingRoute == .app, "completed agent setup did not unlock the app")

  // A pending ChatGPT import outranks both the picker and the app, so the
  // screen cannot be skipped by state that would otherwise route past it.
  state.pendingChatGPTImport = true
  try require(state.onboardingRoute == .importingChatGPT, "pending import did not take the route")
  state.pendingChatGPTImport = false
  try require(state.onboardingRoute == .app, "finishing the import did not return to the app")
}

/// Signing in must leave the picker with nothing selected. Pre-selecting
/// ChatGPT made its row arrive ticked, so the first tap deselected it and the
/// import never ran.
func testSignInLeavesProvidersUnselected() throws {
  var state = WingmanState.empty
  state.hasCompletedLogin = true
  state.signedInEmail = DemoAccounts.eric.email
  state.currentProfile = DemoAccounts.eric.profile
  try require(
    state.connectedAgentProviders.isEmpty,
    "a freshly signed-in session already had a provider selected"
  )
  try require(state.onboardingRoute == .connectAgent, "sign-in did not reach the picker")
}

func testDemoAccountsAreDistinctAndReciprocal() throws {
  guard let eric = DemoAccounts.account(forEmail: "ERIC@gmail.com") else {
    throw SelfTestFailure.failed("email lookup is not case-insensitive")
  }
  guard let julian = DemoAccounts.account(forEmail: " julian@gmail.com ") else {
    throw SelfTestFailure.failed("email lookup did not trim whitespace")
  }
  try require(eric.profile.id != julian.profile.id, "demo accounts share a profile ID")
  try require(
    DemoAccounts.counterpart(of: eric)?.email == julian.email,
    "Eric's seeded candidate is not Julian"
  )
  try require(
    DemoAccounts.counterpart(of: julian)?.email == eric.email,
    "Julian's seeded candidate is not Eric"
  )
  try require(
    DemoAccounts.account(forEmail: "stranger@example.com") == nil,
    "an unknown email matched a demo account"
  )

  // An unrecognised address must still land somewhere, or connecting ChatGPT
  // has no context and the import screen is skipped without saying why.
  try require(
    DemoAccounts.resolve(email: "stranger@example.com").email == eric.email,
    "an unknown email did not fall back to an account"
  )
  try require(DemoAccounts.resolve(email: nil).email == eric.email, "nil email did not fall back")
  try require(
    DemoAccounts.resolve(email: "julian@gmail.com").email == julian.email,
    "resolve ignored an exact match"
  )
}

/// The whole point of splitting authored profile fields from crawled ChatGPT
/// context: a proposed interest must not reach another user until approved.
func testChatGPTProposalsStayOutOfSyncPayload() throws {
  let eric = DemoAccounts.eric
  let packet = eric.chatGPTContext
  try require(!packet.proposedInterests.isEmpty, "fixture has no proposals left to check")

  let snapshot = eric.profile.publicSnapshot
  for proposed in packet.proposedInterests + packet.proposedValues {
    try require(
      !snapshot.interests.contains(proposed) && !snapshot.values.contains(proposed),
      "ChatGPT-proposed field '\(proposed)' entered the public snapshot without approval"
    )
  }
  try require(
    snapshot.bio != packet.proposedBio,
    "ChatGPT-proposed bio entered the public snapshot without approval"
  )

  let facts = MemoryFact.chatGPTFacts(from: packet)
  try require(!facts.isEmpty, "packet produced no reviewable memory facts")
  try require(
    facts.allSatisfy { $0.source == .chatGPT },
    "derived facts were not tagged as ChatGPT-sourced, so re-import cannot replace them"
  )
}

do {
  _ = try testVisibilityAndMatching()
  try testConsentAndPayload()
  try testReplySuggestions()
  try testSharedStore()
  try testOlderSchemaMigratesInsteadOfWiping()
  try testSyncedProfileUsesOnlyApprovedFields()
  try testOnboardingStateRoundTrip()
  try testOnboardingProviders()
  try testOnboardingRouteRequiresLoginThenAgentConnection()
  try testSignInLeavesProvidersUnselected()
  try testDemoAccountsAreDistinctAndReciprocal()
  try testChatGPTProposalsStayOutOfSyncPayload()
  print("wingman-core self-test: 12 passed")
} catch {
  FileHandle.standardError.write(
    Data("wingman-core self-test failed: \(error.localizedDescription)\n".utf8))
  exit(1)
}
