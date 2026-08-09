import SwiftUI

/// Floating white cards with a soft shadow — the mockup's "float-card" —
/// replacing the previous dark hairline-bordered card look. No border by
/// default; shadow alone separates the card from the mesh gradient or white
/// ground behind it.
public struct WingmanCardModifier: ViewModifier {
  public enum Emphasis {
    case standard
    case accent
    case warning
  }

  var radius: CGFloat
  var padding: CGFloat
  var emphasis: Emphasis

  public func body(content: Content) -> some View {
    content
      .padding(padding)
      .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
      .overlay {
        if emphasis != .standard {
          RoundedRectangle(cornerRadius: radius, style: .continuous)
            .stroke(strokeColor, lineWidth: 1.5)
        }
      }
      .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 10)
  }

  private var background: some ShapeStyle {
    switch emphasis {
    case .standard: AnyShapeStyle(WingmanPalette.surface)
    case .accent: AnyShapeStyle(WingmanPalette.accentWash(0.05))
    case .warning: AnyShapeStyle(WingmanPalette.warning.opacity(0.08))
    }
  }

  private var strokeColor: Color {
    switch emphasis {
    case .standard: WingmanPalette.hairline
    case .accent: WingmanPalette.accent.opacity(0.18)
    case .warning: WingmanPalette.warning.opacity(0.20)
    }
  }
}

extension View {
  public func wingmanCard(
    radius: CGFloat = WingmanMetrics.Radius.md,
    padding: CGFloat = WingmanMetrics.Spacing.md,
    emphasis: WingmanCardModifier.Emphasis = .standard
  ) -> some View {
    modifier(WingmanCardModifier(radius: radius, padding: padding, emphasis: emphasis))
  }

  /// A flat row variant (hairline divider, no shadow/background) for dense
  /// utility screens like Settings — deliberately calmer than `wingmanCard`.
  public func wingmanRow() -> some View {
    self.padding(.vertical, WingmanMetrics.Spacing.sm)
  }
}
