import SwiftUI
import WingmanCore

@main
struct WingmanApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    WindowGroup {
      RootView(model: model)
        .tint(WingmanPalette.accent)
    }
  }
}
