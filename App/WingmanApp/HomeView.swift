import SwiftUI
import UIKit
import WingmanCore

/// The landing screen: the people your connected agents put in front of you,
/// one card at a time. Swipe right to like, left to pass, or use the rail of
/// buttons underneath.
///
/// Liking someone selects them, so the Meet tab can show what the wingpeople
/// noticed about the two of you and take both approvals. Nothing here sends
/// anything — a like is a private signal until both humans approve.
struct HomeView: View {
  @Bindable var model: AppModel

  /// The people already swiped, most recent last, so the rewind button can put
  /// one back. Deliberately view state: a pass is a "not now" in this session,
  /// not a durable rejection written into the shared store.
  @State private var swiped: [UUID] = []
  @State private var cardTranslation: CGSize = .zero
  @State private var isComposingReply = false
  @State private var matched: SwipeCandidate?

  var body: some View {
    VStack(spacing: 0) {
      topBar
        .padding(.horizontal, 20)
        .padding(.bottom, 14)

      if deck.isEmpty {
        emptyDeck
      } else {
        cardStack
        actionRail
          .padding(.top, 20)
          .padding(.bottom, 8)
      }
    }
    .padding(.top, 10)
    .editorialPage()
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $isComposingReply) {
      ReplyComposerSheet(model: model)
    }
    // Full screen rather than an overlay on the tab content: a match that lets
    // the tab bar show through reads as a panel, not a moment.
    .fullScreenCover(item: $matched) { candidate in
      MatchRevealView(
        candidate: candidate,
        yourName: model.state.currentProfile.displayName,
        onDismiss: { matched = nil }
      )
    }
  }

  // MARK: - Chrome

  private var topBar: some View {
    HStack(spacing: 12) {
      EditorialLockup()

      Spacer()

      Button {
        isComposingReply = true
      } label: {
        Image(systemName: "square.and.pencil")
          .font(.system(size: 16))
          .foregroundStyle(WingmanEditorial.ink)
          .frame(width: 38, height: 38)
          .background(Circle().stroke(WingmanEditorial.hairline, lineWidth: 1))
      }
      .accessibilityLabel("Draft a reply")

      accountMenu
    }
  }

  /// Replaces the old sliders button, which only cleared the deck. The account
  /// is the thing a person actually needs to reach from here.
  private var accountMenu: some View {
    Menu {
      if let email = model.state.signedInEmail {
        Section(email) {
          Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
            model.signOut()
          }
        }
      } else {
        Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
          model.signOut()
        }
      }
    } label: {
      Image(systemName: "person.crop.circle")
        .font(.system(size: 17))
        .foregroundStyle(WingmanEditorial.ink)
        .frame(width: 38, height: 38)
        .background(Circle().stroke(WingmanEditorial.hairline, lineWidth: 1))
    }
    .accessibilityLabel("Account")
  }

  // MARK: - The deck

  /// Roster fillers first, real candidates last, so a demo swipe builds toward
  /// the account that can actually match instead of opening on it.
  ///
  /// The scripted match is pinned to the very end. `DemoAccounts.all` is
  /// `[eric, julian, evan]`, so Eric's counterparts came back as `[julian,
  /// evan]` and the reveal fired on the fourth of five cards, with a filler
  /// still to swipe after it. The payoff has to be the last thing in the deck,
  /// not something you trip over on the way there.
  private var deck: [SwipeCandidate] {
    let real = model.state.candidates.map { SwipeCandidate(profile: $0.publicSnapshot) }
    let ordered = real.filter { !isMatch($0) } + real.filter { isMatch($0) }
    return (DemoRoster.people + ordered).filter { !swiped.contains($0.id) }
  }

  private var current: SwipeCandidate? { deck.first }

  /// Only the top few are built — the ones behind are just edges peeking out.
  private var cardStack: some View {
    ZStack {
      ForEach(Array(deck.prefix(3).enumerated()).reversed(), id: \.element.id) { depth, candidate in
        SwipeProfileCard(
          candidate: candidate,
          recommender: recommender,
          translation: depth == 0 ? cardTranslation : .zero
        )
        .scaleEffect(1 - CGFloat(depth) * 0.035)
        .offset(y: CGFloat(depth) * 12)
        .zIndex(Double(3 - depth))
        .allowsHitTesting(depth == 0)
        .gesture(depth == 0 ? dragGesture : nil)
      }
    }
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: swiped)
    .animation(.spring(response: 0.25, dampingFraction: 0.85), value: cardTranslation)
  }

  /// How far the current drag has committed in each direction, 0…1. Drives the
  /// card's stamp and the rail's colour and scale from one number, so they
  /// cannot disagree.
  private var likeProgress: Double {
    min(1, max(0, Double(cardTranslation.width) / 110))
  }

  private var passProgress: Double {
    min(1, max(0, Double(-cardTranslation.width) / 110))
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { cardTranslation = $0.translation }
      .onEnded { value in
        let threshold: CGFloat = 100
        if value.translation.width > threshold {
          fling(toward: 1) { like() }
        } else if value.translation.width < -threshold {
          fling(toward: -1) { pass() }
        } else {
          withAnimation { cardTranslation = .zero }
        }
      }
  }

  /// The agent that put this deck together. Named on the card so a
  /// recommendation never reads as though it came from nowhere.
  ///
  /// Short form, not `AgentProvider.title` — that spells OpenAI's out as
  /// "ChatGPT / OpenAI", which is a mouthful set in a tracked rubric.
  private var recommender: String {
    switch model.state.connectedAgentProviders.first {
    case .openAI: return "ChatGPT"
    case .claude: return "Claude"
    case .gemini: return "Gemini"
    case nil: return "your agent"
    }
  }

  private var emptyDeck: some View {
    VStack(spacing: 12) {
      Spacer()

      Image(systemName: model.state.candidates.isEmpty ? "person.2" : "checkmark.seal")
        .font(.system(size: 30, weight: .light))
        .foregroundStyle(WingmanEditorial.accent)
        .padding(.bottom, 4)

      Text(model.state.candidates.isEmpty ? "No one to introduce yet" : "You’re all caught up")
        .font(WingmanEditorial.answer(21))
        .foregroundStyle(WingmanEditorial.ink)

      Text(
        model.state.candidates.isEmpty
          ? "When \(recommender) finds someone worth meeting, they’ll show up here."
          : "You’ve seen everyone \(recommender) recommended. Check Meet for the ones you liked."
      )
      .font(WingmanEditorial.body(14))
      .foregroundStyle(WingmanEditorial.inkSecondary)
      .multilineTextAlignment(.center)
      .frame(maxWidth: 290)

      Button {
        if model.state.candidates.isEmpty {
          model.seedDemoCandidate()
        } else {
          withAnimation { swiped.removeAll() }
        }
      } label: {
        Text(model.state.candidates.isEmpty ? "Add sample profile" : "Start over")
      }
      .buttonStyle(.editorialSecondary)
      .padding(.top, 8)

      Spacer()
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 20)
  }

  // MARK: - Actions

  /// One centred row, three equal circles, equal gaps. Mixing sizes here is
  /// what made the earlier rail look off-centre: the row was centred, but the
  /// heavier pair sat to one side of it, so the eye read the whole thing as
  /// shifted. Pass and like light up from the same drag progress that drives
  /// the card's stamp.
  private var actionRail: some View {
    HStack(spacing: 30) {
      SwipeActionButton(
        icon: "arrow.uturn.backward",
        tint: WingmanEditorial.inkSecondary,
        progress: 0,
        size: 64
      ) { rewind() }
        .disabled(swiped.isEmpty)
        .opacity(swiped.isEmpty ? 0.35 : 1)
        .accessibilityLabel("Undo last swipe")

      SwipeActionButton(
        icon: "xmark",
        tint: WingmanEditorial.ink,
        progress: passProgress,
        size: 64
      ) { fling(toward: -1) { pass() } }
        .accessibilityLabel("Pass")

      SwipeActionButton(
        icon: "heart.fill",
        tint: WingmanEditorial.brand,
        progress: likeProgress,
        size: 64
      ) { fling(toward: 1) { like() } }
        .accessibilityLabel("Like")
    }
    .frame(maxWidth: .infinity)
  }

  /// Throws the card off-screen, then commits — so the button rail and a real
  /// swipe end the same way instead of one snapping and the other sliding.
  private func fling(toward direction: CGFloat, then commit: @escaping () -> Void) {
    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
      cardTranslation = CGSize(width: direction * 520, height: cardTranslation.height)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
      commit()
      cardTranslation = .zero
    }
  }

  private func pass() {
    guard let current else { return }
    swiped.append(current.id)
  }

  /// A like selects the person, and asks the wingpeople for their read when
  /// both profiles are complete enough to have one. The readiness check is here
  /// rather than left to `compareSelectedProfiles`, whose failure path sets
  /// `lastError` — which would put an alert on screen for every swipe.
  private func like() {
    guard let current else { return }

    if current.isRealCandidate {
      model.selectedCandidateID = current.id
      if let profile = model.state.candidates.first(where: { $0.id == current.id }),
        model.profileReady, profile.isReadyForIntroductions {
        model.compareSelectedProfiles()
      }
    }

    swiped.append(current.id)

    if isMatch(current) { reveal(current) }
  }

  /// Presents the match with the cover's own slide suppressed. `MatchRevealView`
  /// runs its own entrance, and a panel sliding up from the bottom first both
  /// wastes the first third of a second and frames the moment as a sheet.
  private func reveal(_ candidate: SwipeCandidate) {
    var instant = Transaction()
    instant.disablesAnimations = true
    withTransaction(instant) { matched = candidate }
  }

  /// The demo's one scripted match: Eric liking Julian. Both sides of that pair
  /// are real accounts in `DemoAccounts`, so the reveal is claiming something
  /// the app can actually back — unlike a roster filler, where a match screen
  /// would be theatre with nobody behind it.
  private func isMatch(_ candidate: SwipeCandidate) -> Bool {
    model.state.signedInEmail?.lowercased() == DemoAccounts.eric.email
      && candidate.id == DemoAccounts.julian.profile.id
  }

  private func rewind() {
    guard !swiped.isEmpty else { return }
    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
      swiped.removeLast()
    }
  }
}

