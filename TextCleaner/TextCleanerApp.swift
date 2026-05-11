import SwiftUI

@main
struct TextCleanerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // SwiftUI's App protocol requires a Scene, but the app's UI is driven
        // entirely from AppDelegate: a status item, a floating popup panel,
        // and a custom Settings window. This placeholder scene is never shown.
        Settings { EmptyView() }
    }
}
