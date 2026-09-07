import Foundation

/// One card on screen: which reminders it lists and how long its ring runs.
public struct CardPlan: Equatable, Sendable {
    public var kinds: [ReminderKind]
    public var countdownSeconds: Int
    /// false when every listed reminder is untimed (water, posture): the card just shows for a while.
    public var isTimed: Bool

    public init(kinds: [ReminderKind], countdownSeconds: Int, isTimed: Bool) {
        self.kinds = kinds
        self.countdownSeconds = countdownSeconds
        self.isTimed = isTimed
    }
}

/// Decides *when* pending reminders may become a card. Knows nothing about windows.
public struct CardPlanner: Equatable, Sendable {
    public static let breathingGapSeconds: Double = 30
    public static let settleAfterQuietSeconds: Double = 30
    public static let untimedDisplaySeconds = 30

    public private(set) var isShowing = false
    public private(set) var lastDismissedAt: Date?
    /// When the last *delivered* card appeared. The minimum gap runs from here rather than
    /// from dismissal, so sitting on a card does not push the next one further out than the
    /// gap the user asked for.
    public private(set) var lastShownAt: Date?
    /// When the card currently on screen appeared. Becomes `lastShownAt` only if that card is
    /// actually delivered: one yanked away by a meeting or a locked screen never reached the
    /// user, so it must not start the clock on the next nudge.
    private var currentShownAt: Date?
    public private(set) var quietEndedAt: Date?
    private var wasQuiet = false

    public init() {}

    public var isQuiet: Bool { wasQuiet }

    /// Call once per tick, before `plan`, so the settle gap starts when a meeting ends.
    public mutating func observe(quiet: Bool, now: Date) {
        if wasQuiet && !quiet { quietEndedAt = now }
        wasQuiet = quiet
    }

    /// Returns a card to show now, or nil. A returned plan marks the planner as showing.
    public mutating func plan(pending: [ReminderKind], settings: NudgieSettings, now: Date) -> CardPlan? {
        guard !isShowing, !wasQuiet, !pending.isEmpty else { return nil }
        if let last = lastDismissedAt, now.timeIntervalSince(last) < Self.breathingGapSeconds { return nil }
        // Anything that fell due inside the gap stays pending, so the next card carries the
        // whole set at once instead of firing them one after another.
        if let shown = lastShownAt, now.timeIntervalSince(shown) < settings.minimumGapSeconds { return nil }
        if let ended = quietEndedAt, now.timeIntervalSince(ended) < Self.settleAfterQuietSeconds { return nil }
        let longest = pending.map { settings.reminder($0).breakSeconds }.max() ?? 0
        isShowing = true
        currentShownAt = now
        return CardPlan(kinds: pending,
                        countdownSeconds: longest > 0 ? longest : Self.untimedDisplaySeconds,
                        isTimed: longest > 0)
    }

    /// "Take a break now": show at once, even mid-meeting, unless a card is already up.
    /// Asked for explicitly, so the minimum gap does not apply -- but it restarts from here,
    /// so a break you took yourself still buys you quiet afterwards.
    public mutating func forcePlan(kinds: [ReminderKind], settings: NudgieSettings,
                                   now: Date) -> CardPlan? {
        guard !isShowing, !kinds.isEmpty else { return nil }
        let longest = kinds.map { settings.reminder($0).breakSeconds }.max() ?? 0
        isShowing = true
        currentShownAt = now
        return CardPlan(kinds: kinds,
                        countdownSeconds: longest > 0 ? longest : Self.untimedDisplaySeconds,
                        isTimed: longest > 0)
    }

    /// Any way the card leaves the screen: Did it, snooze, close, countdown finished, or
    /// hidden by a meeting. `delivered` is false when the card was taken away rather than
    /// acted on -- a locked screen, a meeting, a pause, or the reminder being switched off.
    /// Those stay pending and come back, so they must not start the minimum gap.
    public mutating func cardDismissed(now: Date, delivered: Bool = true) {
        isShowing = false
        lastDismissedAt = now
        if delivered { lastShownAt = currentShownAt ?? now }
        currentShownAt = nil
    }
}
