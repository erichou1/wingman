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

  var state: WingmanState
  var replyRequest = ReplyRequest(incomingMessage: "", relationship: .friendship)
  var replySuggestions: [ReplySuggestion] = []
  // @Snapshotable
  var isGeneratingReplies: Bool = false
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
