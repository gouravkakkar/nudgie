import Foundation
import NudgieCore

/// What the coordinator needs from the OS, as two tiny protocols so tests can substitute fakes.
protocol ActivitySampling {
    func sample() -> ActivityState
}

protocol QuietSampling {
    func sample(now: Date) -> QuietState
}
