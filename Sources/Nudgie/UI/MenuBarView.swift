import SwiftUI
import NudgieCore

struct MenuBarView: View {
    let coordinator: Coordinator

    var body: some View {
        Text(coordinator.status.label)
        Divider()
        ForEach(coordinator.nextUp, id: \.kind) { item in
            Text("\(item.kind.emoji) \(item.kind.title) \(Self.dueText(item.seconds))")
        }
        Text("Today: \(coordinator.today.taken) breaks taken, \(coordinator.today.snoozed) snoozed")
        Divider()
        Button("Take a break now") { coordinator.takeBreakNow() }
            .disabled(coordinator.card != nil || coordinator.nextUp.isEmpty)
        Menu("Pause") {
            Button("For 1 hour") { coordinator.pause(hours: 1) }
            Button("Until tomorrow") { coordinator.pauseUntilTomorrow() }
            Button("Resume") { coordinator.resume() }
        }
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
