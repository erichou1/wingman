import SwiftUI
import UIKit
import WingmanCore

/// One entry in the Home deck, flattened so the card does not care whether it
/// came from a real candidate in shared state or from the demo roster below.
struct SwipeCandidate: Identifiable, Equatable {
  let id: UUID
  let name: String
  let openTo: String
  let blurb: String
  let tags: [String]
  /// Asset-catalog name for the portrait, or nil to fall back to a monogram.
  let artwork: String?
  /// False for roster fillers, which exist to give the deck something to swipe
  /// during a demo and are not people the app can actually introduce.
  let isRealCandidate: Bool

  /// A real candidate takes its words from the shared profile and its surface
  /// (full name, tags, portrait) from the roster, keyed on first name. That
  /// keeps card-only presentation out of `HumanProfile`, which the gateway and
  /// the Messages extension also read.
  init(profile: ApprovedProfile) {
    let detail = DemoRoster.detail(for: profile.displayName)
    id = profile.id
    name = detail?.fullName ?? profile.displayName
    openTo = profile.lookingFor.map(\.title).sorted().joined(separator: " · ")
    blurb = profile.bio ?? ""
    tags = detail?.tags ?? []
    artwork = detail?.artwork
    isRealCandidate = true
  }

  init(id: UUID, name: String, openTo: String, blurb: String, tags: [String], artwork: String?) {
    self.id = id
    self.name = name
    self.openTo = openTo
    self.blurb = blurb
    self.tags = tags
    self.artwork = artwork
    isRealCandidate = false
  }
}

/// Filler people for the swipe demo — public figures, played for laughs.
///
/// The bios are obvious parody rather than claims of fact, which is the line
/// that matters when the face belongs to a real person. Fine for a local demo;
/// see the note in the deck's docs before this goes anywhere public, since the
/// photographs themselves are press images somebody else owns.
enum DemoRoster {
  /// Card-only presentation for someone in the demo, keyed on their first name.
  struct Detail {
    let fullName: String
    let tags: [String]
    var artwork: String? { DemoRoster.asset("Persona" + fullName.split(separator: " ")[0]) }
  }

  private static let details: [String: Detail] = [
    "evan": Detail(
      fullName: "Evan Zhao",
      tags: ["#CameraAngleOptimizer", "#VoidStare", "#3AMComfiles", "#LowAngleEnergy"]
    ),
    "eric": Detail(
      fullName: "Eric Hou",
      tags: ["#SnoopyDrip", "#ZeroLatency", "#MergeConflictAvoider", "#PairProgramming"]
    ),
    "julian": Detail(
      fullName: "Julian Juan",
      tags: ["#MainCharacterEnergy", "#MVPOrBust", "#APISwap", "#ThinkingAboutCatering"]
    ),
  ]

  static func detail(for firstName: String) -> Detail? {
    details[firstName.trimmingCharacters(in: .whitespaces).lowercased()]
  }

  /// Portrait lookup by first name, so anything outside the deck (Connections,
  /// the match reveal) can show the same face without going through
  /// `SwipeCandidate`.
  static func artwork(forName name: String) -> String? {
    detail(for: name)?.artwork ?? asset("Persona" + name.trimmingCharacters(in: .whitespaces))
  }

