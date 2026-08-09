import SwiftUI
import UIKit
import WingmanCore

struct HomeView: View {
  @Bindable var model: AppModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.lg) {
        header

        VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.sm) {
          ReplyComposer(
            request: $model.replyRequest,
            isLoading: model.isGeneratingReplies,
            onGenerate: model.generateReplies
          )
        }
        .padding(WingmanMetrics.Spacing.md)
        .background(WingmanPalette.surface, in: RoundedRectangle(cornerRadius: WingmanMetrics.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 10)

        if model.replySuggestions.isEmpty {
          WingmanEmptyState(
            icon: "sparkles",
            title: "Your drafts will show up here",
            message: "Paste a message above and Wingman will suggest three editable replies."
          )
        } else {
          VStack(spacing: WingmanMetrics.Spacing.sm) {
            ForEach(model.replySuggestions) { suggestion in
              ReplySuggestionCard(suggestion: suggestion) {
                Button {
                  UIPasteboard.general.string = suggestion.text
                } label: {
                  Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.wingmanIcon)
                .accessibilityLabel("Copy \(suggestion.tone.title) reply")
              }
            }
          }
        }
      }
      .padding(.horizontal, WingmanMetrics.Spacing.md)
      .padding(.top, WingmanMetrics.Spacing.sm)
      .padding(.bottom, WingmanMetrics.Spacing.xl)
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

  private var header: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(greeting)
        .font(WingmanType.subheadline(.semibold))
        .foregroundStyle(WingmanPalette.meshInkSecondary)
      Text("What do you want to say?")
        .font(.system(size: 30, weight: .heavy))
        .foregroundStyle(WingmanPalette.meshInk)
        .fixedSize(horizontal: false, vertical: true)
      Text("You remain the author of every message.")
        .font(WingmanType.subheadline())
        .foregroundStyle(WingmanPalette.meshInkSecondary)
    }
    .padding(.top, WingmanMetrics.Spacing.sm)
  }

  private var greeting: String {
    let name = model.state.currentProfile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? "Hi there" : "Hi, \(name)"
  }
}
