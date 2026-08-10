import SwiftUI

/// The Wingman app mark: the speech bubble and chevron "W" from the app icon,
/// without the icon's rounded-square plate (which would disappear against the
/// coral onboarding gradient it sits on).
///
/// The geometry is transcribed from `Design/WingmanAppIcon.svg`, so the sign-in
/// lockup and the home-screen icon are the same drawing rather than a stand-in
/// SF Symbol. Drawn as a `Shape` instead of shipping the SVG through the asset
/// catalog because the mark's stroke is a gradient, and the two vector marks
/// already in `Assets.xcassets` (OpenAI, Claude) are flat fills — Xcode's SVG
/// support does not cover gradient strokes.
public struct WingmanMark: View {
  /// Fixed brand artwork, so these are literals rather than `WingmanPalette`
  /// tokens: the mark must not flip with the system color scheme. `cream` and
  /// `defaultChevron` are public only because they are default argument values
  /// on a public initializer.
  public static let cream = Color(red: 1.0, green: 0.992, blue: 0.965)
  private static let coral = Color(red: 1.0, green: 0.333, blue: 0.310)
  private static let magenta = Color(red: 1.0, green: 0.129, blue: 0.396)

  public static let defaultChevron = LinearGradient(
    colors: [coral, magenta],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  /// The icon's red, for the mark on a light ground.
  public static let brandRed = Color(red: 0.95, green: 0.20, blue: 0.35)

  /// Fills the chevron with the icon's cream, so a coloured bubble reads as the
  /// app icon rather than a two-hue shape.
  public static let creamChevron = LinearGradient(
    colors: [cream, cream],
    startPoint: .top,
    endPoint: .bottom
  )

  var bubble: Color
  var chevron: LinearGradient

  public init(
    bubble: Color = WingmanMark.cream,
    chevron: LinearGradient = WingmanMark.defaultChevron
  ) {
    self.bubble = bubble
    self.chevron = chevron
  }

  public var body: some View {
    GeometryReader { proxy in
      ZStack {
        WingmanBubbleShape().fill(bubble)
        WingmanChevronShape()
          .stroke(
            chevron,
            style: StrokeStyle(
              lineWidth: WingmanMarkGeometry.chevronWidth
                * (proxy.size.width / WingmanMarkGeometry.size.width),
              lineCap: .round,
              lineJoin: .round
            )
          )
      }
    }
    .aspectRatio(WingmanMarkGeometry.aspectRatio, contentMode: .fit)
    .accessibilityHidden(true)
  }
}

/// Shared mapping from the icon's 1024-point canvas into a view rect.
enum WingmanMarkGeometry {
  /// Tight bounding box of the mark within the 1024-point icon canvas.
  static let origin = CGPoint(x: 194, y: 210)
  static let size = CGSize(width: 636, height: 608)
  static let chevronWidth: CGFloat = 72

  static var aspectRatio: CGFloat { size.width / size.height }

  /// Callers apply `aspectRatio(_:contentMode: .fit)`, so scaling each axis
  /// independently here still comes out uniform.
  static func point(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
    CGPoint(
      x: rect.minX + (x - origin.x) / size.width * rect.width,
      y: rect.minY + (y - origin.y) / size.height * rect.height
    )
  }
}

struct WingmanBubbleShape: Shape {
  func path(in rect: CGRect) -> Path {
    func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      WingmanMarkGeometry.point(x, y, in: rect)
    }

    var path = Path()
    path.move(to: at(194, 322))
    path.addCurve(to: at(306, 210), control1: at(194, 260), control2: at(244, 210))
    path.addLine(to: at(718, 210))
    path.addCurve(to: at(830, 322), control1: at(780, 210), control2: at(830, 260))
    path.addLine(to: at(830, 584))
    path.addCurve(to: at(718, 696), control1: at(830, 646), control2: at(780, 696))
    path.addLine(to: at(491, 696))
    path.addLine(to: at(335, 818))
    path.addCurve(to: at(271, 787), control1: at(309, 838), control2: at(271, 820))
    path.addLine(to: at(271, 696))
    path.addCurve(to: at(194, 589), control1: at(226, 681), control2: at(194, 639))
    path.closeSubpath()
    return path
  }
}

struct WingmanChevronShape: Shape {
  func path(in rect: CGRect) -> Path {
    func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
      WingmanMarkGeometry.point(x, y, in: rect)
    }

    var path = Path()
    path.move(to: at(326, 373))
    path.addLine(to: at(437, 591))
    path.addLine(to: at(512, 446))
    path.addLine(to: at(587, 591))
    path.addLine(to: at(698, 373))
    return path
  }
}

#Preview {
  ZStack {
    LinearGradient(
      colors: [
        Color(red: 0.91, green: 0.22, blue: 0.38),
        Color(red: 0.98, green: 0.47, blue: 0.33)
      ],
      startPoint: .bottomLeading,
      endPoint: .topTrailing
    )
    .ignoresSafeArea()

    HStack(spacing: 12) {
      WingmanMark().frame(height: 56)
      Text("wingman")
        .font(.system(size: 48, weight: .heavy, design: .rounded))
        .tracking(-2)
        .foregroundStyle(.white)
    }
  }
}

#if canImport(UIKit)
  import UIKit

  extension WingmanMark {
    /// The mark as a tab-bar icon.
    ///
    /// The tab bar is UIKit and renders a `UIImage`, not a SwiftUI view, so the
    /// mark has to be rasterised once. The chevron is knocked out rather than
    /// filled with a second colour, because a template image only has coverage
    /// and alpha — a lighter chevron would render solid. Tinting is then left
    /// to the tab bar, the way a monochrome logo tab is supposed to behave.
    @MainActor public static let tabIcon: UIImage? = {
      let side: CGFloat = 26
      let renderer = ImageRenderer(
        content:
          ZStack {
            WingmanBubbleShape().fill(.black)
            WingmanChevronShape()
              .stroke(
                .black,
                style: StrokeStyle(
                  lineWidth: WingmanMarkGeometry.chevronWidth
                    * (side / WingmanMarkGeometry.size.width),
                  lineCap: .round,
                  lineJoin: .round
                )
              )
              .blendMode(.destinationOut)
          }
          .compositingGroup()
          .frame(width: side, height: side * (WingmanMarkGeometry.size.height / WingmanMarkGeometry.size.width))
      )
      renderer.scale = UIScreen.main.scale
      return renderer.uiImage?.withRenderingMode(.alwaysTemplate)
    }()
  }
#endif