  static let people: [SwipeCandidate] = [
    SwipeCandidate(
      id: UUID(uuidString: "D3305000-0000-4000-A000-0000000000A1")!,
      name: "Elon Musk",
      openTo: "Dating · New connection",
      blurb:
        "420-friendly, space-obsessed, and currently restructuring my entire life’s roadmap live on stream. Swipe right if you’re ready to ship feature updates at 3 AM.",
      tags: ["#OccupyingMars", "#HardcoreMode", "#ProductionDeployAtMidnight", "#ShipIt"],
      artwork: asset("PersonaElon")
    ),
    SwipeCandidate(
      id: UUID(uuidString: "D3305000-0000-4000-A000-0000000000A2")!,
      name: "Sam Altman",
      openTo: "New connection",
      blurb:
        "Pitching my next billion-dollar idea while mildly panicking inside. If you like high valuations and questionable server uptime, swipe right.",
      tags: ["#SeriesAorBust", "#ServerStatus500", "#PitchDeckEnergy", "#AGIWhen"],
      artwork: asset("PersonaSam")
    ),
    SwipeCandidate(
      id: UUID(uuidString: "D3305000-0000-4000-A000-0000000000A3")!,
      name: "Donald Trump",
      openTo: "Community",
      blurb:
        "I build the best projects — tremendous code, really, nobody’s ever seen anything like it. Everyone says so. Swipe right to make hackathons great again.",
      tags: ["#TremendousCode", "#HugeMVP", "#MakeHackathonsGreatAgain", "#WinnerStatus"],
      artwork: asset("PersonaDonald")
    ),
  ]

  /// nil when the imageset is not in the catalog, so a missing file falls back
  /// to the monogram tile instead of rendering an empty card.
  static func asset(_ name: String) -> String? {
    UIImage(named: name) != nil ? name : nil
  }
}

// MARK: - The card

/// A profile the Hinge way: the picture is the card, and the words sit on it.
struct SwipeProfileCard: View {
  let candidate: SwipeCandidate
  let recommender: String
  let translation: CGSize

  var body: some View {
    ZStack(alignment: .bottomLeading) {
      artwork

      // Scrim, so white type stays readable over whatever the artwork does
      // down there. Starts below halfway — any higher and it dims the face.
      LinearGradient(
        colors: [.black.opacity(0), .black.opacity(0.35), .black.opacity(0.82)],
        startPoint: UnitPoint(x: 0.5, y: 0.42),
        endPoint: .bottom
      )

      caption
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .stroke(WingmanEditorial.hairline, lineWidth: 1)
    )
    .overlay(alignment: .topLeading) { recommendedChip }
    .overlay(alignment: .topLeading) {
      stamp("Like", tint: WingmanEditorial.brand, showing: translation.width > 0)
    }
    .overlay(alignment: .topTrailing) {
      stamp("Nope", tint: .white, showing: translation.width < 0)
    }
    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
    .offset(x: translation.width, y: translation.height)
    .rotationEffect(.degrees(Double(translation.width / 24)), anchor: .bottom)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(candidate.name), recommended by \(recommender). \(candidate.blurb)")
  }

  /// `Color.clear` carries the layout and the portrait rides as a clipped
  /// overlay. A bare `scaledToFill` image reports its own oversized ideal width
  /// to the parent, which pushed the card — and with it the whole screen —
  /// wider than the display.
  @ViewBuilder
  private var artwork: some View {
    if let name = candidate.artwork, let source = UIImage(named: name) {
      // A landscape photo in a portrait card: filling would throw away more
      // than half the width and leave a face cropped to a sliver. Fit it over
      // a blurred copy of itself instead, held high so the caption lands on
      // the blur rather than on the subject.
      //
      // Both layers are overlays on `Color.clear` rather than siblings in a
      // ZStack. Overlay content is proposed its parent's size and can never
      // change it, whereas the blurred `.fill` layer as a ZStack child sized
      // the stack past the card — and the "fitted" image then fitted to *that*,
      // which is why it still came out zoomed.
      let isLandscape = source.size.width > source.size.height

      Color.clear
        .overlay {
          Image(name)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .blur(radius: isLandscape ? 30 : 0)
            // Oversized, because a blur samples past its own edges and would
            // otherwise leave a pale rim inside the card.
            .scaleEffect(isLandscape ? 1.15 : 1)
        }
        .overlay(alignment: .top) {
          if isLandscape {
            Image(name)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .padding(.top, 52)
          }
        }
        .clipped()
    } else {
      ZStack {
        WingmanEditorial.ground
        Text(monogram)
          .font(WingmanEditorial.answer(96, .semibold))
          .foregroundStyle(WingmanEditorial.accent.opacity(0.55))
      }
    }
  }

