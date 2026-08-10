import SwiftUI

/// Semantic color tokens shared by the Wingman app and the Messages extension.
///
/// Light-first: white ground, near-black ink, and a signature four-color
/// mesh gradient (blue/mint/peach/yellow) used as an ambient background wash
/// on the "reflective" screens (Home, Meet, Memories) — never as a fill on
/// buttons or icons. Every control is solid black or a hairline outline;
/// color lives in the gradient, not scattered across the UI.
public enum WingmanPalette {
  public static let ink = Color(light: rgb(0x17, 0x16, 0x18), dark: rgb(0xF4, 0xF3, 0xF5))
  public static let inkSecondary = Color(light: rgb(0x8B, 0x88, 0x91), dark: rgb(0x99, 0x96, 0x9F))
  public static let inkTertiary = Color(light: rgb(0xC2, 0xC0, 0xC7), dark: rgb(0x47, 0x45, 0x4C))

  public static let canvas = Color(light: rgb(0xFF, 0xFF, 0xFF), dark: rgb(0x12, 0x11, 0x13))
  public static let surface = Color(light: rgb(0xFF, 0xFF, 0xFF), dark: rgb(0x1A, 0x19, 0x19))
  public static let surfaceSunken = Color(light: rgb(0xF6, 0xF6, 0xF7), dark: rgb(0x1F, 0x1E, 0x21))
  public static let hairline = Color(light: rgb(0x14, 0x12, 0x18).opacity(0.09), dark: rgb(0xFF, 0xFF, 0xFF).opacity(0.10))

  /// The signature mesh gradient palette — always these four, always in
  /// this role. Fixed values (not light/dark adaptive): the phone screens
  /// are a committed light surface regardless of system theme, same as the
  /// product's actual design.
  public static let mesh1 = rgb(0xA9, 0xC6, 0xEA)  // soft blue
  public static let mesh2 = rgb(0xBF, 0xE0, 0xC6)  // soft mint
  public static let mesh3 = rgb(0xF6, 0xC8, 0xB8)  // soft peach
  public static let mesh4 = rgb(0xF3, 0xDD, 0x9E)  // soft yellow

  /// Semantic-only — status text, never decorative fills.
  public static let success = Color(light: rgb(0x1F, 0x9D, 0x5C), dark: rgb(0x3D, 0xDC, 0x84))
  public static let warning = Color(light: rgb(0xB8, 0x79, 0x0F), dark: rgb(0xF2, 0xC1, 0x4B))
  public static let danger = Color(light: rgb(0xD6, 0x30, 0x4F), dark: rgb(0xFF, 0x4D, 0x6A))

  /// "Accent" IS ink in this design — there's no separate brand color
  /// competing with the mesh gradient; every control is solid black or a
  /// hairline outline. Kept as a named alias so call sites read semantically
  /// (tint, selected state, CTA fill) without a second color to maintain.
  public static let accent = ink
  public static let accentSecondary = inkSecondary
  public static func accentWash(_ opacity: Double = 0.06) -> Color { ink.opacity(opacity) }

  /// `WingmanMeshBackground` is a fixed white surface regardless of system
  /// theme (see that file) — text drawn on it must be equally fixed, not
  /// `ink`/`inkSecondary`, which flip to near-white in Dark Mode and would
  /// go invisible against a background that never darkens. This was the
  /// actual cause of "hard to see": the surface was pinned light but the
  /// text on it wasn't.
  public static let meshInk = rgb(0x17, 0x16, 0x18)
  public static let meshInkSecondary = rgb(0x5C, 0x59, 0x63)

  /// Onboarding surface. A warm off-white ground with near-black type, white
  /// cards, hairline rules, and a single deep accent — no gradient anywhere.
  /// Fixed like the mesh tokens, since these screens commit to one look
  /// regardless of system theme; pair them with `meshInk`/`meshInkSecondary`.
  public static let warmCanvas = rgb(0xF4, 0xF2, 0xED)
  public static let warmSurface = rgb(0xFF, 0xFF, 0xFF)
  public static let warmHairline = rgb(0x17, 0x16, 0x18).opacity(0.12)
  /// The one accent on the onboarding surface: selection, the bloom, links.
  public static let bloom = rgb(0x6C, 0x00, 0x75)

  private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> Color {
    Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
  }
}

extension Color {
  /// A color that resolves differently per color scheme without needing an asset catalog entry.
  public init(light: Color, dark: Color) {
    #if canImport(UIKit)
      self = Color(
        UIColor { traits in
          UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
    #else
      self = light
    #endif
  }
}
