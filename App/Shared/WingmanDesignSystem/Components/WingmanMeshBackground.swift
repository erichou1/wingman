import SwiftUI

/// The signature ambient background: four soft radial blobs (blue, yellow,
/// peach, mint) anchored to the top and fading to clean white by mid-screen
/// — never a centered halo. Used behind the "reflective" screens (Home,
/// Meet, Memories); deliberately absent from utility screens (My Human,
/// Settings) so the contrast between staged and calm does the work.
///
/// Fixed white base — NOT `WingmanPalette.canvas`, which adapts to system
/// Dark Mode. This is a committed light surface independent of the phone's
/// theme setting, same as the product's actual design intent; pair its text
/// with `WingmanPalette.meshInk`/`meshInkSecondary` (also fixed), never
/// `.white` or the adaptive `ink` colors, or contrast breaks in Dark Mode.
///
/// Fixed pt radii rather than geometry-relative sizing: tuned for the phone
/// widths this app actually runs at, not arbitrary container sizes.
public struct WingmanMeshBackground: View {
  public init() {}

  private static let base = Color(red: 1, green: 1, blue: 1)

  public var body: some View {
    ZStack {
      Self.base

      RadialGradient(
        colors: [WingmanPalette.mesh1, WingmanPalette.mesh1.opacity(0)],
        center: UnitPoint(x: 0.12, y: -0.05), startRadius: 0, endRadius: 260
      )
      RadialGradient(
        colors: [WingmanPalette.mesh4, WingmanPalette.mesh4.opacity(0)],
        center: UnitPoint(x: 0.9, y: -0.05), startRadius: 0, endRadius: 240
      )
      RadialGradient(
        colors: [WingmanPalette.mesh3, WingmanPalette.mesh3.opacity(0)],
        center: UnitPoint(x: 0.98, y: 0.26), startRadius: 0, endRadius: 230
      )
      RadialGradient(
        colors: [WingmanPalette.mesh2, WingmanPalette.mesh2.opacity(0)],
        center: UnitPoint(x: 0.0, y: 0.30), startRadius: 0, endRadius: 230
      )

      LinearGradient(
        colors: [Self.base.opacity(0), Self.base],
        startPoint: UnitPoint(x: 0.5, y: 0.30),
        endPoint: UnitPoint(x: 0.5, y: 0.56)
      )
    }
  }
}
