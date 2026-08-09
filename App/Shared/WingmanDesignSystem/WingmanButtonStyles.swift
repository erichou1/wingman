import SwiftUI

/// Every control is solid black or a hairline outline — no gradient fills,
/// no accent color competing with the mesh gradient backgrounds. Matches the
/// reference's send button / "Insert into Messages" pill exactly.
public struct WingmanPrimaryButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(WingmanType.headline())
      .foregroundStyle(WingmanPalette.canvas)
      .padding(.vertical, WingmanMetrics.Spacing.sm + 3)
      .padding(.horizontal, WingmanMetrics.Spacing.lg)
      .frame(maxWidth: .infinity)
      .background(
        WingmanPalette.ink.opacity(configuration.isPressed ? 0.82 : 1),
        in: Capsule(style: .continuous)
      )
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

public struct WingmanSecondaryButtonStyle: ButtonStyle {
  public init() {}

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(WingmanType.headline())
      .foregroundStyle(WingmanPalette.ink)
      .padding(.vertical, WingmanMetrics.Spacing.sm + 3)
      .padding(.horizontal, WingmanMetrics.Spacing.lg)
      .frame(maxWidth: .infinity)
      .background(
        configuration.isPressed ? WingmanPalette.surfaceSunken : WingmanPalette.surface,
        in: Capsule(style: .continuous)
      )
      .overlay(
        Capsule(style: .continuous).stroke(WingmanPalette.hairline, lineWidth: 1)
      )
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

/// A small solid-black circular control — the reference's send button.
public struct WingmanIconButtonStyle: ButtonStyle {
  var filled: Bool
  public init(filled: Bool = false) { self.filled = filled }

  public func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .bold))
      .foregroundStyle(filled ? WingmanPalette.canvas : WingmanPalette.inkSecondary)
      .frame(width: filled ? 32 : 28, height: filled ? 32 : 28)
      .background(
        filled ? WingmanPalette.ink.opacity(configuration.isPressed ? 0.82 : 1) : WingmanPalette.hairline.opacity(configuration.isPressed ? 1.6 : 1),
        in: Circle()
      )
      .scaleEffect(configuration.isPressed ? 0.92 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

extension ButtonStyle where Self == WingmanPrimaryButtonStyle {
  public static var wingmanPrimary: WingmanPrimaryButtonStyle { WingmanPrimaryButtonStyle() }
}

extension ButtonStyle where Self == WingmanSecondaryButtonStyle {
  public static var wingmanSecondary: WingmanSecondaryButtonStyle { WingmanSecondaryButtonStyle() }
}

extension ButtonStyle where Self == WingmanIconButtonStyle {
  public static var wingmanIcon: WingmanIconButtonStyle { WingmanIconButtonStyle() }
  public static var wingmanIconFilled: WingmanIconButtonStyle { WingmanIconButtonStyle(filled: true) }
}
