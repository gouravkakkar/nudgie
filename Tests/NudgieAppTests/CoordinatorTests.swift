import Foundation
import Testing
import NudgieCore
@testable import Nudgie

@MainActor final class FakeActivity: ActivitySampling {
    var state = ActivityState()
    func sample() -> ActivityState { state }
}

@MainActor final class FakeQuiet: QuietSampling {
    var state = QuietState()
    func sample(now: Date) -> QuietState { state }
}

@MainActor final class FakeClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
}

/// Records the sound names the coordinator asks to play, instead of playing real system sounds.
@MainActor final class SoundLog {
    var names: [String] = []
}

@MainActor @Suite struct CoordinatorTests {
    /// Nested types do not inherit the suite's @MainActor, so mark it explicitly.
    @MainActor struct Rig {
        let coordinator: Coordinator
        let activity: FakeActivity
        let quiet: FakeQuiet
        let clock: FakeClock
        let testDefaults: TestDefaults
        let soundLog: SoundLog

        /// Drive the heartbeat one second at a time, like the real Timer would.
        func advance(_ seconds: Int) {
            for _ in 0..<seconds {
                clock.now = clock.now.addingTimeInterval(1)
                coordinator.tick()
            }
        }

        /// Deletes the throwaway UserDefaults suite backing this rig. Call via `defer` right
        /// after `makeRig()`.
        func cleanUp() {
            testDefaults.cleanUp()
        }
    }

    func makeRig() -> Rig {
        let testDefaults = TestDefaults()
        let activity = FakeActivity()
        let quiet = FakeQuiet()
        let clock = FakeClock()
        let soundLog = SoundLog()
        let coordinator = Coordinator(store: Store(defaults: testDefaults.defaults), activity: activity, quiet: quiet,
                                      clock: { clock.now }, playSound: { soundLog.names.append($0) })
        return Rig(coordinator: coordinator, activity: activity, quiet: quiet, clock: clock,
                   testDefaults: testDefaults, soundLog: soundLog)
    }