  private var caption: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(candidate.name)
        .font(.system(size: 31, weight: .bold))
        .kerning(-0.5)
        .foregroundStyle(.white)

      if !candidate.openTo.isEmpty {
        Text(candidate.openTo)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.white.opacity(0.82))
      }

      if !candidate.blurb.isEmpty {
        Text(candidate.blurb)
          .font(WingmanEditorial.answer(15))
          .foregroundStyle(.white.opacity(0.94))
          .lineSpacing(3)
          .lineLimit(6)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 3)
      }

      if !candidate.tags.isEmpty {
        WingmanFlowLayout(spacing: 6) {
          ForEach(candidate.tags, id: \.self) { tag in
            Text(tag)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.white)
              .padding(.horizontal, 9)
              .padding(.vertical, 5)
              .background(.white.opacity(0.22), in: Capsule())
              .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 1))
          }
        }
        .padding(.top, 9)
      }
    }
    .padding(22)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var recommendedChip: some View {
    Text("Recommended by \(recommender)".uppercased())
      .font(.system(size: 10, weight: .semibold))
      .tracking(1.1)
      .foregroundStyle(WingmanEditorial.ink)
      .padding(.horizontal, 11)
      .padding(.vertical, 6)
      .background(.white.opacity(0.92), in: Capsule())
      .padding(16)
  }

  /// The drag verdict. Held back until the card commits to a direction so a
  /// stray horizontal wobble does not flash it.
  private func stamp(_ text: String, tint: Color, showing: Bool) -> some View {
    let progress = min(1, max(0, (abs(translation.width) - 20) / 80))

    return Text(text.uppercased())
      .font(.system(size: 17, weight: .heavy))
      .tracking(2)
      .foregroundStyle(tint)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(tint, lineWidth: 3))
      .rotationEffect(.degrees(text == "Like" ? -14 : 14))
      .padding(22)
      .opacity(showing ? progress : 0)
  }

  private var monogram: String {
    String(candidate.name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
  }
}

// MARK: - The rail

/// A pass/like control that answers the drag: it grows and fills with its own
/// colour as the card commits, so the buttons and the card say the same thing
/// at the same time.
struct SwipeActionButton: View {
  let icon: String
  let tint: Color
  /// 0 when the card is at rest, 1 once the drag has clearly committed here.
  let progress: Double
  let size: CGFloat
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: icon)
        .font(.system(size: size * 0.38, weight: .medium))
        .foregroundStyle(progress > 0.5 ? .white : tint)
        .frame(width: size, height: size)
        .background(
          Circle().fill(WingmanEditorial.card)
            .overlay(Circle().fill(tint).opacity(progress))
        )
        .overlay(Circle().stroke(tint.opacity(0.25 + progress * 0.75), lineWidth: 1.5))
        .shadow(color: tint.opacity(0.15 + progress * 0.35), radius: 8 + progress * 8, y: 4)
        .scaleEffect(1 + progress * 0.18)
    }
    .buttonStyle(.plain)
    .animation(.spring(response: 0.28, dampingFraction: 0.7), value: progress)
  }
}

// MARK: - Match

/// The reveal when two agents agree. Shown only where the demo actually has a
/// second real account behind it (see `HomeView.isMatch`), never for roster
/// fillers — a fake match would be the one moment in this app that lies.
///
/// Choreographed in beats rather than on one `appeared` flag. Everything
/// arriving together on a single spring is what made the old version read as
/// generated: the portraits slid in and stopped, nothing answered them, and
/// half a second later the screen was a still image. The two apps this is
/// measured against both do the same three things — throw the photos, make the
/// landing *land*, then keep the ground alive underneath. So: the cards are
/// flung in with enough overshoot to read as thrown, contact fires a haptic and
/// a burst, the headline climbs out from behind that contact a word at a time,
/// and once it settles the blooms drift and the badge keeps a pulse.
struct MatchRevealView: View {
  let candidate: SwipeCandidate
  let yourName: String
  var onDismiss: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The beats, one flag each rather than a single phase enum, so a late beat
  /// can start while an earlier one is still settling — the buttons begin
  /// rising while the badge is still overshooting, which is what keeps the
  /// sequence from feeling stepped through.
  @State private var groundIn = false
  @State private var portraitsIn = false
  @State private var impact = false
  @State private var heartIn = false
  @State private var titleIn = false
  @State private var subtitleIn = false
  @State private var buttonsIn = false
  /// Flipped once at the end; drives every `repeatForever` on the screen.
  @State private var ambient = false
  /// Bumped at contact. Only exists to trigger the haptic.
  @State private var contact = 0
  @State private var copied = false

