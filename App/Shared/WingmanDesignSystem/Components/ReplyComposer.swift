import SwiftUI
import WingmanCore

/// The "paste a message, pick a relationship, describe your goal" form.
/// Previously hand-duplicated between `HomeView` (containing app) and
/// `MessagesRootView` (extension) with identical fields — unifying it here
/// means the two surfaces can no longer drift out of sync.
public struct ReplyComposer: View {
  @Binding var request: ReplyRequest
  var note: String?
  var isLoading: Bool
  var onGenerate: () -> Void

  public init(
    request: Binding<ReplyRequest>,
    note: String? = nil,
    isLoading: Bool = false,
    onGenerate: @escaping () -> Void
  ) {
    self._request = request
    self.note = note
    self.isLoading = isLoading
    self.onGenerate = onGenerate
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.md) {
      if let note {
        Text(note)
          .font(WingmanType.caption())
          .foregroundStyle(WingmanPalette.inkSecondary)
      }

      Picker("Relationship", selection: $request.relationship) {
        ForEach(RelationshipKind.allCases) { kind in
          Text(kind.title).tag(kind)
        }
      }
      .pickerStyle(.menu)
      .tint(WingmanPalette.accent)

      WingmanTextEditor("Message you're responding to", text: $request.incomingMessage, lineLimit: 3...7)

      WingmanTextEditor("Useful context (optional)", text: $request.context, lineLimit: 2...4)

      WingmanTextField("What should this reply do?", text: $request.goal)

      Button(action: onGenerate) {
        if isLoading {
          Label {
            Text("Drafting…")
          } icon: {
            ProgressView()
              .tint(WingmanPalette.canvas)
          }
        } else {
          Label("Draft three replies", systemImage: "sparkles")
        }
      }
      .buttonStyle(.wingmanPrimary)
      .disabled(isLoading || request.incomingMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
  }
}
