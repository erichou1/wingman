import SwiftUI

/// Promoted from `HomeView`'s private `PrivacyPill` so Home, Meet, and Settings
/// all show the same "nothing sends itself" mark instead of three near-identical
/// inline copies.
public struct PrivacyBadge: View {
  var text: String

  public init(_ text: String = "Private by default · Nothing sends itself") {
    self.text = text
  }

  public var body: some View {
    Label(text, systemImage: "lock.fill")
      .font(WingmanType.caption(.semibold))
      .padding(.horizontal, WingmanMetrics.Spacing.md)
      .padding(.vertical, WingmanMetrics.Spacing.xs)
      .background(WingmanPalette.accentWash(), in: Capsule())
      .foregroundStyle(WingmanPalette.accent)
  }
}

#Preview {
  PrivacyBadge()
    .padding()
}