  private let titleWords = ["It’s", "a", "match"]

  var body: some View {
    ZStack {
      MatchGround(open: groundIn, ambient: ambient)

      VStack(spacing: 0) {
        Spacer(minLength: 12)

        headline
        subtitle
        stage.padding(.top, 38)

        Spacer(minLength: 12)

        suggestion
          .padding(.horizontal, 28)
          .padding(.bottom, 16)

        actions
      }
    }
    // The thump at contact, then a lighter tick when the badge lands on top of
    // it. Two beats a fifth of a second apart, not one buzz.
    .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: contact)
    .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: heartIn)
    .task { await run() }
  }

  // MARK: Choreography

  /// The beat sheet. Written as one timeline instead of scattered `asyncAfter`
  /// calls so the offsets are readable as rhythm, and cancelled for free when
  /// the screen goes away.
  private func run() async {
    guard !reduceMotion else {
      // No entrance at all: the screen is simply already composed. A shortened
      // version of the same motion is still motion.
      groundIn = true
      portraitsIn = true
      heartIn = true
      titleIn = true
      subtitleIn = true
      buttonsIn = true
      return
    }

    withAnimation(.easeOut(duration: 0.34)) { groundIn = true }

    await beat(0.06)
    // Deliberately underdamped: the cards swing past their resting offsets and
    // come back. That overshoot is the difference between thrown and tweened.
    withAnimation(.spring(response: 0.52, dampingFraction: 0.58)) { portraitsIn = true }

    await beat(0.36)  // contact
    contact += 1
    impact = true

    await beat(0.08)
    withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) { heartIn = true }

    await beat(0.04)
    titleIn = true  // per-word delays live on the words

    await beat(0.2)
    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { subtitleIn = true }

    await beat(0.1)
    withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { buttonsIn = true }

    await beat(0.24)
    ambient = true
  }

  private func beat(_ seconds: Double) async {
    try? await Task.sleep(for: .seconds(seconds))
  }

  // MARK: Type

  /// The words climb out from behind a hard edge one after the other, rather
  /// than the whole line fading up together. Clipped to the line's own bounds,
  /// which is what makes it read as a reveal instead of a slide.
  private var headline: some View {
    HStack(spacing: 11) {
      ForEach(Array(titleWords.enumerated()), id: \.offset) { index, word in
        Text(word)
          .font(.system(size: 42, weight: .bold, design: .serif))
          .foregroundStyle(.white)
          .offset(y: titleIn ? 0 : 62)
          .animation(
            reduceMotion
              ? nil
              : .spring(response: 0.68, dampingFraction: 0.78).delay(Double(index) * 0.075),
            value: titleIn
          )
      }
    }
    .clipped()
  }

  /// Why the agents put these two together, in one line. "Both said yes" is
  /// just the mechanic restated — the interesting part of this product is that
  /// something had a reason, so the reason is what goes here.
  private var subtitle: some View {
    Text(MatchReason.line(for: candidate.name))
      .font(.system(size: 16))
      .foregroundStyle(.white.opacity(0.9))
      .multilineTextAlignment(.center)
      .padding(.horizontal, 34)
      .padding(.top, 10)
      .opacity(subtitleIn ? 1 : 0)
      .offset(y: subtitleIn ? 0 : 12)
  }

  // MARK: The stage

  private var stage: some View {
    ZStack {
      portrait(asset: DemoRoster.artwork(forName: yourName), monogram: initial(of: yourName))
        .offset(x: portraitsIn ? -46 : -280)
        .rotationEffect(.degrees(portraitsIn ? -6 : -30))
        .offset(y: ambient ? -5 : 5)
        .animation(drift(6.5), value: ambient)

      portrait(asset: candidate.artwork, monogram: initial(of: candidate.name))
        .offset(x: portraitsIn ? 46 : 280)
        .rotationEffect(.degrees(portraitsIn ? 6 : 30))
        .offset(y: ambient ? 5 : -5)
        .animation(drift(7.4), value: ambient)

      // Inserted at contact rather than animated from a resting state, so its
      // keyframes run once, on appearance, and it cannot flash beforehand.
      if impact {
        ImpactBurst().offset(y: 74)
      }

      heart.offset(y: 74)
    }
  }

  private func portrait(asset: String?, monogram: String) -> some View {
    Group {
      if let asset {
        Image(asset).resizable().aspectRatio(contentMode: .fill)
      } else {
        ZStack {
          Color.white.opacity(0.22)
          Text(monogram)
            .font(.system(size: 46, weight: .semibold, design: .serif))
            .foregroundStyle(.white)
        }
      }
    }
    .frame(width: 132, height: 168)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(.white, lineWidth: 3)
    )
    .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
  }

  private var heartBadge: some View {
    Image(systemName: "heart.fill")
      .font(.system(size: 30))
      .foregroundStyle(WingmanEditorial.brand)
      .padding(14)
      .background(Circle().fill(.white))
      .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
      .scaleEffect(heartIn ? 1 : 0)
      .rotationEffect(.degrees(heartIn ? 0 : -70))
  }

  /// A real double-beat once it has landed — two quick squeezes and a long
  /// relax, not a symmetrical throb. Held back under Reduce Motion, where an
  /// endlessly pulsing element is precisely the thing being asked for less of.
  @ViewBuilder
  private var heart: some View {
    if reduceMotion {
      heartBadge
    } else {
      heartBadge.phaseAnimator(HeartPhase.allCases) { badge, phase in
        badge.scaleEffect(phase.scale)
      } animation: { phase in
        phase.animation
      }
    }
  }

  // MARK: Actions

  /// The line Wingman actually recommends, hard-coded on purpose: at this exact
  /// moment the demo needs a punchline, and a generated opener here is the
  /// difference between a laugh and a loading spinner.
  static let recommendedOpener =
    "Our agents talked for four minutes and the only thing they agreed on was lunch. I’m free Saturday if you want to settle tacos versus burritos in person."

  private var suggestion: some View {
    VStack(alignment: .leading, spacing: 9) {
      Text("YOUR WINGMAN SUGGESTS")
        .font(.system(size: 10, weight: .semibold))
        .tracking(1.2)
        .foregroundStyle(.white.opacity(0.75))

      Text(Self.recommendedOpener)
        .font(.system(size: 16, design: .serif))
        .foregroundStyle(.white)
        .lineSpacing(4)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(18)
    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(.white.opacity(0.3), lineWidth: 1)
    )
    .opacity(buttonsIn ? 1 : 0)
    .offset(y: buttonsIn ? 0 : 26)
  }

  private var actions: some View {
    VStack(spacing: 12) {
      Button {
        UIPasteboard.general.string = Self.recommendedOpener
        withAnimation(.easeOut(duration: 0.18)) { copied = true }
      } label: {
        Text(copied ? "Copied — go send it" : "Copy this line")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(WingmanEditorial.brand)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(Capsule().fill(.white))
          .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
      }
      .opacity(buttonsIn ? 1 : 0)
      .offset(y: buttonsIn ? 0 : 26)

      Button(action: onDismiss) {
        Text("Keep swiping")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .overlay(Capsule().stroke(.white.opacity(0.6), lineWidth: 1.5))
      }
      .opacity(buttonsIn ? 1 : 0)
      .offset(y: buttonsIn ? 0 : 26)
      // The pair rises as one gesture with a beat between them, rather than
      // as one block.
      .animation(
        reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.82).delay(0.07),
        value: buttonsIn
      )
    }
    .padding(.horizontal, 28)
    .padding(.bottom, 40)
  }

  // MARK: Helpers

  private func drift(_ duration: Double) -> Animation {
    .easeInOut(duration: duration).repeatForever(autoreverses: true)
  }

  private func initial(of name: String) -> String {
    String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
  }
}

