import SwiftUI
import UIKit
import WingmanCore

struct RootView: View {
  @Bindable var model: AppModel

  var body: some View {
    Group {
      switch model.state.onboardingRoute {
      case .login:
        LoginView(model: model)
      case .connectAgent:
        AgentConnectionView(model: model)
      case .importingChatGPT:
        ChatGPTCrawlView(context: model.chatGPTContext) { model.completeChatGPTImport() }
      case .app:
        appTabs
      }
    }
    .alert(
      "Wingman needs attention",
      isPresented: Binding(
        get: { model.lastError != nil },
        set: { if !$0 { model.lastError = nil } }
      )
    ) {
      Button("OK") { model.lastError = nil }
    } message: {
      Text(model.lastError ?? "Unknown error")
    }
  }

  private var appTabs: some View {
    // The mark sits dead centre and the four outline glyphs flank it two a
    // side, so the logo anchors the bar rather than starting it. Home is still
    // the landing tab — `selectedTab` defaults to it — it just is not leftmost.
    TabView(selection: $model.selectedTab) {
      NavigationStack { MeetView(model: model) }
        .tabItem { Label { Text("Meet") } icon: { outlineIcon("heart") } }
        .tag("meet")

      NavigationStack { ConnectionsView(model: model) }
        .tabItem { Label { Text("Connections") } icon: { outlineIcon("person.2") } }
        .tag("connections")

      NavigationStack { HomeView(model: model) }
        .tabItem {
          Label {
            Text("Wingman")
          } icon: {
            if let mark = WingmanMark.tabIcon {
              Image(uiImage: mark)
            } else {
              Image(systemName: "bubble.left.and.bubble.right")
            }
          }
        }
        .tag("home")

      NavigationStack { ProfileEditorView(model: model) }
        .tabItem { Label { Text("My human") } icon: { outlineIcon("person") } }
        .tag("profile")

      NavigationStack { SettingsView(model: model) }
        .tabItem { Label { Text("Privacy") } icon: { outlineIcon("lock") } }
        .tag("settings")
    }
    .tint(WingmanEditorial.brand)
    .onAppear(perform: applyTabBarAppearance)
  }

  /// A symbol at a light weight, kept as an outline.
  ///
  /// `Label(systemImage:)` alone is not enough: the tab bar substitutes the
  /// filled variant of every symbol, which reads far heavier than the line icons
  /// this bar is modelled on. Building the `UIImage` directly opts out of that
  /// substitution, since the variant is resolved before UIKit sees it.
  private func outlineIcon(_ name: String) -> Image {
    let configuration = UIImage.SymbolConfiguration(pointSize: 21, weight: .light)
    guard let symbol = UIImage(systemName: name, withConfiguration: configuration) else {
      return Image(systemName: name)
    }
    return Image(uiImage: symbol.withRenderingMode(.alwaysTemplate))
  }

  /// The tab bar is UIKit, so it does not pick up the pages' warm ground on its
  /// own — left alone it renders as a translucent grey shelf under an off-white
  /// page. Opaque, warm, and separated by the same hairline the cards use.
  private func applyTabBarAppearance() {
    let appearance = UITabBarAppearance()
    appearance.configureWithOpaqueBackground()
    appearance.backgroundColor = UIColor(WingmanEditorial.ground)
    appearance.shadowColor = UIColor(WingmanEditorial.hairline)

    UITabBar.appearance().standardAppearance = appearance
    UITabBar.appearance().scrollEdgeAppearance = appearance
  }
}
