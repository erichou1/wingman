import Messages
import SwiftUI
import WingmanCore

struct MessagesRootView: View {
  @Bindable var model: MessagesExtensionModel
  let requestExpanded: () -> Void
  let insertText: (String) -> Void
  let insertCard: () -> Void

  var body: some View {
    Group {
      if model.presentationStyle == .compact {
        compactView
          // Apple gives compact ~110pt total. A blanket `.padding()` (16pt
          // every side) was eating ~29% of that before any content
          // rendered — this is sized to the actual budget instead.
          .padding(.horizontal, WingmanMetrics.Spacing.sm + 2)
          .padding(.vertical, WingmanMetrics.Spacing.sm)
      } else {
        expandedView
          .padding(.horizontal, WingmanMetrics.Spacing.md)
          .padding(.top, WingmanMetrics.Spacing.xs)
          .padding(.bottom, WingmanMetrics.Spacing.md)
      }
    }
    .background(WingmanPalette.surface)
    .alert(
      "Wingman needs attention",
      isPresented: Binding(
        get: { model.lastError != nil },
        set: { if !$0 { model.lastError = nil } }
      )
    ) {
      Button("OK") { model.lastError = nil }
    } message: {
      Text(model.lastError ?? "Unknown error")
    }
  }

  private var compactView: some View {
    VStack(spacing: WingmanMetrics.Spacing.xs + 2) {
      HStack {
        Text("Wingman")
          .font(WingmanType.headline(.heavy))
          .foregroundStyle(WingmanPalette.ink)
        Spacer()
        Text("you tap send")
          .font(WingmanType.caption())
          .foregroundStyle(WingmanPalette.inkSecondary)
      }
      HStack(spacing: WingmanMetrics.Spacing.xs + 2) {
        compactButton("Help me reply", icon: "bubble.left.fill", mode: .reply)
        compactButton("Meet My Human", icon: "person.2.fill", mode: .meet)
      }
    }
  }

  private func compactButton(_ title: String, icon: String, mode: MessagesExtensionModel.Mode) -> some View {
    Button {
      model.mode = mode
      requestExpanded()
    } label: {
      VStack(spacing: 4) {
        Image(systemName: icon).font(.system(size: 15, weight: .semibold))
        Text(title).font(WingmanType.caption(.bold))
      }
      // Fills the row via the HStack's equal-width layout, not fixed
      // per-button padding — the bug was 24pt of horizontal padding on
      // each of two buttons inside an already-narrow bar.
      .frame(maxWidth: .infinity, minHeight: 44)
      .padding(.horizontal, WingmanMetrics.Spacing.xs)
    }
    .buttonStyle(.wingmanSecondary)
    .foregroundStyle(WingmanPalette.ink)
  }

  private var expandedView: some View {
    VStack(spacing: WingmanMetrics.Spacing.sm) {
      Picker("Mode", selection: $model.mode) {
        ForEach(MessagesExtensionModel.Mode.allCases) { mode in
          Text(mode.title).tag(mode)
        }
      }
      .pickerStyle(.segmented)

      ScrollView {
        switch model.mode {
        case .reply:
          replyView
        case .meet:
          meetView
        }
      }
    }
  }

  private var replyView: some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.md) {
      ReplyComposer(
        request: $model.replyRequest,
        note: "iMessage does not give extensions transcript access. Wingman only uses what you choose to paste.",
        isLoading: model.isGeneratingReplies,
        onGenerate: model.generateReplies
      )

      if model.replySuggestions.isEmpty {
        WingmanEmptyState(
          icon: "sparkles",
          title: "Drafts appear here",
          message: "Paste the message above to get three editable replies."
        )
      } else {
        VStack(spacing: WingmanMetrics.Spacing.sm) {
          ForEach(model.replySuggestions) { suggestion in
            ReplySuggestionCard(suggestion: suggestion) {
              Button("Insert") { insertText(suggestion.text) }
                .font(WingmanType.caption(.bold))
                .foregroundStyle(WingmanPalette.canvas)
                .padding(.horizontal, WingmanMetrics.Spacing.sm)
                .padding(.vertical, 6)
                .background(WingmanPalette.ink, in: Capsule())
            }
          }
        }
      }
    }
  }

  private var meetView: some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.md) {
      if let card = model.receivedCard {
        receivedIntroduction(card)
      } else if let insight = model.latestInsight {
        Text("What the wingpeople noticed")
          .font(WingmanType.title())
          .foregroundStyle(WingmanPalette.ink)
        messageSection("Possible resonance", text: insight.resonance.first ?? "")
        messageSection("Worth discussing", text: insight.friction.first ?? "")
        messageSection("A place to begin", text: insight.conversationStarters.first ?? "")

        Label(
          model.introductionReady ? "Both humans approved" : "Waiting for both humans",
          systemImage: model.introductionReady ? "checkmark.shield.fill" : "hourglass"
        )
        .font(WingmanType.subheadline(.semibold))
        .foregroundStyle(model.introductionReady ? WingmanPalette.success : WingmanPalette.inkSecondary)

        Button(action: insertCard) {
          Label("Insert introduction card", systemImage: "message.fill")
        }
        .buttonStyle(.wingmanPrimary)
        .disabled(!model.introductionReady)
      } else {
        WingmanEmptyState(
          icon: "person.2.slash",
          title: "No introduction ready",
          message: "Create approved profiles and an introduction in the Wingman app first."
        )
      }
    }
  }

  private func receivedIntroduction(_ card: IntroductionCard) -> some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.sm) {
      Text("Meet My Human")
        .font(WingmanType.title())
        .foregroundStyle(WingmanPalette.ink)
      Text("\(card.firstName) × \(card.secondName)")
        .font(WingmanType.title())
        .foregroundStyle(WingmanPalette.ink)
      Text(card.relationshipLabel)
        .font(WingmanType.subheadline())
        .foregroundStyle(WingmanPalette.inkSecondary)
      messageSection("Possible resonance", text: card.resonance)
      messageSection("Worth discussing", text: card.friction)
      messageSection("Start here", text: card.conversationStarter)
    }
  }

  private func messageSection(_ title: String, text: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(WingmanType.headline())
        .foregroundStyle(WingmanPalette.ink)
      Text(text)
        .font(WingmanType.subheadline())
        .foregroundStyle(WingmanPalette.inkSecondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .wingmanCard(radius: WingmanMetrics.Radius.sm)
  }
}
