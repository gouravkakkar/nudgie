import AppKit
import SwiftUI

/// Floats the card in the top-right of the menu-bar screen without ever taking keyboard focus.
final class CardPanelController {
    private var panel: NSPanel?
    private let coordinator: Coordinator

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
        coordinator.onShowCard = { [weak self] in self?.show() }
        coordinator.onHideCard = { [weak self] in self?.hide() }
    }

    func show() {
        hide()
        let size = NSSize(width: CardView.width + CardView.margin * 2, height: CardView.height + CardView.margin * 2)
        // A fresh hosting view each time so the entry wobble replays.
        let hosting = NSHostingView(rootView: CardView(coordinator: coordinator))
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false               // the sticker draws its own
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = hosting

        // screens[0] is the one with the menu bar. Inset the *visible* card 16 pt from the corner.
        if let screen = NSScreen.screens.first {
            let visible = screen.visibleFrame
            let inset = 16 - CardView.margin
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - inset,
                                         y: visible.maxY - size.height - inset))
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
