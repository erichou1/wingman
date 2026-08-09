import SwiftUI

/// A text input with no visible box by default — the specific complaint was
/// that the previous `.textFieldStyle(.plain)` + tinted-background fields
/// still "felt like textboxes." This one has no fill and no border in its
/// resting state: just a floating label (Linear-style — sits inline as the
/// placeholder, animates to a small caption above on focus or content) and a
/// bottom hairline that only brightens to the accent color while focused.
public struct WingmanTextField: View {
  private var label: String
  @Binding private var text: String
  private var axis: Axis
  private var lineLimit: ClosedRange<Int>?
  @FocusState private var isFocused: Bool

  public init(
    _ label: String,
    text: Binding<String>,
    axis: Axis = .horizontal,
    lineLimit: ClosedRange<Int>? = nil
  ) {
    self.label = label
    self._text = text
    self.axis = axis
    self.lineLimit = lineLimit
  }

  private var isElevated: Bool { isFocused || !text.isEmpty }

  public var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(WingmanType.caption())
        .foregroundStyle(isFocused ? WingmanPalette.accent : WingmanPalette.inkSecondary)
        .opacity(isElevated ? 1 : 0)
        .frame(height: 14, alignment: .leading)

      field
        .focused($isFocused)
        .font(WingmanType.body())
        .foregroundStyle(WingmanPalette.ink)
        .textFieldStyle(.plain)
        .tint(WingmanPalette.accent)
    }
    .padding(.top, WingmanMetrics.Spacing.xs)
    .padding(.bottom, WingmanMetrics.Spacing.sm)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(isFocused ? WingmanPalette.accent : WingmanPalette.hairline)
        .frame(height: isFocused ? 1.5 : 1)
    }
    .animation(.easeOut(duration: 0.16), value: isFocused)
    .animation(.easeOut(duration: 0.16), value: isElevated)
  }

  @ViewBuilder
  private var field: some View {
    if let lineLimit {
      TextField(isElevated ? "" : label, text: $text, axis: axis)
        .lineLimit(lineLimit)
    } else {
      TextField(isElevated ? "" : label, text: $text)
    }
  }
}
