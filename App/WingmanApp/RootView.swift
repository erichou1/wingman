import SwiftUI

struct RootView: View {
  @Bindable var model: AppModel

  var body: some View {
    TabView(selection: $model.selectedTab) {
      NavigationStack { HomeView(model: model) }
        .tabItem { Label("Wingman", systemImage: "bubble.left.and.bubble.right.fill") }
        .tag("home")

      NavigationStack { ProfileEditorView(model: model) }
        .tabItem { Label("My human", systemImage: "person.crop.circle") }
        .tag("profile")

      NavigationStack { MeetView(model: model) }
        .tabItem { Label("Meet", systemImage: "person.2.fill") }
        .tag("meet")

      NavigationStack { MemoriesView(model: model) }
        .tabItem { Label("Memories", systemImage: "sparkles.square.filled.on.square") }
        .tag("memories")

      NavigationStack { SettingsView(model: model) }
        .tabItem { Label("Privacy", systemImage: "lock.shield.fill") }
        .tag("settings")
    }
    .tint(WingmanPalette.accent)
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
}
