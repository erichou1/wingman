import Foundation
import Observation
import WingmanCore

@MainActor
@Observable
final class AppModel {
  // @Snapshotable
  var selectedTab: String = "home"
  // @Snapshotable
  var profileReady: Bool = false
  // @Snapshotable
  var candidateCount: Int = 0
  // @Snapshotable
  var lastError: String? = nil
  // @Snapshotable
  var loginEmail: String = ""

  var state: WingmanState
  var replyRequest = ReplyRequest(incomingMessage: "", relationship: .friendship)
  var replySuggestions: [ReplySuggestion] = []
  // @Snapshotable
  var isGeneratingReplies: Bool = false
  // @Snapshotable
  var isSyncingProfiles: Bool = false
  // @Snapshotable
  var lastProfileSyncAt: Date? = nil
  var selectedCandidateID: UUID?
  var selectedInsightID: UUID?

  private let store: SharedStateStore?

  init(store: SharedStateStore? = try? SharedStateStore()) {
    self.store = store
    do {
      self.state = try store?.load() ?? .empty
    } catch {
      self.state = .empty
      self.lastError = error.localizedDescription
    }
    refreshSnapshot()
  }

  func completePrototypeLogin() {
    let email = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    guard email.contains("@"), email.contains(".") else {
      lastError = "Enter a valid email address to continue."
      return
    }
    state.hasCompletedLogin = true
    state.hasCompletedAgentSetup = false
    state.signedInEmail = email
    seed(DemoAccounts.resolve(email: email))
    save()
  }

  /// The account backing this session. Always resolves, so every sign-in lands
  /// in a usable demo state.
  var activeDemoAccount: DemoAccount {
    DemoAccounts.resolve(email: state.signedInEmail)
  }

  var chatGPTContext: ChatGPTContextPacket {
    activeDemoAccount.chatGPTContext
  }

  /// The picker's primary action. ChatGPT's import runs from here rather than
  /// from the row itself, so choosing a provider only ticks it and nothing
  /// happens until the person commits.
  func continueFromAgentSetup() {
    guard !state.connectedAgentProviders.isEmpty else {
      lastError = "Choose at least one AI provider before continuing."
      return
    }
    if state.connectedAgentProviders.contains(.openAI) {
      beginChatGPTImport()
    } else {
      completeAgentSetup()
    }
  }

  /// Routes to the ChatGPT import screen.
  func beginChatGPTImport() {
    state.hasCompletedAgentSetup = false
    state.pendingChatGPTImport = true
    save()
  }

  /// Finishing the import is what completes agent setup, so the person lands in
  /// the app rather than back on the picker they already committed from.
  func completeChatGPTImport() {
    state.pendingChatGPTImport = false
    state.hasCompletedAgentSetup = true
    save()
  }

  /// Loads an account: its authored profile, its ChatGPT-derived memories, and
  /// the other account as a discovery candidate.
  ///
  /// Deliberately leaves `connectedAgentProviders` empty. Pre-selecting ChatGPT
  /// here made the picker arrive with its row already ticked, so the first tap
  /// read as a deselect and the import never ran.
  private func seed(_ account: DemoAccount) {
    state.currentProfile = account.profile
    state.memories.removeAll { $0.source == .chatGPT }
    state.memories.append(contentsOf: MemoryFact.chatGPTFacts(from: account.chatGPTContext))
    state.connectedAgentProviders = []

    let others = DemoAccounts.counterparts(of: account)
    if !others.isEmpty {
      state.candidates = others.map(\.profile)
      selectedCandidateID = others.first?.profile.id
    }
  }

  func returnToLogin() {
    state.hasCompletedLogin = false
    state.signedInEmail = nil
    state.connectedAgentProviders = []
    state.hasCompletedAgentSetup = false
    // Without this, signing out during the import leaves the flag set and the
    // next sign-in routes straight back into the import screen.
    state.pendingChatGPTImport = false
    save()
  }

  /// Signs out to the login screen. Profile, memories, and candidates stay on
  /// device; signing back in re-seeds them.
  func signOut() {
    returnToLogin()
    loginEmail = ""
    replySuggestions = []
    selectedCandidateID = nil
    selectedInsightID = nil
  }

  func toggleAgentProvider(_ provider: AgentProvider) {
    if let index = state.connectedAgentProviders.firstIndex(of: provider) {
      state.connectedAgentProviders.remove(at: index)
    } else {
      state.connectedAgentProviders.append(provider)
    }
    state.hasCompletedAgentSetup = false
    save()
  }

  func completeAgentSetup() {
    guard !state.connectedAgentProviders.isEmpty else {
      lastError = "Choose at least one AI provider before continuing."
      return
    }
    state.hasCompletedAgentSetup = true
    save()
  }

  var selectedCandidate: HumanProfile? {
    guard let selectedCandidateID else { return state.candidates.first }
    return state.candidates.first(where: { $0.id == selectedCandidateID })
  }

  var selectedInsight: MatchInsight? {
    guard let selectedInsightID else { return state.insights.last }
    return state.insights.first(where: { $0.id == selectedInsightID })
  }

