import Foundation
import Testing
@testable import NudgieCore

@Suite struct TimerEngineTests {
    /// Monday 2026-09-07 10:00 UTC.
    static let start = TestClock.date(2026, 9, 7, 10, 0)

    /// Drives the engine one second at a time. `activity` is built from the tick index so idle can grow.
    @discardableResult
    static func run(_ engine: inout TimerEngine, from now: inout Date, seconds: Int,
                    activity: (Int) -> ActivityState = { _ in ActivityState() }) -> [TimerEngine.TickOutcome] {
        var outcomes: [TimerEngine.TickOutcome] = []
        for i in 0..<seconds {
            now = now.addingTimeInterval(1)
            outcomes.append(engine.tick(now: now, activity: activity(i), calendar: TestClock.utc))
        }
        return outcomes
    }

    @Test func eyesBecomesPendingAfterTwentyActiveMinutes() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 20 * 60 - 1)
        #expect(e.pending.isEmpty)
        #expect(e.secondsUntilDue(.eyes) == 1)
        Self.run(&e, from: &now, seconds: 1)
        #expect(e.pending == [.eyes])
        #expect(e.secondsUntilDue(.eyes) == 0)
    }

    @Test func lockedSecondsDoNotCount() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 10 * 60)
        let locked = Self.run(&e, from: &now, seconds: 3 * 60) { i in ActivityState(idleSeconds: Double(i), isLocked: true) }
        #expect(locked.allSatisfy { $0 == .away })
        Self.run(&e, from: &now, seconds: 10 * 60 - 1)
        #expect(e.pending.isEmpty)
        Self.run(&e, from: &now, seconds: 1)
        #expect(e.pending == [.eyes])
    }

    @Test func idleUnderFiveMinutesStillCounts() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        let out = Self.run(&e, from: &now, seconds: 20 * 60) { _ in ActivityState(idleSeconds: 200) }
        #expect(out.allSatisfy { $0 == .counting })
        #expect(e.pending == [.eyes])
    }

    @Test func idleReachingFiveMinutesResetsOnce() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 15 * 60)
        #expect(e.secondsUntilDue(.eyes) == 300)
        let out = Self.run(&e, from: &now, seconds: 310) { i in ActivityState(idleSeconds: Double(i + 1)) }
        // idle 1...299 is still active, idle 300 resets at once, idle 301...310 is away
        #expect(out[298] == .counting)
        #expect(out[299] == .resetAfterAway)
        #expect(out[300] == .away)
        #expect(out.filter { $0 == .resetAfterAway }.count == 1)
        #expect(e.secondsUntilDue(.eyes) == 1200)
    }

    @Test func lockResetsAfterFiveMinutesLocked() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 15 * 60)
        let out = Self.run(&e, from: &now, seconds: 305) { i in ActivityState(idleSeconds: Double(i), isLocked: true) }
        #expect(out.filter { $0 == .resetAfterAway }.count == 1)
        #expect(out.firstIndex(of: .resetAfterAway) == 300)
        #expect(e.activeSeconds[.eyes] == nil || e.activeSeconds[.eyes] == 0)
    }

    @Test func longGapBetweenTicksResetsTimers() {
        // The Mac slept: no ticks arrived for an hour. That gap was a break.
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 15 * 60)
        now = now.addingTimeInterval(3600)
        #expect(e.tick(now: now, activity: ActivityState(), calendar: TestClock.utc) == .resetAfterAway)
        #expect(e.secondsUntilDue(.eyes) == 1200)
        let after = Self.run(&e, from: &now, seconds: 1)
        #expect(after == [.counting])
    }

    @Test func shortLockDoesNotReset() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 15 * 60)
        Self.run(&e, from: &now, seconds: 120) { i in ActivityState(idleSeconds: Double(i), isLocked: true) }
        Self.run(&e, from: &now, seconds: 5 * 60)
        #expect(e.pending == [.eyes])
    }

    @Test func lockThenSleepThenWakeStillResets() {
        // Locked 90 s (ticks), then asleep 4 min (no ticks, gap under the threshold on its own),
        // then unlocked and active: the whole stretch is 330 s, so it resets.
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 15 * 60)
        Self.run(&e, from: &now, seconds: 90) { i in ActivityState(idleSeconds: Double(i), isLocked: true) }
        now = now.addingTimeInterval(4 * 60)
        #expect(e.tick(now: now, activity: ActivityState(), calendar: TestClock.utc) == .resetAfterAway)
        #expect(e.secondsUntilDue(.eyes) == 1200)
    }

    @Test func delayedHeartbeatCountsAtMostTwoSeconds() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 60)
        now = now.addingTimeInterval(10)           // the timer fired late
        e.tick(now: now, activity: ActivityState(), calendar: TestClock.utc)
        #expect(e.secondsUntilDue(.eyes) == 1200 - 60 - 2)
        e.tick(now: now, activity: ActivityState(), calendar: TestClock.utc)   // same instant again
        #expect(e.secondsUntilDue(.eyes) == 1200 - 60 - 2)
        now = now.addingTimeInterval(-30)          // clock jumped backward
        e.tick(now: now, activity: ActivityState(), calendar: TestClock.utc)
        #expect(e.secondsUntilDue(.eyes) == 1200 - 60 - 2)
    }

    @Test func eachReminderPendsOnceInDueOrder() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 60 * 60)
        #expect(e.pending == [.eyes, .posture, .water, .walk, .stretch])
        Self.run(&e, from: &now, seconds: 60 * 60)
        #expect(e.pending == [.eyes, .posture, .water, .walk, .stretch])
    }

    @Test func markDoneClearsPendingAndRestartsTimer() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 20 * 60)
        e.markDone([.eyes])
        #expect(e.pending.isEmpty)
        #expect(e.secondsUntilDue(.eyes) == 1200)
    }

    @Test func snoozeComesBackAfterSnoozeMinutes() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 20 * 60)
        e.snooze([.eyes])
        #expect(e.pending.isEmpty)
        #expect(e.secondsUntilDue(.eyes) == 300)
        Self.run(&e, from: &now, seconds: 300)
        #expect(e.pending == [.eyes])
    }

    @Test func snoozeLongerThanIntervalWaitsTheFullSnooze() {
        var s = NudgieSettings.defaults
        s.setReminder(ReminderSetting(intervalMinutes: 5, breakSeconds: 0), for: .water)
        s.snoozeMinutes = 30
        var e = TimerEngine(settings: s)
        e.triggerNow(.water)
        e.snooze([.water])
        #expect(e.secondsUntilDue(.water) == 30 * 60)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 30 * 60 - 1)
        #expect(!e.pending.contains(.water))
        Self.run(&e, from: &now, seconds: 1)
        #expect(e.pending.contains(.water))
    }

    @Test func snoozeEqualToIntervalComesBackAfterOneInterval() {
        var s = NudgieSettings.defaults
        s.setReminder(ReminderSetting(intervalMinutes: 5, breakSeconds: 0), for: .water)
        s.snoozeMinutes = 5
        var e = TimerEngine(settings: s)
        e.triggerNow(.water)
        e.snooze([.water])
        #expect(e.secondsUntilDue(.water) == 300)
    }

    @Test func offTheClockResetsAndDoesNotCount() {
        var s = NudgieSettings.defaults
        s.workHours = WorkHours(isEnabled: true, startMinute: 9 * 60, endMinute: 18 * 60, weekdays: [2, 3, 4, 5, 6])
        var e = TimerEngine(settings: s)
        var now = Self.start                                   // Monday 10:00, inside
        Self.run(&e, from: &now, seconds: 10 * 60)
        #expect(e.secondsUntilDue(.eyes) == 600)
        now = TestClock.date(2026, 9, 7, 18, 30)
        let out = Self.run(&e, from: &now, seconds: 5)
        #expect(out.allSatisfy { $0 == .offTheClock })
        #expect(e.secondsUntilDue(.eyes) == 1200)
    }

    @Test func manualPauseResetsStopsAndExpires() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 10 * 60)
        e.pause(until: now.addingTimeInterval(61))   // ticks land on now+1 ... now+60, all before expiry
        #expect(e.isPaused(at: now))
        #expect(e.secondsUntilDue(.eyes) == 1200)
        let paused = Self.run(&e, from: &now, seconds: 60)
        #expect(paused.allSatisfy { if case .paused = $0 { true } else { false } })
        let after = Self.run(&e, from: &now, seconds: 1)
        #expect(after == [.counting])
        #expect(!e.isPaused(at: now))
    }

    @Test func resumeClearsPause() {
        var e = TimerEngine(settings: .defaults)
        e.pause(until: Self.start.addingTimeInterval(3600))
        e.resume()
        #expect(!e.isPaused(at: Self.start))
    }

    @Test func triggerNowMakesPendingImmediately() {
        var e = TimerEngine(settings: .defaults)
        e.triggerNow(.water)
        #expect(e.pending == [.water])
        #expect(e.secondsUntilDue(.water) == 0)
        e.triggerNow(.water)
        #expect(e.pending == [.water])
    }

    @Test func disabledKindNeverPends() {
        var s = NudgieSettings.defaults
        s.setReminder(ReminderSetting(isEnabled: false, intervalMinutes: 20, breakSeconds: 20), for: .eyes)
        var e = TimerEngine(settings: s)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 60 * 60)
        #expect(!e.pending.contains(.eyes))
        #expect(e.secondsUntilDue(.eyes) == nil)
        e.triggerNow(.eyes)
        #expect(!e.pending.contains(.eyes))
    }

    @Test func updateSettingsDropsDisabledPending() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 20 * 60)
        var s = NudgieSettings.defaults
        s.setReminder(ReminderSetting(isEnabled: false, intervalMinutes: 20, breakSeconds: 20), for: .eyes)
        e.updateSettings(s)
        #expect(e.pending.isEmpty)
        #expect(e.settings == s)
    }
}
