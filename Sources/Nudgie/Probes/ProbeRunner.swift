import Foundation
import NudgieCore

/// `Nudgie --probe`: print live detector values once a second. Ctrl-C to stop.
enum ProbeRunner {
    static func run() {
        let activity = ActivityProbe()
        let quiet = QuietProbe()
        print("Nudgie probe. Move the mouse, lock the screen, open Photo Booth, switch apps. Ctrl-C to stop.")
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                let a = activity.sample()
                let q = quiet.sample()
                let front = q.frontmostBundleID ?? "nil"
                print(String(format: "idle %6.1fs  locked %@  asleep %@  camera %@  mic %@  front %@",
                             a.idleSeconds, "\(a.isLocked)", "\(a.isAsleep)", "\(q.cameraBusy)", "\(q.micBusy)", front))
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.run()
    }
}