    @Test func lockHidesTheCardAndNothingNewShowsWhileLocked() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        defer { rig.cleanUp() }
        rig.advance(20 * 60)
        #expect(rig.coordinator.card != nil)
        rig.activity.state = ActivityState(idleSeconds: 1, isLocked: true)
        rig.advance(1)
        #expect(rig.coordinator.card == nil)
        rig.advance(60)                               // pending eyes must not become a card while locked
        #expect(rig.coordinator.card == nil)
        rig.activity.state = ActivityState()
        rig.advance(1)                                // back at the keyboard: the breathing gap passed while locked
        #expect(rig.coordinator.card?.plan.kinds == [.eyes])
    }

    @Test func disablingAReminderRemovesItFromTheCard() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        rig.advance(30 * 60)                          // eyes card came and finished at 20:20; posture card is up now
        #expect(rig.coordinator.card?.plan.kinds == [.posture])
        var s = rig.coordinator.settings
        s.setReminder(ReminderSetting(isEnabled: false, intervalMinutes: 30, breakSeconds: 0), for: .posture)
        rig.coordinator.updateSettings(s)
        #expect(rig.coordinator.card == nil)
        #expect(rig.coordinator.today.taken == 1)     // only the eyes card that ran its ring down
    }

    @Test func disablingOneKindOfAGroupedCardKeepsTheCountdownConsistent() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        var s = rig.coordinator.settings
        var walk = s.reminder(.walk)
        walk.intervalMinutes = 20                     // now due at the same time as eyes
        s.setReminder(walk, for: .walk)
        rig.coordinator.updateSettings(s)
        rig.advance(20 * 60)                           // both land on one card together
        #expect(rig.coordinator.card?.plan.kinds == [.eyes, .walk])
        #expect(rig.coordinator.card?.plan.countdownSeconds == 180)   // walk's longer break wins
        rig.advance(5)
        s = rig.coordinator.settings
        walk = s.reminder(.walk)
        walk.isEnabled = false
        s.setReminder(walk, for: .walk)
        rig.coordinator.updateSettings(s)
        #expect(rig.coordinator.card?.plan.kinds == [.eyes])
        #expect(rig.coordinator.card?.secondsLeft == 15)   // eyes' 20 s break minus the 5 s already spent
    }

    @Test func didItIgnoresAStaleCardID() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        rig.advance(20 * 60)
        let stale = UUID()
        rig.coordinator.didIt(cardID: stale)
        #expect(rig.coordinator.card != nil)
        #expect(rig.coordinator.today.taken == 0)
        rig.coordinator.didIt(cardID: rig.coordinator.card!.id)
        #expect(rig.coordinator.card == nil)
        #expect(rig.coordinator.today.taken == 1)
    }

    @Test func statusMapping() {
        #expect(Coordinator.status(outcome: .counting, quiet: nil) == .counting)
        #expect(Coordinator.status(outcome: .counting, quiet: .micBusy) == .quiet(.micBusy))
        #expect(Coordinator.status(outcome: .offTheClock, quiet: .micBusy) == .offTheClock)
        #expect(Coordinator.status(outcome: .away, quiet: nil) == .away)
        #expect(Coordinator.status(outcome: .resetAfterAway, quiet: nil) == .away)
    }

    @Test func iconMapping() {
        #expect(Coordinator.icon(for: .quiet(.cameraBusy), tick: 5) == .shh)
        #expect(Coordinator.icon(for: .paused(until: .distantFuture), tick: 5) == .zzz)
        #expect(Coordinator.icon(for: .offTheClock, tick: 5) == .zzz)
        #expect(Coordinator.icon(for: .counting, tick: 30) == .blink)
        #expect(Coordinator.icon(for: .counting, tick: 31) == .normal)
    }

    @Test func eyesCardAppearsAfterTwentyActiveMinutesAndCountsWhenTheRingRunsOut() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        rig.advance(20 * 60)
        #expect(rig.coordinator.card?.plan.kinds == [.eyes])
        #expect(rig.coordinator.card?.isForced == false)
        rig.advance(20)
        #expect(rig.coordinator.card == nil)
        #expect(rig.coordinator.today.taken == 1)
    }

    @Test func meetingHidesTheCardAndItReturnsAfterTheSettleGap() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        rig.advance(20 * 60)
        #expect(rig.coordinator.card != nil)
        rig.quiet.state.cameraBusy = true
        rig.advance(1)
        #expect(rig.coordinator.card == nil)
        #expect(rig.coordinator.status == .quiet(.cameraBusy))
        rig.quiet.state.cameraBusy = false
        rig.advance(29)
        #expect(rig.coordinator.card == nil)      // still inside the 30 s settle gap
        rig.advance(1)
        #expect(rig.coordinator.card == nil)      // tick 1231: breathing gap satisfied, settle gap not
        rig.advance(1)
        #expect(rig.coordinator.card?.plan.kinds == [.eyes])
    }

    @Test func takeABreakNowSurvivesAMeeting() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        rig.quiet.state.micBusy = true
        rig.advance(1)
        rig.coordinator.takeBreakNow()
        #expect(rig.coordinator.card?.isForced == true)
        rig.advance(5)
        #expect(rig.coordinator.card != nil)
    }

    @Test func takeABreakNowIsIgnoredWhilePaused() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        rig.advance(1)
        rig.coordinator.pause(hours: 1)
        #expect(rig.coordinator.canTakeBreakNow == false)
        rig.coordinator.takeBreakNow()
        #expect(rig.coordinator.card == nil)
        #expect(rig.coordinator.engine.pending.isEmpty)
    }

    @Test func snoozeCountsAndReschedules() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        rig.advance(20 * 60)
        rig.coordinator.snooze()
        #expect(rig.coordinator.card == nil)
        #expect(rig.coordinator.today.snoozed == 1)
        #expect(rig.coordinator.nextUp.first { $0.kind == .eyes }?.seconds == 300)
    }

    @Test func pauseHidesTheCardAndReportsPaused() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        rig.advance(20 * 60)
        rig.coordinator.pause(hours: 1)
        #expect(rig.coordinator.card == nil)
        guard case .paused = rig.coordinator.status else {
            Issue.record("expected paused, got \(rig.coordinator.status)")
            return
        }
    }

    @Test func demoShowsAForcedCardEvenWhenAway() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        rig.activity.state = ActivityState(idleSeconds: 600)
        rig.coordinator.start(demo: .water)
        #expect(rig.coordinator.card?.plan.kinds == [.water])
        #expect(rig.coordinator.card?.isForced == true)
        rig.advance(3)
        #expect(rig.coordinator.card != nil)
    }

    @Test func dueTextFormats() {
        #expect(MenuBarView.dueText(0) == "now")
        #expect(MenuBarView.dueText(30) == "in 1 min")
        #expect(MenuBarView.dueText(61) == "in 2 min")
    }

    @Test func scheduledCardPlaysTheConfiguredSoundOnce() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        rig.advance(1200)
        #expect(rig.soundLog.names == ["Pop"])
    }

    @Test func forcedCardDuringAMeetingPlaysNoSound() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        rig.quiet.state.micBusy = true
        rig.advance(1)
        rig.coordinator.takeBreakNow()
        #expect(rig.soundLog.names.isEmpty)
    }

    @Test func noSoundWhenSoundIsDisabled() {
        let rig = makeRig()
        defer { rig.cleanUp() }
        var s = rig.coordinator.settings
        s.soundEnabled = false
        rig.coordinator.updateSettings(s)
        rig.advance(1200)
        #expect(rig.soundLog.names.isEmpty)
        #expect(rig.coordinator.card != nil)
    }
}
