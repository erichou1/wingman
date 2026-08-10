import SwiftUI
import WingmanCore

struct MeetView: View {
  @Bindable var model: AppModel

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 22) {
        EditorialHeader(
          rubric: "Introductions",
          title: "Meet my human",
          detail: "No swiping. No compatibility score. What may resonate, and what deserves an honest conversation."
        )

        if !model.profileReady {
          CalloutCard(
            icon: "person.crop.circle.badge.exclamationmark",
            title: "Finish your approved profile",
            detail: "Approve your name, connection types, and at least one value or interest before an introduction."
          )
        }

        if model.state.candidates.isEmpty {
          emptyState
        } else {
          VStack(spacing: 14) {
            ForEach(model.state.candidates) { candidate in
              CandidateCard(
                profile: candidate.publicSnapshot,
                selected: model.selectedCandidate?.id == candidate.id
              ) {
                model.selectedCandidateID = candidate.id
              }
            }
          }

          Button {
            model.compareSelectedProfiles()
          } label: {
            Text("Ask our wingpeople")
          }
          .buttonStyle(EditorialPrimaryButtonStyle(enabled: model.profileReady))
          .disabled(!model.profileReady)
        }

        if let insight = model.selectedInsight {
          InsightCard(insight: insight)
          ConsentCard(model: model, insight: insight)
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 10)
      .padding(.bottom, 32)
    }
    .editorialPage()
    .navigationBarTitleDisplayMode(.inline)
  }

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: 14) {
      EditorialRubric("Nobody here yet")

      Text("Wingman has no one to introduce you to.")
        .font(WingmanEditorial.answer(20))
        .foregroundStyle(WingmanEditorial.ink)
        .fixedSize(horizontal: false, vertical: true)

      Text("This is a local prototype profile for trying the flow — Wingman has no real invite or matching backend yet.")
        .font(WingmanEditorial.body(14))
        .foregroundStyle(WingmanEditorial.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)

      Button {
        model.seedDemoCandidate()
      } label: {
        Text("Add sample profile")
      }
      .buttonStyle(.editorialPrimary)
      .padding(.top, 2)
    }
    .editorialCard()
  }
}

// MARK: - A person

/// A candidate read the way a profile should read: who they are, then what
/// they wrote, then their vitals as a stack of quiet rows.
private struct CandidateCard: View {
  let profile: ApprovedProfile
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 16) {
        header

        if let bio = profile.bio, !bio.isEmpty {
          Text(bio)
            .font(WingmanEditorial.answer(20))
            .foregroundStyle(WingmanEditorial.ink)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
        }

        if !attributes.isEmpty {
          EditorialDivider()

          VStack(alignment: .leading, spacing: 12) {
            ForEach(attributes, id: \.text) { attribute in
              EditorialAttributeRow(attribute.icon, attribute.text, detail: attribute.detail)
            }
          }
        }
      }
      .editorialCard(selected: selected)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(profile.displayName)\(selected ? ", selected" : "")")
    .accessibilityHint("Select this person for an introduction")
  }

  private var header: some View {
    HStack(spacing: 13) {
      ZStack {
        Circle().fill(WingmanEditorial.ground)
        Text(monogram)
          .font(WingmanEditorial.answer(20, .semibold))
          .foregroundStyle(WingmanEditorial.accent)
      }
      .frame(width: 46, height: 46)

      VStack(alignment: .leading, spacing: 2) {
        Text(profile.displayName)
          .font(.system(size: 19, weight: .semibold))
          .foregroundStyle(WingmanEditorial.ink)

        if !openTo.isEmpty {
          Text(openTo)
            .font(WingmanEditorial.body(13))
            .foregroundStyle(WingmanEditorial.inkSecondary)
        }
      }

      Spacer(minLength: 0)

      // The like affordance sits where the eye already is on a profile card —
      // top-right of the person, not buried in a row of controls below.
      Image(systemName: selected ? "heart.fill" : "heart")
        .font(.system(size: 19))
        .foregroundStyle(selected ? WingmanEditorial.accent : WingmanEditorial.inkSecondary.opacity(0.5))
    }
  }

  private var monogram: String {
    String(profile.displayName.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
  }

  private var openTo: String {
    profile.lookingFor.map(\.title).sorted().joined(separator: " · ")
  }

  private struct Attribute {
    let icon: String
    let text: String
    var detail: String?
  }

  private var attributes: [Attribute] {
    var rows: [Attribute] = []
    if !profile.values.isEmpty {
      rows.append(Attribute(icon: "heart.text.square", text: profile.values.joined(separator: ", ")))
    }
    if !profile.interests.isEmpty {
      rows.append(Attribute(icon: "sparkles", text: profile.interests.joined(separator: ", ")))
    }
    if !profile.lifestyle.isEmpty {
      rows.append(Attribute(icon: "sun.horizon", text: profile.lifestyle.joined(separator: ", ")))
    }
    if let style = profile.communicationStyle, !style.isEmpty {
      rows.append(Attribute(icon: "bubble.left.and.text.bubble.right", text: style))
    }
    if !profile.boundaries.isEmpty {
      rows.append(
        Attribute(
          icon: "hand.raised",
          text: "Boundaries",
          detail: profile.boundaries.joined(separator: ", ")
        )
      )
    }
    return rows
  }
}