// MARK: - Reply composer

/// The reply deck, moved off the landing screen and into a sheet when Home
/// became the people deck. Same composer and same swipeable drafts as before —
/// reachable from the pencil in the top bar.
private struct ReplyComposerSheet: View {
  @Bindable var model: AppModel
  @Environment(\.dismiss) private var dismiss

  @State private var activeCardIndex = 0
  @State private var cardTranslation: CGSize = .zero

  var body: some View {
    NavigationStack {
      ScrollView(showsIndicators: false) {
        VStack(spacing: 22) {
          EditorialHeader(
            rubric: "Your reply deck",
            title: "Find the one that sounds like you."
          )

          promptCard

          if model.replySuggestions.isEmpty {
            emptyDeck
          } else {
            replyDeck
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 32)
      }
      .editorialPage()
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
            .foregroundStyle(WingmanEditorial.ink)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .onChange(of: model.replySuggestions.count) { _, _ in
        activeCardIndex = 0
        cardTranslation = .zero
      }
    }
  }

  private var promptCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        EditorialRubric("Message to reply to")

        Spacer()

        relationshipMenu
      }

      WingmanTextEditor(
        "Paste the message here",
        text: $model.replyRequest.incomingMessage,
        lineLimit: 3...6
      )

      HStack(spacing: 10) {
        Image(systemName: "sparkles")
          .font(.system(size: 14))
          .foregroundStyle(WingmanEditorial.accent)

        WingmanTextField("What should it feel like?", text: $model.replyRequest.goal)
      }

