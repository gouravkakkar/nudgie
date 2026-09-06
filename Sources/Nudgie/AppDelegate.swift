import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon, even when run straight from .build without a bundle.
        NSApp.setActivationPolicy(.accessory)
    }
}
