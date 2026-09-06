import AppKit
import CoreGraphics
import NudgieCore

/// Idle time from CoreGraphics; lock and sleep from system notifications.
final class ActivityProbe: ActivitySampling {
    private(set) var isLocked = false
    private(set) var isAsleep = false
    private var tokens: [NSObjectProtocol] = []

    init() {
        let dnc = DistributedNotificationCenter.default()
        tokens.append(dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.isLocked = true }
        })
        tokens.append(dnc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.isLocked = false }
        })
        let wnc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            tokens.append(wnc.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { self.isAsleep = true }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            tokens.append(wnc.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { self.isAsleep = false }
            })
        }
    }

    /// Seconds since the last keyboard or mouse event, any type.
    var idleSeconds: Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    func sample() -> ActivityState {
        ActivityState(idleSeconds: idleSeconds, isLocked: isLocked, isAsleep: isAsleep)
    }
}
