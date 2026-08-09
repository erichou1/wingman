import SwiftUI
import WingmanCore

struct ProfileEditorView: View {
  @Bindable var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.lg) {
        VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.sm) {
          Text("Only fields you approve can appear in matching or an introduction.")
            .font(WingmanType.subheadline())
            .foregroundStyle(WingmanPalette.inkSecondary)
          ProgressView(value: approvalProgress)
            .tint(WingmanPalette.accent)
          Text("\(model.state.currentProfile.approvedFields.count) of \(ProfileField.allCases.count) fields approved")
            .font(WingmanType.caption())
            .foregroundStyle(WingmanPalette.inkSecondary)
        }
        .wingmanCard()

        profileSection("Identity", field: .displayName) {
          WingmanTextField("Your first name", text: $model.state.currentProfile.displayName)
            .textContentType(.name)
        }

        profileSection("About me", field: .bio) {
          WingmanTextEditor("What should another human understand?", text: $model.state.currentProfile.bio, lineLimit: 3...6)
        }

        profileSection("Open to", field: .lookingFor) {
          VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.xs) {
            ForEach(RelationshipKind.allCases) { kind in
              Toggle(
                kind.title,
                isOn: Binding(
                  get: { model.state.currentProfile.lookingFor.contains(kind) },
                  set: { enabled in
                    if enabled { model.state.currentProfile.lookingFor.insert(kind) } else {
                      model.state.currentProfile.lookingFor.remove(kind)
                    }
                  }
                )
              )
              .tint(WingmanPalette.accent)
              .font(WingmanType.body())
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
          ChipListField(placeholder: "Morning walks, creative work, quiet weekends", values: $model.state.currentProfile.lifestyle)
        }

        profileSection("Communication", field: .communicationStyle) {
          WingmanTextEditor("Direct, playful, needs time to think…", text: $model.state.currentProfile.communicationStyle, lineLimit: 1...4)
        }

        profileSection("Boundaries", field: .boundaries) {
          ChipListField(placeholder: "Ask before calls, no pressure for fast replies", values: $model.state.currentProfile.boundaries)
        }

        Button {
          model.save()
        } label: {
          Label("Save approved profile", systemImage: "checkmark.shield.fill")
        }
        .buttonStyle(.wingmanPrimary)
      }
      .padding()
    }
    .background(WingmanPalette.canvas)
    .navigationTitle("My human")
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
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.sm) {
      Text(title)
        .font(WingmanType.headline())
        .foregroundStyle(WingmanPalette.ink)
      content()
      Toggle("Approved for matching", isOn: approvalBinding(for: field))
        .tint(WingmanPalette.accent)
        .font(WingmanType.subheadline())
    }
    .wingmanCard()
  }

  private func approvalBinding(for field: ProfileField) -> Binding<Bool> {
    Binding(
      get: { model.state.currentProfile.approvedFields.contains(field) },
      set: { approved in
        if approved { model.state.currentProfile.approvedFields.insert(field) } else {
          model.state.currentProfile.approvedFields.remove(field)
        }
      }
    )
  }
}
