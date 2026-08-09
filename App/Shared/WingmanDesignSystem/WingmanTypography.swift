import SwiftUI

/// A small type scale used everywhere instead of ad hoc `.font(.system(size:...))`
/// calls and stock text styles, so every screen shares the same voice.
///
/// Bigger and bolder than a typical form UI — the mesh-gradient screens
/// carry a confident, editorial headline, not a quiet system label.
public enum WingmanType {
  public static func display(_ weight: Font.Weight = .heavy) -> Font {
    .system(size: 32, weight: weight, design: .default)
  }

  public static func title(_ weight: Font.Weight = .heavy) -> Font {
    .system(size: 24, weight: weight, design: .default)
  }

  public static func headline(_ weight: Font.Weight = .bold) -> Font {
    .system(size: 16, weight: weight, design: .default)
  }

  public static func body(_ weight: Font.Weight = .medium) -> Font {
    .system(size: 15, weight: weight, design: .default)
  }

  public static func subheadline(_ weight: Font.Weight = .medium) -> Font {
    .system(size: 13, weight: weight, design: .default)
  }

  public static func caption(_ weight: Font.Weight = .semibold) -> Font {
    .system(size: 11, weight: weight, design: .default)
  }
}
