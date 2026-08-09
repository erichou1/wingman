import SwiftUI
import WingmanCore

/// One drafted reply. The trailing slot differs by surface — Home offers
/// "Copy", the Messages extension offers "Insert" — so it's left to the
/// caller rather than baked in here.
public struct ReplySuggestionCard<Trailing: View>: View {
  var suggestion: ReplySuggestion
  @ViewBuilder var trailing: () -> Trailing

  public init(suggestion: ReplySuggestion, @ViewBuilder trailing: @escaping () -> Trailing) {
    self.suggestion = suggestion
    self.trailing = trailing
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: WingmanMetrics.Spacing.sm) {
      HStack {
        Text(suggestion.tone.title)
          .font(WingmanType.headline())
          .foregroundStyle(WingmanPalette.ink)
        Spacer()
        trailing()
      }
      Text(suggestion.text)
        .font(WingmanType.body())
        .foregroundStyle(WingmanPalette.ink)
        .textSelection(.enabled)
      Text(suggestion.rationale)
        .font(WingmanType.caption())
        .foregroundStyle(WingmanPalette.inkSecondary)
    }
    .wingmanCard()
  }
}
