import AppKit
import NudgieCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = Coordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator.start(demo: Self.demoKind())
    }

    /// `Nudgie --demo eyes` shows a card for that reminder right away.
    static func demoKind() -> ReminderKind? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--demo"), args.indices.contains(i + 1) else { return nil }
        return ReminderKind(rawValue: args[i + 1])
    }
}