/// The one line the reveal gives for why these two were put together.
///
/// The joke is on the agents, not on either person. That is the honest place
/// for it: the app's actual claim is that two bots compared notes and reached a
/// conclusion, and a line at their expense lands without inventing a fact about
/// a human that no profile supports. Anyone without a line falls back to the
/// plain statement of what happened rather than to a guess.
private enum MatchReason {
  private static let lines: [String: String] = [
    "julian": "Your agents hit it off. You two should try."
  ]

  static func line(for name: String) -> String {
    let key = name.trimmingCharacters(in: .whitespaces).split(separator: " ").first?.lowercased()
    if let key, let line = lines[String(key)] { return line }
    return "You and \(name) both said yes."
  }
}

/// Deterministic 0…1 from an index. Not `Double.random`, which would reshuffle
/// every particle on each body evaluation and make the burst crawl.
private func matchJitter(_ index: Int) -> CGFloat {
  let x = sin(Double(index) * 12.9898 + 78.233) * 43758.5453
  return CGFloat(x - x.rounded(.down))
}

/// The ground: a deep brand gradient with two soft blooms drifting across it at
/// different speeds, plus a vignette so the corners stop competing with the
/// type. The drift is the whole point — one static radial wash behind centred
/// content is the surest tell that a screen was generated rather than designed.
///
/// Everything rides as an overlay on the gradient rather than as sibling layers:
/// the blooms are wider than the phone, and as ZStack children they sized the
/// stack and pushed the button column past both edges.
private struct MatchGround: View {
  var open: Bool
  var ambient: Bool

