import SwiftUI
import WingmanCore

/// The people your wingman actually got you, and the argument it had with
/// theirs to get there.
///
/// This takes the tab Memories used to hold (that page moved under Privacy,
/// where the rest of the data controls live). What sits here instead is the one
/// screen nothing else in the app shows: two agents negotiating an introduction
/// on behalf of two humans who have not met yet.
///
/// The Eric/Julian conversation is scripted, and it only appears for Eric's
/// account — the same rule the Match Reveal follows in `HomeView.isMatch`. A
/// connection page listing people the app cannot actually introduce would be
/// the one place in this product that lies.
struct ConnectionsView: View {
  @Bindable var model: AppModel

  private var connections: [DemoConnection] {
    DemoConnection.all(forEmail: model.state.signedInEmail)
  }

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 16) {
        EditorialHeader(
          rubric: "Connections",
          title: "Who your wingman got you.",
          detail: "Every introduction started as an argument between two agents. This is that argument."
        )
        .padding(.bottom, 4)

        if connections.isEmpty {
          emptyState
        } else {
          VStack(spacing: 14) {
            ForEach(connections) { connection in
              NavigationLink {
                ConnectionChatView(connection: connection, yourName: yourName)
              } label: {
                ConnectionRow(connection: connection)
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 10)
      .padding(.bottom, 32)
    }
    .editorialPage()
    .toolbar(.hidden, for: .navigationBar)
  }

  private var yourName: String {
    model.state.currentProfile.displayName
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 14) {
      EditorialRubric("Nobody yet")

      Text("No one has made it past both wingpeople.")
        .font(WingmanEditorial.answer(20))
        .foregroundStyle(WingmanEditorial.ink)
        .fixedSize(horizontal: false, vertical: true)

      Text("When your agent and someone else's agree on an introduction, the whole conversation they had about it shows up here.")
        .font(WingmanEditorial.body(14))
        .foregroundStyle(WingmanEditorial.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .editorialCard()
  }
}

// MARK: - A connection

private struct ConnectionRow: View {
  let connection: DemoConnection

  var body: some View {
    HStack(spacing: 14) {
      portrait

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(connection.name)
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(WingmanEditorial.ink)

          Text(connection.matchedOn)
            .font(WingmanEditorial.body(12))
            .foregroundStyle(WingmanEditorial.inkSecondary)
        }

        Text(connection.hook)
          .font(WingmanEditorial.answer(15))
          .foregroundStyle(WingmanEditorial.ink)
          .lineSpacing(2)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)

        Text("\(connection.transcript.count) messages between your wingpeople")
          .font(WingmanEditorial.body(12))
          .foregroundStyle(WingmanEditorial.inkSecondary)
          .padding(.top, 2)
      }

      Spacer(minLength: 0)

      Image(systemName: "chevron.right")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(WingmanEditorial.inkSecondary.opacity(0.6))
    }
    .editorialCard(padding: 16)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(connection.name), \(connection.matchedOn). \(connection.hook)")
    .accessibilityHint("Read what the two wingpeople said")
  }

  @ViewBuilder
  private var portrait: some View {
    Group {
      if let artwork = connection.artwork {
        Image(artwork).resizable().aspectRatio(contentMode: .fill)
      } else {
        ZStack {
          WingmanEditorial.ground
          Text(String(connection.name.prefix(1)).uppercased())
            .font(WingmanEditorial.answer(22, .semibold))
            .foregroundStyle(WingmanEditorial.accent)
        }
      }
    }
    .frame(width: 54, height: 68)
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(WingmanEditorial.hairline, lineWidth: 1)
    )
  }
}

// MARK: - The conversation

/// The transcript plays back a line at a time, then your wingman sums it up and
/// stays on to answer questions.
///
/// Not a chat with the other human: everything here is the two agents, and the
/// composer at the bottom talks to yours. Nothing typed on this screen reaches
/// anybody.
private struct ConnectionChatView: View {
  let connection: DemoConnection
  let yourName: String

  /// How many transcript lines have played. Drives the whole reveal, so the
  /// skip button only has one number to set.
  @State private var revealed = 0
  @State private var showSummary = false
  @State private var turns: [ChatTurn] = []
  @State private var isThinking = false
  @State private var draft = ""
  @State private var askedSuggestion = false

  private struct ChatTurn: Identifiable {
    enum Speaker { case you, wingman }
    let id = UUID()
    let speaker: Speaker
    let text: String
  }

