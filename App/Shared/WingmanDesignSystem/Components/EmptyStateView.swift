import SwiftUI

/// Shared empty state so every screen that can be "nothing here yet"
/// (Home before a reply is drafted, Meet before a match, the Messages
/// extension before an introduction) looks the same instead of either
/// showing a bare `ContentUnavailableView` or nothing at all.
public struct WingmanEmptyState: View {
  var icon: String
  var title: String
  var message: String

  public init(icon: String, title: String, message: String) {
    self.icon = icon
    self.title = title
    self.message = message
  }

  public var body: some View {
    VStack(spacing: WingmanMetrics.Spacing.sm) {
      Image(systemName: icon)
        .font(.system(size: 30))
        .foregroundStyle(WingmanPalette.accent)
      Text(title)
        .font(WingmanType.headline())
        .foregroundStyle(WingmanPalette.ink)
      Text(message)
        .font(WingmanType.subheadline())
        .foregroundStyle(WingmanPalette.inkSecondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, WingmanMetrics.Spacing.lg)
    .padding(.horizontal, WingmanMetrics.Spacing.md)
  }
}
