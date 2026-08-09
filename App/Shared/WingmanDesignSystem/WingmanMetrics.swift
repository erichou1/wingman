import CoreGraphics

/// Shared spacing and corner-radius scale. Replaces the previously ad hoc
/// corner radii (14 / 16 / 18 / 20) scattered across screens.
public enum WingmanMetrics {
  public enum Spacing {
    public static let xs: CGFloat = 6
    public static let sm: CGFloat = 10
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
  }

  /// Generous, soft-card radii — floating white cards over the mesh
  /// gradient, not flat hairline-bordered rows.
  public enum Radius {
    public static let sm: CGFloat = 14
    public static let md: CGFloat = 18
    public static let lg: CGFloat = 26
    public static let pill: CGFloat = 999
  }
}
