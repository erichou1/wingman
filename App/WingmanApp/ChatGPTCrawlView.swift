import SwiftUI
import WingmanCore

/// The ChatGPT import screen, shown once a person connects ChatGPT.
///
/// Deliberately quiet: one blooming mark, one line of text at a time, and the
/// findings only at the end. The stage names are the real pipeline from
/// `docs/CHATGPT_CONTEXT_CRAWL.md` in order, so when the ingest lands it reports
/// into this same sequence.
struct ChatGPTCrawlView: View {
  let context: ChatGPTContextPacket
  var onFinish: () -> Void

  @State private var stageIndex = 0
  @State private var isComplete = false

  private let stages = [
    "Opening your conversations",
    "Following each thread",
    "Keeping only what you wrote",
    "Reading your instructions",
    "Noticing what you return to",
    "Shaping your agent card",
  ]

  var body: some View {
    ZStack {
      WingmanPalette.warmCanvas.ignoresSafeArea()

      VStack(spacing: 0) {
        Spacer()

        PetalBloom(isSettled: isComplete)

        Spacer().frame(height: 30)

        if isComplete {
          completion
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
          Text(stages[min(stageIndex, stages.count - 1)])
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(WingmanPalette.meshInk)
            .multilineTextAlignment(.center)
            .id(stageIndex)
            .transition(.opacity)
        }

        Spacer()

        if isComplete {
          Button(action: onFinish) {
            Text("Continue")
          }
          .buttonStyle(WingmanPillButtonStyle())
          .padding(.horizontal, 26)
          .padding(.bottom, 34)
          .transition(.opacity)
        }
      }
    }
    .preferredColorScheme(.light)
    .task { await run() }
  }

  private var completion: some View {
    VStack(spacing: 18) {
      Text("Your agent card is ready")
        .font(.system(size: 24, weight: .bold))
        .kerning(-0.5)
        .foregroundStyle(WingmanPalette.meshInk)

      Text("\(context.conversationCount) conversations · \(context.topics.count) themes")
        .font(.system(size: 15))
        .foregroundStyle(WingmanPalette.meshInkSecondary)

      VStack(spacing: 8) {
        ForEach(context.topics.prefix(3), id: \.name) { topic in
          Text(topic.name)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(WingmanPalette.meshInk)
            .lineLimit(1)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
              Capsule().stroke(WingmanPalette.warmHairline, lineWidth: 1)
            )
        }
      }
      .padding(.top, 4)

      Text("Nothing here reaches another person until you approve it.")
        .font(.system(size: 13))
        .foregroundStyle(WingmanPalette.meshInkSecondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 4)
    }
    .padding(.horizontal, 34)
  }

  private func run() async {
    for index in stages.indices {
      withAnimation(.easeInOut(duration: 0.35)) { stageIndex = index }
      try? await Task.sleep(for: .milliseconds(900))
    }
    withAnimation(.easeInOut(duration: 0.55)) { isComplete = true }
  }
}

/// Six translucent petals overlapping into a rosette, breathing in sequence
/// around one slow rotation.
///
/// The petals are deliberately large enough to overlap at the centre: the
/// darker core is the overlap itself, not a drawn shape, which is what makes it
/// read as a flower rather than a spinner.
private struct PetalBloom: View {
  var isSettled: Bool

  @State private var isOpen = false
  @State private var spin = false

  private let petalCount = 6

  var body: some View {
    ZStack {
      ForEach(0..<petalCount, id: \.self) { index in
        Ellipse()
          .fill(WingmanPalette.bloom.opacity(0.48))
          .frame(width: 64, height: 106)
          .offset(y: -26)
          .scaleEffect(isSettled ? 1.02 : (isOpen ? 1 : 0.8))
          .rotationEffect(.degrees(Double(index) / Double(petalCount) * 360))
          .animation(petalAnimation(index), value: isOpen)
          .animation(.easeOut(duration: 0.7), value: isSettled)
      }
    }
    .frame(width: 158, height: 158)
    .rotationEffect(.degrees(spin ? 360 : 0))
    .animation(
      isSettled ? .easeOut(duration: 1.0) : .linear(duration: 11).repeatForever(autoreverses: false),
      value: spin
    )
    .onAppear {
      isOpen = true
      spin = true
    }
  }

  /// Each petal lags the one before it, which is what turns six identical
  /// shapes into a bloom travelling around the circle.
  private func petalAnimation(_ index: Int) -> Animation {
    .easeInOut(duration: 1.5)
      .repeatForever(autoreverses: true)
      .delay(Double(index) * 0.13)
  }
}

#Preview {
  ChatGPTCrawlView(context: DemoAccounts.eric.chatGPTContext, onFinish: {})
}
