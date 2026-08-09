import Foundation
import Messages
import Observation
import WingmanCore

@MainActor
@Observable
final class MessagesExtensionModel {
  enum Mode: String, CaseIterable, Identifiable {
    case reply
    case meet

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
  }

  // @Snapshotable
  var selectedMode: String = Mode.reply.rawValue
  // @Snapshotable
  var suggestionCount: Int = 0
  // @Snapshotable
  var introductionReady: Bool = false
  // @Snapshotable
  var isGeneratingReplies: Bool = false
  // @Snapshotable
  var lastError: String? = nil

  var mode: Mode = .reply {
    didSet { selectedMode = mode.rawValue }
  }
  var presentationStyle: MSMessagesAppPresentationStyle = .compact
  var state: WingmanState = .empty
  var replyRequest = ReplyRequest(incomingMessage: "", relationship: .friendship)
  var replySuggestions: [ReplySuggestion] = []
  var receivedCard: IntroductionCard?

  private let store: SharedStateStore?

  init(store: SharedStateStore? = try? SharedStateStore()) {
    self.store = store
    reload()
  }

  var latestInsight: MatchInsight? { state.insights.last }

  var latestConsent: IntroductionConsent? {
    guard let matchID = latestInsight?.id else { return nil }
    return state.consents.first(where: { $0.matchID == matchID })
  }

  func reload() {
    do {
      state = try store?.load() ?? .empty
      lastError = nil
    } catch {
      state = .empty
      lastError = error.localizedDescription
    }
    introductionReady = latestConsent?.canIntroduce == true
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
    suggestionCount = replySuggestions.count
  }

  func makeIntroductionCard() throws -> IntroductionCard {
    guard let insight = latestInsight,
      let consent = latestConsent,
      let candidate = state.candidates.first(where: {
        $0.id == insight.firstProfileID || $0.id == insight.secondProfileID
      }),
      state.currentProfile.id == insight.firstProfileID || state.currentProfile.id == insight.secondProfileID
    else {
      throw IntroductionError.profileMismatch
    }
    return try IntroductionFactory.makeCard(
      first: state.currentProfile.publicSnapshot,
      second: candidate.publicSnapshot,
      insight: insight,
      consent: consent
    )
  }

  func select(message: MSMessage?) {
    guard let url = message?.url else {
      receivedCard = nil
      return
    }
    receivedCard = try? MessagePayloadCodec.decode(url)
    if receivedCard != nil { mode = .meet }
  }
}
