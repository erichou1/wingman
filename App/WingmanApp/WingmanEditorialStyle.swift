import SwiftUI

/// The surface language for every screen *behind* onboarding — Home, Meet,
/// My human, Memories, Privacy.
///
/// One ground, one card, one accent. A warm off-white page carries pure white
/// cards separated by a hairline rather than a shadow, and `bloom` appears only
/// where something is chosen, active, or approved — never as decoration. Long
/// text (a drafted reply, a bio, what a wingperson noticed) is set in a serif so
/// it reads as writing; every structural label stays in the system sans. That
/// split is the whole look: the app is quiet, and the words are the loud part.
///
/// This picks up the ground, ink, and accent the sign-in flow already
/// established (`warmCanvas` / `meshInk` / `bloom`) so the app does not change
/// character the moment onboarding ends.
///
/// It lives in the app target rather than in `WingmanDesignSystem` on purpose:
/// that folder also compiles into the Messages extension, which keeps its own
/// compact look and should not inherit page-sized cards and serif body copy.
enum WingmanEditorial {
  // MARK: Surface

  static let ground = WingmanPalette.warmCanvas
  static let card = WingmanPalette.warmSurface
  static let hairline = WingmanPalette.warmHairline
  static let accent = WingmanPalette.bloom

  /// The brand red — aliased to the mark's own red rather than redeclared, so
  /// the wordmark, the selected tab, and a like cannot drift apart. Distinct
  /// from `accent`, which stays purple where it means "your agent".
  static let brand = WingmanMark.brandRed

  /// Fixed inks, matching the ground: these screens commit to a light surface
  /// regardless of the system theme, so the adaptive `ink` tokens (which flip
  /// to near-white in Dark Mode) would go invisible here.
  static let ink = WingmanPalette.meshInk
  static let inkSecondary = WingmanPalette.meshInkSecondary

  static let cardRadius: CGFloat = 20

  // MARK: Type

  /// The page headline. Negative tracking at this size keeps a two-line
  /// heading from reading as loose as body copy.
  static func display(_ size: CGFloat = 30) -> Font {
    .system(size: size, weight: .bold)
  }

  static func heading(_ size: CGFloat = 17) -> Font {
    .system(size: size, weight: .semibold)
  }

  static func body(_ size: CGFloat = 15, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight)
  }

  /// The small tracked rubric above a section. Never larger than 11pt — it is
  /// a signpost, not a heading.
  static let rubric = Font.system(size: 11, weight: .semibold)

  /// Long-form voice. Anything a human wrote, or that Wingman wrote *for* a
  /// human to say, is set here.
  static func answer(_ size: CGFloat = 21, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .serif)
  }
}

// MARK: - Page and card

extension View {
  /// The shared page ground. Pins the light scheme for the whole subtree so
  /// the adaptive colors inside shared components (`WingmanTextField`'s
  /// hairline, `ChipListField`'s chips) resolve light against a ground that
  /// never darkens.
  func editorialPage() -> some View {
    background(WingmanEditorial.ground.ignoresSafeArea())
      .preferredColorScheme(.light)
  }

  /// A white card on the warm ground. Separated by a hairline and the ground
  /// showing through, with only enough shadow to lift the edge — the previous
  /// `wingmanCard` shadow (0.10 at 18pt) was tuned to float over the mesh
  /// gradient and reads as heavy here.
  func editorialCard(
    radius: CGFloat = WingmanEditorial.cardRadius,
    padding: CGFloat = 18,
    selected: Bool = false
  ) -> some View {
    modifier(EditorialCardModifier(radius: radius, padding: padding, selected: selected))
  }
}

struct EditorialCardModifier: ViewModifier {
  var radius: CGFloat
  var padding: CGFloat
  var selected: Bool

  func body(content: Content) -> some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        WingmanEditorial.card,
        in: RoundedRectangle(cornerRadius: radius, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: radius, style: .continuous)
          .stroke(
            selected ? WingmanEditorial.accent : WingmanEditorial.hairline,
            lineWidth: selected ? 1.6 : 1
          )
      )
      .shadow(color: .black.opacity(0.045), radius: 10, y: 4)
      .animation(.easeOut(duration: 0.18), value: selected)
  }
}

// MARK: - Pieces

/// The tracked all-caps signpost that opens a section.
struct EditorialRubric: View {
  var text: String
  var tint: Color = WingmanEditorial.inkSecondary

  init(_ text: String, tint: Color = WingmanEditorial.inkSecondary) {
    self.text = text
    self.tint = tint
  }

  var body: some View {
    Text(text.uppercased())
      .font(WingmanEditorial.rubric)
      .tracking(1.3)
      .foregroundStyle(tint)
  }
}

/// A page heading with its rubric — the standard way every screen opens, so
/// the five tabs share one entrance instead of five near-identical stacks.
struct EditorialHeader: View {
  var rubric: String
  var title: String
  var detail: String?

