import SwiftUI
import NudgieCore

struct MenuBarView: View {
    let coordinator: Coordinator

    var body: some View {
        // Everything here reads `coordinator.menu`, never the per-second countdown state: see
        // MenuSnapshot for why the menu must not re-render on the heartbeat.
        let menu = coordinator.menu
        Text(menu.statusLabel)
        Divider()
        ForEach(menu.lines) { line in
            Text("\(line.kind.emoji) \(line.kind.title) \(line.text)")
        }
        Text(menu.todayLine)
        Divider()
        Button("Take a break now") { coordinator.takeBreakNow() }
            .disabled(!menu.canTakeBreakNow)
        // Flat, not a "Pause" submenu. A submenu is torn down whenever the NSMenu is rebuilt,
        // and the menu still rebuilds when a countdown line changes, which left the submenu
        // flickering and unclickable. Top-level items survive a rebuild.
        Button("Pause for 1 hour") { coordinator.pause(hours: 1) }
        Button("Pause until tomorrow") { coordinator.pauseUntilTomorrow() }
        Button("Resume") { coordinator.resume() }
        Divider()
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Button("Quit Nudgie") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    static func dueText(_ seconds: Double) -> String {
        if seconds <= 0 { return "now" }
        let minutes = Int((seconds / 60).rounded(.up))
        return minutes <= 1 ? "in 1 min" : "in \(minutes) min"
    }
}