  func save() {
    state.currentProfile.updatedAt = Date()
    state.updatedAt = Date()
    do {
      try store?.save(state)
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
    refreshSnapshot()
  }

  func generateReplies() {
    guard !isGeneratingReplies else { return }
    Task { await performReplyGeneration() }
  }

  private func performReplyGeneration() async {
    isGeneratingReplies = true
    defer { isGeneratingReplies = false }
    do {
      replySuggestions = try await NIMReplyAssistant.suggest(
        for: replyRequest,
        writingStyle: state.writingStyle,
        memories: state.memories
      )
      lastError = nil
    } catch {
      replySuggestions = ReplyAssistant.suggest(for: replyRequest)
      lastError = "Using offline drafts — NVIDIA NIM request failed: \(error.localizedDescription)"
    }
  }

  var syncIsConfigured: Bool {
    WingmanSyncConfiguration.fromBundle() != nil
  }

  func syncProfiles() {
    guard !isSyncingProfiles else { return }
    Task { await performProfileSync() }
  }

  private func performProfileSync() async {
    guard state.currentProfile.isReadyForIntroductions else {
      lastError = "Approve your name, connection types, and at least one value or interest before syncing."
      return
    }
    guard let configuration = WingmanSyncConfiguration.fromBundle() else {
      lastError = "Set WINGMAN_SYNC_BASE_URL in Secrets.xcconfig, rebuild, then try sync again."
      return
    }

    isSyncingProfiles = true
    defer { isSyncingProfiles = false }
    save()
    do {
      let client = WingmanSyncClient(
        configuration: configuration,
        token: WingmanSyncClient.tokenFromBundle()
      )
      state.candidates = try await client.sync(profile: state.currentProfile)
      selectedCandidateID = state.candidates.first?.id
      state.updatedAt = Date()
      try store?.save(state)
      lastProfileSyncAt = Date()
      lastError = nil
      refreshSnapshot()
    } catch {
      lastError = "Could not sync profiles: \(error.localizedDescription)"
    }
  }

  func seedDemoCandidate() {
    guard state.candidates.isEmpty else { return }
    let candidate = HumanProfile(
      displayName: "Jordan",
      bio: "Community builder, careful listener, and enthusiastic home cook.",
      lookingFor: [.friendship, .community, .newConnection],
      values: ["Kindness", "Curiosity", "Reliability"],
      interests: ["Hiking", "Live music", "Cooking"],
      lifestyle: ["Morning walks", "Creative work", "Small gatherings"],
      communicationStyle: "Reflect first, then talk directly",
      boundaries: ["Plans need a little notice", "No pressure to reply immediately"],
      approvedFields: Set(ProfileField.allCases)
    )
    state.candidates = [candidate]
    selectedCandidateID = candidate.id
    save()
  }

  func compareSelectedProfiles() {
    guard state.currentProfile.isReadyForIntroductions, let candidate = selectedCandidate,
      candidate.isReadyForIntroductions
    else {
      lastError = "Approve your name, connection types, and at least one value or interest first."
      return
    }
    let replacedMatchIDs = state.insights.filter {
      Set([$0.firstProfileID, $0.secondProfileID])
        == Set([state.currentProfile.id, candidate.id])
    }.map(\.id)
    state.insights.removeAll { replacedMatchIDs.contains($0.id) }
    state.consents.removeAll { replacedMatchIDs.contains($0.matchID) }

    let insight = MatchEngine.compare(state.currentProfile.publicSnapshot, candidate.publicSnapshot)
    state.insights.append(insight)
    state.consents.append(IntroductionConsent(matchID: insight.id))
    selectedInsightID = insight.id
    save()
  }

  func consent(for matchID: UUID) -> IntroductionConsent {
    state.consents.first(where: { $0.matchID == matchID })
      ?? IntroductionConsent(matchID: matchID)
  }

  func setConsent(matchID: UUID, firstHuman: Bool? = nil, secondHuman: Bool? = nil) {
    guard let index = state.consents.firstIndex(where: { $0.matchID == matchID }) else { return }
    if let firstHuman { state.consents[index].firstHumanApproved = firstHuman }
    if let secondHuman { state.consents[index].secondHumanApproved = secondHuman }
    state.consents[index].updatedAt = Date()
    save()
  }

  func addMemory(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    state.memories.append(MemoryFact(text: trimmed, source: .userEntered))
    save()
  }

  func removeMemory(id: UUID) {
    state.memories.removeAll { $0.id == id }
    save()
  }

  func importMacGraph(from url: URL) {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let graph = try decoder.decode(ImportedRelationshipGraph.self, from: data)
      state.memories.removeAll { $0.source == .macGraph }
      state.memories.append(contentsOf: MemoryFact.macGraphFacts(from: graph))
      lastError = nil
      save()
    } catch {
      lastError = "Could not import that graph file: \(error.localizedDescription)"
    }
  }

  func eraseWingmanData() {
    store?.erase()
    state = .empty
    replyRequest = ReplyRequest(incomingMessage: "", relationship: .friendship)
    replySuggestions = []
    selectedCandidateID = nil
    selectedInsightID = nil
    lastError = nil
    refreshSnapshot()
  }

  private func refreshSnapshot() {
    profileReady = state.currentProfile.isReadyForIntroductions
    candidateCount = state.candidates.count
  }
}
