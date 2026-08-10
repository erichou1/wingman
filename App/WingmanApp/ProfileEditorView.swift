import SwiftUI
import WingmanCore

struct ProfileEditorView: View {
  @Bindable var model: AppModel

  var body: some View {
    ScrollView(showsIndicators: false) {
      VStack(alignment: .leading, spacing: 16) {
        EditorialHeader(
          rubric: "My human",
          title: "What you’re willing to share."
        )
        .padding(.bottom, 4)

        approvalCard

        profileSection("Identity", field: .displayName) {
          WingmanTextField("Your first name", text: $model.state.currentProfile.displayName)
            .textContentType(.name)
        }

        profileSection("About me", field: .bio) {
          WingmanTextEditor(
            "What should another human understand?",
            text: $model.state.currentProfile.bio,
            lineLimit: 3...6
          )
        }

        profileSection("Open to", field: .lookingFor) {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(RelationshipKind.allCases) { kind in
              Toggle(
                kind.title,
                isOn: Binding(
                  get: { model.state.currentProfile.lookingFor.contains(kind) },
                  set: { enabled in
                    if enabled {
                      model.state.currentProfile.lookingFor.insert(kind)
                    } else {
                      model.state.currentProfile.lookingFor.remove(kind)
                    }
                  }
                )
              )
              .tint(WingmanEditorial.accent)
              .font(WingmanEditorial.body())
              .foregroundStyle(WingmanEditorial.ink)
            }
          }
        }

        profileSection("Values", field: .values) {
          ChipListField(placeholder: "Kindness, curiosity, reliability", values: $model.state.currentProfile.values)
        }

        profileSection("Interests", field: .interests) {
          ChipListField(placeholder: "Hiking, cooking, live music", values: $model.state.currentProfile.interests)
        }

        profileSection("How I live", field: .lifestyle) {
          ChipListField(
            placeholder: "Morning walks, creative work, quiet weekends",
            values: $model.state.currentProfile.lifestyle
          )
        }

        profileSection("Communication", field: .communicationStyle) {
          WingmanTextEditor(
            "Direct, playful, needs time to think…",
            text: $model.state.currentProfile.communicationStyle,
            lineLimit: 1...4
          )
        }

        profileSection("Boundaries", field: .boundaries) {
          ChipListField(
            placeholder: "Ask before calls, no pressure for fast replies",
            values: $model.state.currentProfile.boundaries
          )
        }

        Button {
          model.save()
        } label: {
          Text("Save approved profile")
        }
        .buttonStyle(.editorialPrimary)
        .padding(.top, 8)
      }
      .padding(.horizontal, 20)
      .padding(.top, 10)
      .padding(.bottom, 32)
    }
    .editorialPage()
    .toolbar(.hidden, for: .navigationBar)
  }

  /// Approval is the whole point of this screen, so it gets the top card and a
  /// rule that fills rather than a stock progress bar.
  private var approvalCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        EditorialRubric("Approved for matching")
        Spacer()
        Text("\(model.state.currentProfile.approvedFields.count) of \(ProfileField.allCases.count)")
          .font(WingmanEditorial.body(13, .medium))
          .foregroundStyle(WingmanEditorial.accent)
      }

      GeometryReader { proxy in
        ZStack(alignment: .leading) {
          Capsule()
            .fill(WingmanEditorial.ground)
          Capsule()
            .fill(WingmanEditorial.accent)
            .frame(width: max(0, proxy.size.width * approvalProgress))
        }
      }
      .frame(height: 4)
      .animation(.easeOut(duration: 0.25), value: approvalProgress)

      Text("Only fields you approve can appear in matching or an introduction.")
        .font(WingmanEditorial.body(13))
        .foregroundStyle(WingmanEditorial.inkSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .editorialCard()
  }

  private var approvalProgress: Double {
    Double(model.state.currentProfile.approvedFields.count) / Double(ProfileField.allCases.count)
  }

  @ViewBuilder
  private func profileSection<Content: View>(
    _ title: String,
    field: ProfileField,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Text(title)
          .font(WingmanEditorial.heading())
          .foregroundStyle(WingmanEditorial.ink)

        Spacer(minLength: 0)

        // Labelled, because "Open to" stacks its own switches underneath and a
        // second naked toggle in the header reads as one more option rather
        // than as the control that shares the whole section.
        EditorialRubric("Approved")

        Toggle("", isOn: approvalBinding(for: field))
          .labelsHidden()
          .tint(WingmanEditorial.accent)
          .accessibilityLabel("\(title) approved for matching")
      }

      content()
    }
    .editorialCard()
  }

  private func approvalBinding(for field: ProfileField) -> Binding<Bool> {
    Binding(
      get: { model.state.currentProfile.approvedFields.contains(field) },
      set: { approved in
        if approved {
          model.state.currentProfile.approvedFields.insert(field)
        } else {
          model.state.currentProfile.approvedFields.remove(field)
        }
      }
    )
  }
}
