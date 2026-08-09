import SwiftUI
import WingmanCore

struct MeetView: View {
  @Bindable var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.lg) {
        VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.xs) {
          Text("Meet My Human")
            .font(.system(size: 30, weight: .heavy))
            .foregroundStyle(WingmanPalette.meshInk)
          Text("No swiping. No compatibility score. What may resonate, and what deserves an honest conversation.")
            .font(WingmanType.subheadline())
            .foregroundStyle(WingmanPalette.meshInkSecondary)
        }
        .padding(.top, WingmanMetrics.Spacing.sm)

        if !model.profileReady {
          CalloutCard(
            icon: "person.crop.circle.badge.exclamationmark",
            title: "Finish your approved profile",
            detail: "Approve your name, connection types, and at least one value or interest before an introduction."
          )
        }

        if model.state.candidates.isEmpty {
          VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.sm) {
            Button {
              model.seedDemoCandidate()
            } label: {
              Label("Add sample profile (demo)", systemImage: "person.badge.plus")
            }
            .buttonStyle(.wingmanPrimary)
            Text("This is a local prototype profile for trying the flow — Wingman has no real invite or matching backend yet.")
              .font(WingmanType.caption())
              .foregroundStyle(WingmanPalette.inkSecondary)
          }
        } else {
          VStack(spacing: WingmanMetrics.Spacing.sm) {
            ForEach(model.state.candidates) { candidate in
              CandidateCard(
                candidate: candidate,
                selected: model.selectedCandidate?.id == candidate.id
              ) {
                model.selectedCandidateID = candidate.id
              }
            }
          }

          Button {
            model.compareSelectedProfiles()
          } label: {
            Label("Ask our wingpeople", systemImage: "person.2.fill")
          }
          .buttonStyle(.wingmanPrimary)
          .disabled(!model.profileReady)
        }

        if let insight = model.selectedInsight {
          InsightCard(insight: insight)
          ConsentCard(model: model, insight: insight)
        }
      }
      .padding()
    }
    .background(WingmanMeshBackground().ignoresSafeArea())
    // These screens are a committed light surface (mesh gradient + fixed
    // mesh ink colors) — force light mode for everything in the subtree so
    // shared components (wingmanCard, ReplySuggestionCard, etc.) resolve
    // their adaptive colors to light too, instead of going dark-card-on-
    // light-mesh inconsistent when the system is in Dark Mode.
    .preferredColorScheme(.light)
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct CandidateCard: View {
  let candidate: HumanProfile
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: WingmanMetrics.Spacing.md) {
        Image(systemName: "person.crop.circle.fill")
          .font(.system(size: 44))
          .foregroundStyle(WingmanPalette.accent)
        VStack(alignment: .leading, spacing: 4) {
          Text(candidate.publicSnapshot.displayName)
            .font(WingmanType.headline())
            .foregroundStyle(WingmanPalette.ink)
          Text(candidate.publicSnapshot.lookingFor.map(\.title).sorted().joined(separator: " · "))
            .font(WingmanType.caption())
            .foregroundStyle(WingmanPalette.inkSecondary)
        }
        Spacer()
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(selected ? WingmanPalette.accent : WingmanPalette.inkSecondary)
      }
      .wingmanCard(emphasis: selected ? .accent : .standard)
    }
    .buttonStyle(.plain)
  }
}

private struct InsightCard: View {
  let insight: MatchInsight

  var body: some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.md) {
      Text("What the wingpeople noticed")
        .font(WingmanType.title())
        .foregroundStyle(WingmanPalette.ink)

      InsightSection(title: "Possible resonance", color: WingmanPalette.ink, items: insight.resonance)
      InsightSection(title: "Worth discussing", color: WingmanPalette.warning, items: insight.friction)
      InsightSection(title: "A place to begin", color: WingmanPalette.success, items: insight.conversationStarters)
    }
    .wingmanCard(radius: WingmanMetrics.Radius.lg)
  }
}

private struct InsightSection: View {
  let title: String
  let color: Color
  let items: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.xs) {
      Text(title)
        .font(WingmanType.headline())
        .foregroundStyle(color)
      ForEach(items, id: \.self) { item in
        Text("• \(item)")
          .font(WingmanType.subheadline())
          .foregroundStyle(WingmanPalette.ink)
      }
    }
  }
}

private struct ConsentCard: View {
  @Bindable var model: AppModel
  let insight: MatchInsight

  private var consent: IntroductionConsent {
    model.consent(for: insight.id)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.sm) {
      Text("Both humans choose")
        .font(WingmanType.headline())
        .foregroundStyle(WingmanPalette.ink)
      Text("For the prototype, these switches simulate two independent approvals. Production approval arrives from each person’s own account.")
        .font(WingmanType.caption())
        .foregroundStyle(WingmanPalette.inkSecondary)
      Toggle(
        "I want this introduction",
        isOn: Binding(
          get: { consent.firstHumanApproved },
          set: { model.setConsent(matchID: insight.id, firstHuman: $0) }
        )
      )
      .tint(WingmanPalette.accent)
      Toggle(
        "The other human approved",
        isOn: Binding(
          get: { consent.secondHumanApproved },
          set: { model.setConsent(matchID: insight.id, secondHuman: $0) }
        )
      )
      .tint(WingmanPalette.accent)
      Label(
        consent.canIntroduce ? "Ready in the Wingman iMessage app" : "Waiting for both approvals",
        systemImage: consent.canIntroduce ? "message.fill" : "hourglass"
      )
      .font(WingmanType.subheadline(.semibold))
      .foregroundStyle(consent.canIntroduce ? WingmanPalette.success : WingmanPalette.inkSecondary)
    }
    .wingmanCard(radius: WingmanMetrics.Radius.lg, emphasis: .accent)
  }
}

private struct CalloutCard: View {
  let icon: String
  let title: String
  let detail: String

  var body: some View {
    HStack(alignment: .top, spacing: WingmanMetrics.Spacing.sm) {
      Image(systemName: icon).foregroundStyle(WingmanPalette.warning)
      VStack(alignment: .leading, spacing: 4) {
        Text(title).font(WingmanType.headline()).foregroundStyle(WingmanPalette.ink)
        Text(detail).font(WingmanType.subheadline()).foregroundStyle(WingmanPalette.inkSecondary)
      }
    }
    .wingmanCard(emphasis: .warning)
  }
}
