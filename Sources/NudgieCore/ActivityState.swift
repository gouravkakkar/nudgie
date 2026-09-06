/// What the OS tells us about the person at the keyboard, as plain values.
public struct ActivityState: Equatable, Sendable {
    /// Seconds since the last keyboard or mouse event.
    public var idleSeconds: Double
    public var isLocked: Bool
    public var isAsleep: Bool

    /// Away for this long counts as a break and resets every timer.
    public static let awayThresholdSeconds: Double = 300

    public init(idleSeconds: Double = 0, isLocked: Bool = false, isAsleep: Bool = false) {
        self.idleSeconds = idleSeconds
        self.isLocked = isLocked
        self.isAsleep = isAsleep
    }

    /// Locked or asleep is away at once; idle counts as away after the threshold.
    public var isAway: Bool {
        isLocked || isAsleep || idleSeconds >= Self.awayThresholdSeconds
    }
}
