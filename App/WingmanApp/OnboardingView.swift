import SwiftUI
import WingmanCore

struct LoginView: View {
  @Bindable var model: AppModel

  var body: some View {
    ZStack {
      WingmanOnboardingBackground()

      VStack(spacing: 0) {
        Spacer(minLength: 74)

        WingmanLockup()

        Spacer()

        VStack(spacing: 16) {
          Text("The Ultimate Wingman.")
            .font(.system(size: 23, weight: .bold, design: .rounded))
            .foregroundStyle(.white)

          Text("Enter your email to create a private Wingman session on this device.")
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.88))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

          ZStack(alignment: .leading) {
            if model.loginEmail.isEmpty {
              Text("you@example.com")
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
                .allowsHitTesting(false)
            }

            TextField("", text: $model.loginEmail)
              .textInputAutocapitalization(.never)
              .keyboardType(.emailAddress)
              .textContentType(.emailAddress)
              .autocorrectionDisabled()
              .foregroundStyle(.white)
              .tint(.white)
          }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.white.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.92), lineWidth: 1.5))

          Text("By continuing, you agree to the Wingman prototype terms and acknowledge that your profile remains private until you approve what is shared.")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

          Button(action: model.completePrototypeLogin) {
            HStack(spacing: 12) {
              Image(systemName: "envelope.fill")
                .frame(width: 24)
              Text("CONTINUE WITH EMAIL")
                .tracking(1.1)
            }
          }
          .buttonStyle(WingmanOutlineButtonStyle())

          Text("Trouble signing in?")
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.top, 5)
        }
        .padding(.horizontal, 28)

        Spacer(minLength: 38)
      }
    }
    .preferredColorScheme(.dark)
  }
}

struct AgentConnectionView: View {
  @Bindable var model: AppModel

  var body: some View {
    ZStack {
      WingmanPalette.warmCanvas.ignoresSafeArea()

      VStack(alignment: .leading, spacing: 0) {
        Button(action: model.returnToLogin) {
          Image(systemName: "chevron.left")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(WingmanPalette.meshInk)
            .frame(width: 40, height: 40, alignment: .leading)
        }
        .accessibilityLabel("Back to sign in")

        // Fixed, so the title sits under the back control and the slack falls
        // above the action instead of pushing the heading to mid-screen.
        Spacer().frame(height: 26)

        Text("Choose your wingman")
          .font(.system(size: 34, weight: .bold))
          .kerning(-0.8)
          .foregroundStyle(WingmanPalette.meshInk)
          .fixedSize(horizontal: false, vertical: true)

        Text("Connect one AI agent to help you discover people, using only the profile fields you approve.")
          .font(.system(size: 16))
          .foregroundStyle(WingmanPalette.meshInkSecondary)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.top, 10)

        VStack(spacing: 12) {
          ForEach(AgentProvider.onboardingProviders) { provider in
            providerRow(provider)
          }
        }
        .padding(.top, 30)

        Spacer()

        Button(action: model.continueFromAgentSetup) {
          Text("Continue")
        }
        .buttonStyle(WingmanPillButtonStyle())
        .disabled(model.state.connectedAgentProviders.isEmpty)
        .opacity(model.state.connectedAgentProviders.isEmpty ? 0.35 : 1)
      }
      .padding(.horizontal, 26)
      .padding(.top, 8)
      .padding(.bottom, 34)
    }
    .preferredColorScheme(.light)
  }

  private func providerRow(_ provider: AgentProvider) -> some View {
    let isSelected = model.state.connectedAgentProviders.contains(provider)

    return Button {
      model.toggleAgentProvider(provider)
    } label: {
      HStack(spacing: 14) {
        ZStack {
          RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(WingmanPalette.warmCanvas)
          Image(provider == .openAI ? "OpenAILogo" : "ClaudeLogo")
            .resizable()
            .scaledToFit()
            .padding(provider == .openAI ? 9 : 7)
        }
        .frame(width: 44, height: 44)

        VStack(alignment: .leading, spacing: 2) {
          Text(provider == .openAI ? "ChatGPT" : "Claude")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(WingmanPalette.meshInk)
          Text(provider == .openAI ? "by OpenAI" : "by Anthropic")
            .font(.system(size: 14))
            .foregroundStyle(WingmanPalette.meshInkSecondary)
        }

        Spacer(minLength: 0)

        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
          .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
          .foregroundStyle(isSelected ? WingmanPalette.bloom : WingmanPalette.meshInkSecondary.opacity(0.5))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(WingmanPalette.warmSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(isSelected ? WingmanPalette.bloom : WingmanPalette.warmHairline, lineWidth: isSelected ? 1.6 : 1)
      )
    }
    .buttonStyle(.plain)
    .animation(.easeOut(duration: 0.18), value: isSelected)
    .accessibilityLabel("\(isSelected ? "Disconnect" : "Connect") \(provider.title)")
  }
}

private struct WingmanLockup: View {
  var body: some View {
    HStack(spacing: 12) {
      WingmanMark()
        .frame(height: 56)
      Text("wingman")
        .font(.system(size: 48, weight: .heavy, design: .rounded))
        .tracking(-2)
    }
    .foregroundStyle(.white)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Wingman")
  }
}

/// The sign-in ground. Kept on its original coral gradient; the screens after
/// it use `WingmanPalette.warmCanvas` instead.
struct WingmanOnboardingBackground: View {
  var body: some View {
    LinearGradient(
      colors: [
        Color(red: 0.91, green: 0.22, blue: 0.38),
        Color(red: 0.96, green: 0.34, blue: 0.42),
        Color(red: 0.98, green: 0.47, blue: 0.33)
      ],
      startPoint: .bottomLeading,
      endPoint: .topTrailing
    )
    .ignoresSafeArea()
  }
}

struct WingmanOutlineButtonStyle: ButtonStyle {
  var emphasized = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 16, weight: .bold, design: .rounded))
      // Fixed ink, not `WingmanPalette.accent`: this screen pins
      // `.preferredColorScheme(.dark)`, under which the adaptive token resolves
      // to near-white and the label disappears into the white capsule.
      .foregroundStyle(emphasized ? WingmanPalette.meshInk : .white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 17)
      .background(emphasized ? .white : .white.opacity(configuration.isPressed ? 0.18 : 0.08), in: Capsule())
      .overlay(Capsule().stroke(.white, lineWidth: 1.5))
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
  }
}

/// The single primary action on the warm canvas surface: a solid ink pill.
struct WingmanPillButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 17, weight: .semibold))
      .foregroundStyle(WingmanPalette.warmCanvas)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 18)
      .background(WingmanPalette.meshInk.opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
  }
}