      if !model.replyRequest.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        WingmanTextField("Extra context", text: $model.replyRequest.context)
      }

      Button(action: model.generateReplies) {
        HStack(spacing: 8) {
          if model.isGeneratingReplies {
            ProgressView().tint(WingmanEditorial.card)
            Text("Building your deck")
          } else {
            Text("Build my reply deck")
          }
        }
      }
      .buttonStyle(EditorialPrimaryButtonStyle(enabled: hasMessageToReplyTo))
      .disabled(model.isGeneratingReplies || !hasMessageToReplyTo)
      .padding(.top, 6)
    }
    .editorialCard()
  }

  private var hasMessageToReplyTo: Bool {
    !model.replyRequest.incomingMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var relationshipMenu: some View {
    Menu {
      ForEach(RelationshipKind.allCases) { kind in
        Button {
          model.replyRequest.relationship = kind
        } label: {
          Label(
            kind.title,
            systemImage: kind == model.replyRequest.relationship ? "checkmark" : "person"
          )
        }
      }
    } label: {
      HStack(spacing: 5) {
        Text(model.replyRequest.relationship.title)
        Image(systemName: "chevron.down")
          .font(.system(size: 9, weight: .semibold))
      }
      .font(.system(size: 13, weight: .medium))
      .foregroundStyle(WingmanEditorial.ink)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .overlay(Capsule().stroke(WingmanEditorial.hairline, lineWidth: 1))
    }
    .accessibilityLabel("Relationship: \(model.replyRequest.relationship.title)")
  }

  private var emptyDeck: some View {
    VStack(spacing: 10) {
      Image(systemName: "square.stack.3d.up")
        .font(.system(size: 26, weight: .light))
        .foregroundStyle(WingmanEditorial.accent)
        .padding(.bottom, 4)

      Text("Your deck is waiting")
        .font(WingmanEditorial.answer(20))
        .foregroundStyle(WingmanEditorial.ink)

      Text("Add a message above and we’ll give you a few ways to say it.")
        .font(WingmanEditorial.body(14))
        .foregroundStyle(WingmanEditorial.inkSecondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 280)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 34)
  }

  private var replyDeck: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .firstTextBaseline) {
        EditorialRubric(hasCardsLeft ? "Pick your vibe" : "Deck complete")

        Spacer()

        Text(
          hasCardsLeft
            ? "\(model.replySuggestions.count - activeCardIndex) left"
            : "\(model.replySuggestions.count) drafts"
        )
        .font(WingmanEditorial.body(12, .medium))
        .foregroundStyle(WingmanEditorial.inkSecondary)
      }

      if hasCardsLeft {
        ZStack {
          ForEach(Array(model.replySuggestions.enumerated().reversed()), id: \.element.id) { index, suggestion in
            swipeCard(suggestion, at: index)
          }
        }
        .frame(height: 320)

        actionRail
      } else {
        deckComplete
      }
    }
  }

  private var hasCardsLeft: Bool { activeCardIndex < model.replySuggestions.count }

  private var deckComplete: some View {
    VStack(spacing: 14) {
      Image(systemName: "checkmark.seal")
        .font(.system(size: 28, weight: .light))
        .foregroundStyle(WingmanEditorial.accent)

      Text("You’ve seen every version")
        .font(WingmanEditorial.answer(19))
        .foregroundStyle(WingmanEditorial.ink)

      Button("Run the deck again") {
        activeCardIndex = 0
      }
      .buttonStyle(.editorialSecondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 30)
    .editorialCard(padding: 0)
  }

  private func swipeCard(_ suggestion: ReplySuggestion, at index: Int) -> some View {
    let isCurrent = index == activeCardIndex
    let depth = max(0, index - activeCardIndex)

    return VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 7) {
        Image(systemName: toneIcon(for: suggestion.tone))
          .font(.system(size: 12))
          .foregroundStyle(WingmanEditorial.accent)

        EditorialRubric(suggestion.tone.title, tint: WingmanEditorial.accent)

        Spacer()
      }

      Text(suggestion.text)
        .font(WingmanEditorial.answer(23))
        .foregroundStyle(WingmanEditorial.ink)
        .lineSpacing(5)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
        .padding(.top, 16)

      Spacer(minLength: 18)

      EditorialDivider()

      Text(suggestion.rationale)
        .font(WingmanEditorial.body(13))
        .foregroundStyle(WingmanEditorial.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 12)
    }
    .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
    .editorialCard(padding: 22)
    .scaleEffect(isCurrent ? 1 : 1 - CGFloat(depth) * 0.04)
    .offset(
      x: isCurrent ? cardTranslation.width : 0,
      y: isCurrent ? cardTranslation.height : CGFloat(depth * 10)
    )
    .rotationEffect(.degrees(isCurrent ? Double(cardTranslation.width / 20) : 0))
    .opacity(index < activeCardIndex ? 0 : 1)
    .zIndex(Double(model.replySuggestions.count - index))
    .gesture(
      DragGesture()
        .onChanged { value in
          if isCurrent { cardTranslation = value.translation }
        }
        .onEnded { value in
          if isCurrent { finishSwipe(value.translation.width) }
        }
    )
    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: activeCardIndex)
    .animation(.spring(response: 0.25, dampingFraction: 0.82), value: cardTranslation)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(suggestion.tone.title) reply: \(suggestion.text)")
  }

  private var actionRail: some View {
    HStack(spacing: 20) {
      Button {
        activeCardIndex = 0
        cardTranslation = .zero
      } label: {
        Image(systemName: "arrow.uturn.backward")
      }
      .buttonStyle(.editorialCircle(size: 44))
      .accessibilityLabel("Start over")

      Button { advanceCard() } label: {
        Image(systemName: "xmark")
      }
      .buttonStyle(.editorialCircle(size: 52))
      .accessibilityLabel("Skip reply")

      Button { copyCurrentReply() } label: {
        Image(systemName: "doc.on.doc")
      }
      .buttonStyle(.editorialCircle(size: 62, filled: true))
      .accessibilityLabel("Copy reply")

      Button { copyCurrentReply() } label: {
        Image(systemName: "heart")
      }
      .buttonStyle(.editorialCircle(size: 52, tint: WingmanEditorial.accent))
      .accessibilityLabel("Choose reply")
    }
    .frame(maxWidth: .infinity)
  }

  private func finishSwipe(_ horizontalDistance: CGFloat) {
    let threshold: CGFloat = 90
    if abs(horizontalDistance) > threshold {
      withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
        cardTranslation = CGSize(
          width: horizontalDistance > 0 ? 460 : -460,
          height: cardTranslation.height
        )
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
        advanceCard()
      }
    } else {
      withAnimation { cardTranslation = .zero }
    }
  }

  private func advanceCard() {
    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
      activeCardIndex = min(activeCardIndex + 1, model.replySuggestions.count)
      cardTranslation = .zero
    }
  }

  private func copyCurrentReply() {
    guard activeCardIndex < model.replySuggestions.count else { return }
    UIPasteboard.general.string = model.replySuggestions[activeCardIndex].text
  }

  private func toneIcon(for tone: ReplySuggestion.Tone) -> String {
    switch tone {
    case .warm: return "heart"
    case .direct: return "arrow.right"
    case .light: return "sun.max"
    }
  }
}
