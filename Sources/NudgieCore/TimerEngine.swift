import Foundation

/// Counts active seconds per reminder and says when each is due.
/// Pure value type: the app feeds it one tick per second with what the OS reported.
public struct TimerEngine: Equatable, Sendable {
    public enum TickOutcome: Equatable, Sendable {
        case counting
        case paused(until: Date)
        case offTheClock
        case away
        case resetAfterAway
    }

    public private(set) var settings: NudgieSettings
    public private(set) var activeSeconds: [ReminderKind: Double] = [:]
    /// Due reminders waiting for a card, in the order they became due. Never contains duplicates.
    public private(set) var pending: [ReminderKind] = []
    public private(set) var manualPauseUntil: Date?
    /// Start of the current away stretch, nil while active.
    private var awayStartedAt: Date?
    private var didResetForThisAway = false
    /// When the previous tick happened. A long gap means the Mac was asleep.
    private var lastTickAt: Date?
    /// A late heartbeat or a forward clock jump can add at most this much per tick.
    public static let maxElapsedSeconds: Double = 2

    public init(settings: NudgieSettings) {
        self.settings = settings
    }

    // MARK: Heartbeat

    @discardableResult
    public mutating func tick(now: Date, activity: ActivityState,
                              calendar: Calendar = .current) -> TickOutcome {
        defer { lastTickAt = now }
        // Seconds since the previous tick, clamped: never negative, never more than 2. First tick counts 1.
        let elapsed = lastTickAt.map { min(max(now.timeIntervalSince($0), 0), Self.maxElapsedSeconds) } ?? 1

        if let until = manualPauseUntil {
            if now < until { return .paused(until: until) }
            manualPauseUntil = nil
        }
        guard settings.workHours.allows(now, calendar: calendar) else {
            resetAll()
            awayStartedAt = nil
            didResetForThisAway = false
            return .offTheClock
        }
        if let last = lastTickAt, now.timeIntervalSince(last) >= ActivityState.awayThresholdSeconds {
            // No ticks for 5+ minutes: the process was suspended (sleep). That gap was a break.
            resetAll()
            awayStartedAt = nil
            didResetForThisAway = false
            return .resetAfterAway
        }
        if activity.isAway {
            // Idle time already elapsed counts toward the away stretch.
            let startedAt = awayStartedAt
                ?? now.addingTimeInterval(-min(activity.idleSeconds, ActivityState.awayThresholdSeconds))
            awayStartedAt = startedAt
            if !didResetForThisAway,
               now.timeIntervalSince(startedAt) >= ActivityState.awayThresholdSeconds {
                resetAll()
                didResetForThisAway = true
                return .resetAfterAway
            }
            return .away
        }
        // Back at the keyboard. Did the whole away stretch (ticks plus any sleep gap) reach the threshold?
        if let startedAt = awayStartedAt {
            awayStartedAt = nil
            let wasReset = didResetForThisAway
            didResetForThisAway = false
            if !wasReset, now.timeIntervalSince(startedAt) >= ActivityState.awayThresholdSeconds {
                resetAll()
                return .resetAfterAway
            }
        }
        for kind in settings.enabledKinds where !pending.contains(kind) {
            let total = (activeSeconds[kind] ?? 0) + elapsed
            activeSeconds[kind] = total
            if total >= settings.reminder(kind).intervalSeconds {
                pending.append(kind)
            }
        }
        return .counting
    }

    // MARK: User actions

    public mutating func markDone(_ kinds: [ReminderKind]) {
        for kind in kinds { activeSeconds[kind] = 0 }
        pending.removeAll { kinds.contains($0) }
    }

    /// May leave the accumulator negative on purpose: the reminder waits the full snooze.
    public mutating func snooze(_ kinds: [ReminderKind]) {
        let snoozeSeconds = Double(settings.snoozeMinutes) * 60
        for kind in kinds {
            activeSeconds[kind] = settings.reminder(kind).intervalSeconds - snoozeSeconds
        }
        pending.removeAll { kinds.contains($0) }
    }

    /// "Take a break now" from the menu.
    public mutating func triggerNow(_ kind: ReminderKind) {
        guard settings.reminder(kind).isEnabled, !pending.contains(kind) else { return }
        activeSeconds[kind] = settings.reminder(kind).intervalSeconds
        pending.append(kind)
    }

    public mutating func resetAll() {
        activeSeconds = [:]
        pending = []
    }

    public mutating func pause(until: Date) {
        manualPauseUntil = until
        resetAll()
    }

    public mutating func resume() {
        manualPauseUntil = nil
    }

    public mutating func updateSettings(_ new: NudgieSettings) {
        settings = new
        for kind in ReminderKind.allCases where !new.reminder(kind).isEnabled {
            activeSeconds[kind] = nil
            pending.removeAll { $0 == kind }
        }
    }

    // MARK: Queries

    public func isPaused(at now: Date) -> Bool {
        guard let until = manualPauseUntil else { return false }
        return now < until
    }

    /// nil when the reminder is switched off, 0 when it is already due.
    public func secondsUntilDue(_ kind: ReminderKind) -> Double? {
        let setting = settings.reminder(kind)
        guard setting.isEnabled else { return nil }
        if pending.contains(kind) { return 0 }
        return max(0, setting.intervalSeconds - (activeSeconds[kind] ?? 0))
    }
}