// MARK: - What the wingpeople said

private struct InsightCard: View {
  let insight: MatchInsight

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      EditorialRubric("What the wingpeople noticed")

      InsightSection(title: "Possible resonance", icon: "circle.hexagongrid", items: insight.resonance)

      if !insight.friction.isEmpty {
        EditorialDivider()
        InsightSection(title: "Worth discussing", icon: "exclamationmark.bubble", items: insight.friction)
      }

      if !insight.conversationStarters.isEmpty {
        EditorialDivider()
        InsightSection(title: "A place to begin", icon: "quote.opening", items: insight.conversationStarters)
      }
    }
    .editorialCard(padding: 22)
  }
}

private struct InsightSection: View {
  let title: String
  let icon: String
  let items: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 7) {
        Image(systemName: icon)
          .font(.system(size: 12))
          .foregroundStyle(WingmanEditorial.accent)
        EditorialRubric(title, tint: WingmanEditorial.accent)
      }

      ForEach(items, id: \.self) { item in
        Text(item)
          .font(WingmanEditorial.answer(17))
          .foregroundStyle(WingmanEditorial.ink)
          .lineSpacing(3)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Both humans choose

private struct ConsentCard: View {
  @Bindable var model: AppModel
  let insight: MatchInsight

  private var consent: IntroductionConsent {
    model.consent(for: insight.id)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      EditorialRubric("Both humans choose")

      Text("For the prototype, these switches simulate two independent approvals. Production approval arrives from each person’s own account.")
        .font(WingmanEditorial.body(13))
        .foregroundStyle(WingmanEditorial.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)

      EditorialDivider()

      Toggle(
        "I want this introduction",
        isOn: Binding(
          get: { consent.firstHumanApproved },
          set: { model.setConsent(matchID: insight.id, firstHuman: $0) }
        )
      )
      .tint(WingmanEditorial.accent)

      Toggle(
        "The other human approved",
        isOn: Binding(
          get: { consent.secondHumanApproved },
          set: { model.setConsent(matchID: insight.id, secondHuman: $0) }
        )
      )
      .tint(WingmanEditorial.accent)

      EditorialDivider()

      Label(
        consent.canIntroduce ? "Ready in the Wingman iMessage app" : "Waiting for both approvals",
        systemImage: consent.canIntroduce ? "checkmark.circle" : "hourglass"
      )
      .font(WingmanEditorial.body(14, .medium))
      .foregroundStyle(consent.canIntroduce ? WingmanEditorial.accent : WingmanEditorial.inkSecondary)
    }
    .font(WingmanEditorial.body(15))
    .foregroundStyle(WingmanEditorial.ink)
    .editorialCard(padding: 22)
  }
}

// MARK: - Callout

private struct CalloutCard: View {
  let icon: String
  let title: String
  let detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 13) {
      Image(systemName: icon)
        .font(.system(size: 17))
        .foregroundStyle(WingmanEditorial.accent)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(WingmanEditorial.heading())
          .foregroundStyle(WingmanEditorial.ink)
        Text(detail)
          .font(WingmanEditorial.body(13))
          .foregroundStyle(WingmanEditorial.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .editorialCard(padding: 16, selected: true)
  }
}
