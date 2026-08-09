import SwiftUI

/// Replaces `CommaListField`, which edited an array as a single comma-joined
/// string (breaking on commas mid-word, trailing commas, or mid-list edits).
/// This keeps each value as its own removable chip and only turns typed text
/// into a new chip on comma or return, so editing one entry never corrupts
/// the rest of the list.
public struct ChipListField: View {
  var placeholder: String
  @Binding var values: [String]
  @State private var draft: String = ""

  public init(placeholder: String, values: Binding<[String]>) {
    self.placeholder = placeholder
    self._values = values
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.sm) {
      if !values.isEmpty {
        WingmanFlowLayout(spacing: WingmanMetrics.Spacing.xs) {
          ForEach(values, id: \.self) { value in
            ChipView(text: value) { remove(value) }
          }
        }
      }

      TextField(placeholder, text: $draft)
        .textFieldStyle(.plain)
        .font(WingmanType.body())
        .onSubmit(commitDraft)
        .onChange(of: draft) { _, newValue in
          guard newValue.contains(",") else { return }
          commitDraft()
        }
    }
  }

  private func commitDraft() {
    let pieces = draft
      .split(separator: ",", omittingEmptySubsequences: true)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    guard !pieces.isEmpty else {
      draft = ""
      return
    }
    for piece in pieces where !values.contains(piece) {
      values.append(piece)
    }
    draft = ""
  }

  private func remove(_ value: String) {
    values.removeAll { $0 == value }
  }
}

private struct ChipView: View {
  let text: String
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 4) {
      Text(text)
        .font(WingmanType.subheadline())
      Button(action: onRemove) {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 13))
      }
      .buttonStyle(.plain)
      .foregroundStyle(WingmanPalette.inkSecondary)
    }
    .padding(.horizontal, WingmanMetrics.Spacing.sm)
    .padding(.vertical, 6)
    .background(WingmanPalette.accentWash(), in: Capsule())
    .foregroundStyle(WingmanPalette.accent)
  }
}

/// Minimal wrapping layout so chips flow onto multiple lines. `SwiftUI.Layout`
/// (iOS 16+) keeps this self-contained without a third-party dependency.
public struct WingmanFlowLayout: Layout {
  var spacing: CGFloat

  public init(spacing: CGFloat = 8) {
    self.spacing = spacing
  }

  public func sizeThatFits(
    proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) -> CGSize {
    let width = proposal.width ?? .infinity
    var rowWidth: CGFloat = 0
    var totalHeight: CGFloat = 0
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if rowWidth + size.width > width, rowWidth > 0 {
        totalHeight += rowHeight + spacing
        rowWidth = 0
        rowHeight = 0
      }
      rowWidth += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    totalHeight += rowHeight
    return CGSize(width: width == .infinity ? rowWidth : width, height: totalHeight)
  }

  public func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var origin = bounds.origin
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
        origin.x = bounds.minX
        origin.y += rowHeight + spacing
        rowHeight = 0
      }
      subview.place(at: origin, proposal: .unspecified)
      origin.x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