  init(rubric: String, title: String, detail: String? = nil) {
    self.rubric = rubric
    self.title = title
    self.detail = detail
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      EditorialRubric(rubric)

      Text(title)
        .font(WingmanEditorial.display())
        .kerning(-0.6)
        .foregroundStyle(WingmanEditorial.ink)
        .fixedSize(horizontal: false, vertical: true)

      if let detail {
        Text(detail)
          .font(WingmanEditorial.body())
          .foregroundStyle(WingmanEditorial.inkSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 2)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// One line of a profile's vitals: a thin line icon and its value. The icon
/// column is fixed so a stack of these aligns down the left edge.
struct EditorialAttributeRow: View {
  var icon: String
  var text: String
  var detail: String?

  init(_ icon: String, _ text: String, detail: String? = nil) {
    self.icon = icon
    self.text = text
    self.detail = detail
  }

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 15, weight: .regular))
        .foregroundStyle(WingmanEditorial.inkSecondary)
        .frame(width: 20, alignment: .leading)

      VStack(alignment: .leading, spacing: 2) {
        Text(text)
          .font(WingmanEditorial.body(15))
          .foregroundStyle(WingmanEditorial.ink)

        if let detail {
          Text(detail)
            .font(WingmanEditorial.body(13))
            .foregroundStyle(WingmanEditorial.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }

      Spacer(minLength: 0)
    }
  }
}

/// A hairline rule inside a card, for separating stacked attribute rows.
struct EditorialDivider: View {
  var body: some View {
    Rectangle()
      .fill(WingmanEditorial.hairline)
      .frame(height: 1)
  }
}

// MARK: - Controls

/// The single filled action on a page: a solid ink pill.
///
/// `enabled: false` is a distinct look rather than the whole pill at reduced
/// opacity — a dimmed black capsule reads as a heavy grey slab, which is the
/// loudest thing on the page precisely when there is nothing to do.
struct EditorialPrimaryButtonStyle: ButtonStyle {
  var enabled = true

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 16, weight: .semibold))
      .foregroundStyle(enabled ? WingmanEditorial.card : WingmanEditorial.inkSecondary.opacity(0.6))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .background {
        if enabled {
          Capsule().fill(WingmanEditorial.ink.opacity(configuration.isPressed ? 0.82 : 1))
        } else {
          Capsule()
            .fill(WingmanEditorial.ground)
            .overlay(Capsule().stroke(WingmanEditorial.hairline, lineWidth: 1))
        }
      }
      .scaleEffect(configuration.isPressed && enabled ? 0.99 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

/// The quieter sibling: a white pill on a hairline.
struct EditorialSecondaryButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(WingmanEditorial.ink)
      .padding(.horizontal, 20)
      .padding(.vertical, 13)
      .background(WingmanEditorial.card, in: Capsule())
      .overlay(Capsule().stroke(WingmanEditorial.hairline, lineWidth: 1))
      .opacity(configuration.isPressed ? 0.7 : 1)
  }
}

/// The round control that floats over a card — the like/skip/copy affordances.
/// White with a hairline by default; `filled` makes it the one solid action in
/// a row of them.
struct EditorialCircleButtonStyle: ButtonStyle {
  var size: CGFloat = 48
  var tint: Color = WingmanEditorial.ink
  var filled = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: size * 0.36, weight: .regular))
      .foregroundStyle(filled ? WingmanEditorial.card : tint)
      .frame(width: size, height: size)
      .background(filled ? WingmanEditorial.ink : WingmanEditorial.card, in: Circle())
      .overlay(
        Circle().stroke(filled ? .clear : WingmanEditorial.hairline, lineWidth: 1)
      )
      .shadow(color: .black.opacity(filled ? 0.14 : 0.06), radius: filled ? 9 : 6, y: 3)
      .scaleEffect(configuration.isPressed ? 0.92 : 1)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}

extension ButtonStyle where Self == EditorialPrimaryButtonStyle {
  static var editorialPrimary: EditorialPrimaryButtonStyle { EditorialPrimaryButtonStyle() }
}

extension ButtonStyle where Self == EditorialSecondaryButtonStyle {
  static var editorialSecondary: EditorialSecondaryButtonStyle { EditorialSecondaryButtonStyle() }
}

extension ButtonStyle where Self == EditorialCircleButtonStyle {
  static func editorialCircle(
    size: CGFloat = 48,
    tint: Color = WingmanEditorial.ink,
    filled: Bool = false
  ) -> EditorialCircleButtonStyle {
    EditorialCircleButtonStyle(size: size, tint: tint, filled: filled)
  }
}

/// The app's own mark, drawn for the light ground: a dark bubble with the
/// cream chevron, rather than the cream-on-coral version the sign-in lockup
/// uses against its gradient.
struct EditorialLockup: View {
  var body: some View {
    HStack(spacing: 9) {
      WingmanMark(bubble: WingmanMark.brandRed, chevron: WingmanMark.creamChevron)
        .frame(height: 27)

      Text("wingman")
        .font(.system(size: 19, weight: .semibold))
        .kerning(-0.3)
        .foregroundStyle(WingmanEditorial.brand)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Wingman")
  }
}