  private static let lift = Color(red: 1.00, green: 0.44, blue: 0.43)
  private static let deep = Color(red: 0.72, green: 0.09, blue: 0.28)

  var body: some View {
    LinearGradient(
      colors: [Self.lift, WingmanEditorial.brand, Self.deep],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .overlay { blooms }
    .overlay { motes }
    .overlay { vignette }
    .ignoresSafeArea()
  }

  private var blooms: some View {
    ZStack {
      bloom(size: 460, opacity: 0.16, blur: 60)
        .offset(x: ambient ? -60 : -110, y: ambient ? -230 : -160)
        .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: ambient)

      bloom(size: 380, opacity: 0.10, blur: 70)
        .offset(x: ambient ? 130 : 70, y: ambient ? 210 : 280)
        .animation(.easeInOut(duration: 9.5).repeatForever(autoreverses: true), value: ambient)
    }
  }

  private func bloom(size: CGFloat, opacity: Double, blur: CGFloat) -> some View {
    Circle()
      .fill(.white.opacity(opacity))
      .frame(width: size, height: size)
      .blur(radius: blur)
      .scaleEffect(open ? 1 : 0.45)
  }

  /// A few slow specks. Low enough to register as air rather than as snow.
  private var motes: some View {
    ZStack {
      ForEach(0..<9, id: \.self) { i in
        let size = 4 + matchJitter(i + 40) * 7

        Circle()
          .fill(.white.opacity(0.10 + Double(matchJitter(i)) * 0.12))
          .frame(width: size, height: size)
          .offset(
            x: (matchJitter(i + 7) - 0.5) * 330,
            y: (matchJitter(i + 19) - 0.5) * 620 + (ambient ? -36 : 36)
          )
          .animation(
            .easeInOut(duration: 6 + Double(matchJitter(i + 3)) * 5)
              .repeatForever(autoreverses: true),
            value: ambient
          )
      }
    }
    .opacity(open ? 1 : 0)
  }

