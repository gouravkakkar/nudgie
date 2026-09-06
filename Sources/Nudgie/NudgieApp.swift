import SwiftUI

struct NudgieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(coordinator: appDelegate.coordinator)
        } label: {
            Image(systemName: "face.smiling")
                .accessibilityLabel("Nudgie")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            Text("Settings arrive in Task 12").padding(40)
        }
    }
}