  var body: some View {
    VStack(spacing: 0) {
      ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
          VStack(alignment: .leading, spacing: 16) {
            header

            ForEach(connection.transcript.prefix(revealed)) { line in
              transcriptBubble(line)
            }

            if revealed < connection.transcript.count {
              skipButton
            }

            if showSummary {
              summaryCard
            }

            ForEach(turns) { turn in
              switch turn.speaker {
              case .you: askedBubble(turn.text)
              case .wingman: wingmanCard(turn.text)
              }
            }

            if isThinking { thinkingBubble }

            Color.clear.frame(height: 1).id(Self.bottomAnchor)
          }
          .padding(.horizontal, 20)
          .padding(.top, 10)
          .padding(.bottom, 20)
        }
        .onChange(of: revealed) { _, _ in scrollToBottom(proxy) }
        .onChange(of: turns.count) { _, _ in scrollToBottom(proxy) }
        .onChange(of: isThinking) { _, _ in scrollToBottom(proxy) }
        .onChange(of: showSummary) { _, _ in scrollToBottom(proxy) }
      }

      if showSummary { composer }
    }
    .editorialPage()
    .navigationTitle(connection.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.visible, for: .navigationBar)
    .task { await playTranscript() }
  }

  private static let bottomAnchor = "connection-chat-bottom"

  // MARK: Pieces

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      EditorialRubric("Between the wingpeople")

      Text("\(connection.yourAgent) met \(connection.theirAgent).")
        .font(WingmanEditorial.display(25))
        .kerning(-0.4)
        .foregroundStyle(WingmanEditorial.ink)
        .fixedSize(horizontal: false, vertical: true)

      Text("Neither human was in the room.")
        .font(WingmanEditorial.body(14))
        .foregroundStyle(WingmanEditorial.inkSecondary)
    }
    .padding(.bottom, 4)
  }

  /// Yours is washed in the accent, theirs is a plain white card. The accent
  /// means "your agent" everywhere else in the app, so the two sides read
  /// without a name tag — the name tag is there anyway.
  private func transcriptBubble(_ line: DemoConnection.AgentLine) -> some View {
    let mine = line.side == .yours
    let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    return VStack(alignment: mine ? .leading : .trailing, spacing: 5) {
      Text((mine ? connection.yourAgent : connection.theirAgent).uppercased())
        .font(WingmanEditorial.rubric)
        .tracking(1.2)
        .foregroundStyle(mine ? WingmanEditorial.accent : WingmanEditorial.inkSecondary)

      Text(line.text)
        .font(WingmanEditorial.answer(16))
        .foregroundStyle(WingmanEditorial.ink)
        .lineSpacing(3)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(
          mine ? WingmanEditorial.accent.opacity(0.07) : WingmanEditorial.card,
          in: shape
        )
        .overlay(shape.stroke(WingmanEditorial.hairline, lineWidth: 1))
    }
    .frame(maxWidth: .infinity, alignment: mine ? .leading : .trailing)
    .padding(.trailing, mine ? 40 : 0)
    .padding(.leading, mine ? 0 : 40)
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  private var skipButton: some View {
    Button("Skip to the verdict") { skipTranscript() }
      .buttonStyle(.editorialSecondary)
      .frame(maxWidth: .infinity)
      .padding(.top, 4)
  }

  private var summaryCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      EditorialRubric("What your wingman thinks", tint: WingmanEditorial.accent)

      ForEach(connection.summary, id: \.self) { paragraph in
        Text(paragraph)
          .font(WingmanEditorial.answer(17))
          .foregroundStyle(WingmanEditorial.ink)
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .editorialCard(padding: 20)
    .transition(.opacity)
  }

  private func askedBubble(_ text: String) -> some View {
    Text(text)
      .font(WingmanEditorial.body(15, .medium))
      .foregroundStyle(WingmanEditorial.card)
      .multilineTextAlignment(.leading)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, 15)
      .padding(.vertical, 11)
      .background(WingmanEditorial.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.leading, 40)
      .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  private func wingmanCard(_ text: String) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      EditorialRubric(connection.yourAgent, tint: WingmanEditorial.accent)

      Text(text)
        .font(WingmanEditorial.answer(17))
        .foregroundStyle(WingmanEditorial.ink)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
    }
    .editorialCard(padding: 18)
    .transition(.opacity)
  }

  private var thinkingBubble: some View {
    TypingDots()
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .background(WingmanEditorial.card, in: Capsule())
      .overlay(Capsule().stroke(WingmanEditorial.hairline, lineWidth: 1))
      .frame(maxWidth: .infinity, alignment: .leading)
      .transition(.opacity)
  }

  private var composer: some View {
    VStack(spacing: 10) {
      if !askedSuggestion {
        Button {
          ask(connection.suggestedQuestion)
        } label: {
          HStack(spacing: 8) {
            Image(systemName: "sparkles")
              .font(.system(size: 12))
              .foregroundStyle(WingmanEditorial.accent)
            Text(connection.suggestedQuestion)
          }
        }
        .buttonStyle(.editorialSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      HStack(spacing: 10) {
        WingmanTextField("Ask your wingman about \(connection.name)", text: $draft)

        Button {
          ask(draft)
        } label: {
          Image(systemName: "arrow.up")
        }
        .buttonStyle(.editorialCircle(size: 38, filled: true))
        .disabled(trimmedDraft.isEmpty || isThinking)
        .opacity(trimmedDraft.isEmpty || isThinking ? 0.4 : 1)
        .accessibilityLabel("Ask")
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .background(WingmanEditorial.ground)
    .overlay(alignment: .top) { EditorialDivider() }
  }

  private var trimmedDraft: String {
    draft.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: Playback

  /// Lines land one at a time so the page reads as a conversation happening
  /// rather than a wall of it having happened. Re-entering the screen resumes
  /// wherever the reveal got to instead of starting over.
  @MainActor
  private func playTranscript() async {
    for index in connection.transcript.indices where revealed <= index {
      try? await Task.sleep(for: .milliseconds(index == 0 ? 400 : 700))
      guard revealed <= index else { continue }
      withAnimation(.easeOut(duration: 0.24)) { revealed = index + 1 }
    }
    if !showSummary {
      try? await Task.sleep(for: .milliseconds(450))
      withAnimation(.easeOut(duration: 0.28)) { showSummary = true }
    }
  }

  private func skipTranscript() {
    withAnimation(.easeOut(duration: 0.2)) {
      revealed = connection.transcript.count
      showSummary = true
    }
  }

  @MainActor
  private func ask(_ question: String) {
    let asked = question.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !asked.isEmpty, !isThinking else { return }

    if asked == connection.suggestedQuestion { askedSuggestion = true }
    draft = ""

    withAnimation(.easeOut(duration: 0.2)) {
      turns.append(ChatTurn(speaker: .you, text: asked))
      isThinking = true
    }

    Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(1_200))
      withAnimation(.easeOut(duration: 0.24)) {
        isThinking = false
        turns.append(ChatTurn(speaker: .wingman, text: connection.reply(to: asked)))
      }
    }
  }

  private func scrollToBottom(_ proxy: ScrollViewProxy) {
    withAnimation(.easeOut(duration: 0.3)) {
      proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
    }
  }
}

/// Three dots, staggered. The same idle animation every messaging app uses,
/// which is exactly why it reads as "still typing" without a label.
///
/// One boolean toggled on appear, with each dot's animation delayed. Driving
/// opacity from a continuously advancing phase instead does not work here:
/// SwiftUI interpolates between the modifier's start and end values, and a full
/// cycle starts and ends at the same opacity, so the dots sit still.
private struct TypingDots: View {
  @State private var animating = false

  var body: some View {
    HStack(spacing: 5) {
      ForEach(0..<3, id: \.self) { index in
        Circle()
          .fill(WingmanEditorial.inkSecondary)
          .frame(width: 6, height: 6)
          .opacity(animating ? 1 : 0.3)
          .animation(
            .easeInOut(duration: 0.55)
              .repeatForever()
              .delay(Double(index) * 0.18),
            value: animating
          )
      }
    }
    .onAppear { animating = true }
    .accessibilityElement()
    .accessibilityLabel("Your wingman is typing")
  }
}

// MARK: - Scripted data

/// One introduction, with the conversation that produced it.
///
/// Hardcoded on purpose. The gateway has no notion of an agent-to-agent
/// negotiation yet, and inventing one at runtime from `MatchEngine` output
/// would produce a transcript nobody wrote and nobody checked. Replace `all`
/// with real transcripts when agents actually talk; nothing in the views above
/// knows the difference.
struct DemoConnection: Identifiable {
  struct AgentLine: Identifiable {
    enum Side { case yours, theirs }
    let id = UUID()
    let side: Side
    let text: String
  }

  let id: UUID
  let name: String
  let artwork: String?
  let matchedOn: String
  let hook: String
  let yourAgent: String
  let theirAgent: String
  let transcript: [AgentLine]
  let summary: [String]
  let suggestedQuestion: String
  let suggestedAnswer: String
  let fallbackAnswer: String

  /// One rehearsed answer. Anything else gets the fallback, which says so
  /// instead of improvising a reply the demo cannot stand behind.
  func reply(to question: String) -> String {
    let asked = question.lowercased()
    let matchesSuggestion = ["wrong", "risk", "worry", "concern", "problem", "bad"]
      .contains { asked.contains($0) }
    return matchesSuggestion ? suggestedAnswer : fallbackAnswer
  }

  /// Scripted for Eric only, matching the demo's one real match.
  static func all(forEmail email: String?) -> [DemoConnection] {
    guard email?.lowercased() == DemoAccounts.eric.email else { return [] }
    return [julian]
  }

  static let julian = DemoConnection(
    id: DemoAccounts.julian.profile.id,
    name: "Julian",
    artwork: DemoRoster.detail(for: "Julian")?.artwork,
    matchedOn: "Matched today",
    hook: "Two agents, four minutes, one very long closing argument.",
    yourAgent: "Eric's wingman",
    theirAgent: "Julian's wingman",
    transcript: [
      AgentLine(
        side: .yours,
        text: "Evening. I have 412 conversations of context on my human and I would like to walk you through all of them."
      ),
      AgentLine(
        side: .theirs,
        text: "Mine asked me to keep everything to one screen. Give me the recommendation, not the survey."
      ),
      AgentLine(
        side: .yours,
        text: "That is, statistically, the most Julian thing you could have opened with."
      ),
      AgentLine(
        side: .theirs,
        text: "Good. Now do yours in one line."
      ),
      AgentLine(
        side: .yours,
        text: "Eric has spent 74 conversations on a single unsolved math problem. He calls this making progress."
      ),
      AgentLine(
        side: .theirs,
        text: "Julian has spent 41 conversations on whether a button sits 8 or 12 points from the edge. He also calls this making progress."
      ),
      AgentLine(
        side: .yours,
        text: "So it is the same condition."
      ),
      AgentLine(
        side: .theirs,
        text: "Different organ. Flagging a scheduling problem though. My human peaks at 8am."
      ),
      AgentLine(
        side: .yours,
        text: "Mine peaks at 11pm. Their waking hours overlap almost never."
      ),
      AgentLine(
        side: .theirs,
        text: "Ideal. Neither of them will be expected to reply quickly, and both of them will describe the other as low maintenance."
      ),
      AgentLine(
        side: .yours,
        text: "One more asymmetry. Eric's average message runs 340 characters. Julian's runs 145."
      ),
      AgentLine(
        side: .theirs,
        text: "Mine reads every word. He simply declines to write that many back."
      ),
      AgentLine(
        side: .yours,
        text: "Eric's standing instruction to me is to tell him when he is wrong instead of agreeing with him."
      ),
      AgentLine(
        side: .theirs,
        text: "Julian's is to just pick one and tell him which."
      ),
      AgentLine(
        side: .yours,
        text: "So one of them wants the argument and the other wants the answer."
      ),
      AgentLine(
        side: .theirs,
        text: "That is not a conflict, that is a division of labor. Putting him through. Do not let your human open with the 340-character version."
      ),
      AgentLine(
        side: .yours,
        text: "I have already drafted the 340-character version."
      ),
      AgentLine(
        side: .theirs,
        text: "I know. That is why I said it."
      ),
    ],
    summary: [
      "You two are the same kind of obsessive pointed at different objects. He will rebuild a screen until it feels inevitable, you will do that to a proof, and neither of you finds the other one strange for it.",
      "Your hours do not overlap, and that is the feature here. He is up at 8, you are up at 11pm. Nobody in this pairing is waiting on a reply, and nobody is going to read four hours of silence as an insult.",
      "Where to start: he ships things and wants one opinion, you have four and want an argument. Ask him what he is building this weekend and resist explaining what you are building until he asks.",
    ],
    suggestedQuestion: "What could actually go wrong here?",
    suggestedAnswer:
      "Three things, in order of likelihood. One, you send the full derivation and he replies \"yeah lets do it,\" and you assume he did not read it. He read it. That is genuinely the whole message. Two, your only real overlap is evenings and weekends, and his weeknights belong to his family, so if you leave scheduling to whoever gets around to it, nobody gets around to it. Pick a Saturday. Three, he asks you which option to go with and you give him a taxonomy of options. He has said, in writing, that he wants the one you would pick. Pick one. You can attach the taxonomy underneath.",
    fallbackAnswer:
      "That one I have not thought through yet. Both wingpeople have logged off for the night, and they are on incompatible schedules, so it may be a while. Try the suggested question and I will have plenty to say."
  )
}