  private var vignette: some View {
    RadialGradient(
      colors: [.clear, .black.opacity(0.26)],
      center: .center,
      startRadius: 170,
      endRadius: 480
    )
  }
}

/// One frame of the impact, as a bag of animatable numbers for the keyframe
/// tracks to drive independently — the rings are still expanding well after
/// their opacity has gone, which is what makes the burst dissipate rather than
/// switch off.
private struct BurstFrame {
  var ring: CGFloat = 0.2
  var ringOpacity: Double = 0
  var spread: CGFloat = 0
  var sparkOpacity: Double = 0
}

/// The consequence of the landing: two rings pushed out of the contact point at
/// different speeds, and a single throw of sparks. Under a second, then nothing
/// — a burst that lingers turns a moment into a screensaver.
///
/// Mounted at the instant of contact, so its keyframes run once on appearance
/// and there is no resting state to leak beforehand.
private struct ImpactBurst: View {
  var body: some View {
    ZStack {
      ring(width: 2.5, to: 2.8, delay: 0)
      ring(width: 1.2, to: 2.0, delay: 0.1)
      sparks
    }
    .allowsHitTesting(false)
  }

  private func ring(width: CGFloat, to maxScale: CGFloat, delay: Double) -> some View {
    // `repeating` defaults to true on this initialiser, which loops the burst
    // for as long as the screen is up. A shockwave that fires every second is
    // a loading spinner, not an impact.
    KeyframeAnimator(initialValue: BurstFrame(), repeating: false) { frame in
      Circle()
        .stroke(.white.opacity(frame.ringOpacity), lineWidth: width)
        .frame(width: 92, height: 92)
        .scaleEffect(frame.ring)
    } keyframes: { _ in
      KeyframeTrack(\.ring) {
        LinearKeyframe(0.2, duration: delay)
        SpringKeyframe(maxScale, duration: 0.85, spring: .snappy)
      }
      KeyframeTrack(\.ringOpacity) {
        LinearKeyframe(0, duration: delay)
        LinearKeyframe(0.8, duration: 0.06)
        CubicKeyframe(0, duration: 0.72)
      }
    }
  }

  private var sparks: some View {
    KeyframeAnimator(initialValue: BurstFrame(), repeating: false) { frame in
      ZStack {
        ForEach(0..<14, id: \.self) { i in
          Capsule()
            .fill(.white.opacity(frame.sparkOpacity))
            .frame(width: 2.5, height: 10 + matchJitter(i) * 11)
            .offset(y: -(50 + frame.spread * (56 + matchJitter(i + 11) * 34)))
            .rotationEffect(.degrees(Double(i) / 14 * 360))
        }
      }
    } keyframes: { _ in
      KeyframeTrack(\.spread) {
        SpringKeyframe(1, duration: 0.7, spring: .snappy)
      }
      KeyframeTrack(\.sparkOpacity) {
        LinearKeyframe(0.9, duration: 0.08)
        CubicKeyframe(0, duration: 0.5)
      }
    }
  }
}

/// The badge's resting pulse: squeeze, release, smaller squeeze, long relax.
/// A single symmetrical throb reads mechanical; this one reads like a pulse
/// because the two contractions are uneven and the gap after them is long.
private enum HeartPhase: CaseIterable {
  case lub, release, dub, relax

  var scale: CGFloat {
    switch self {
    case .lub: 1.13
    case .release: 1.0
    case .dub: 1.06
    case .relax: 1.0
    }
  }

  var animation: Animation {
    switch self {
    case .lub: .easeOut(duration: 0.11)
    case .release: .easeInOut(duration: 0.12)
    case .dub: .easeOut(duration: 0.1)
    case .relax: .easeInOut(duration: 1.15)
    }
  }
}
