import Foundation
import Testing
@testable import NudgieCore

@Suite struct CardPlannerTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    let settings = NudgieSettings.defaults

    @Test func showsWhenPendingAndClear() {
        var p = CardPlanner()
        let plan = p.plan(pending: [.eyes], settings: settings, now: t0)
        #expect(plan == CardPlan(kinds: [.eyes], countdownSeconds: 20, isTimed: true))
        #expect(p.isShowing)
    }

    @Test func nothingWhenNoPending() {
        var p = CardPlanner()
        #expect(p.plan(pending: [], settings: settings, now: t0) == nil)
        #expect(!p.isShowing)
    }

    @Test func nothingWhileQuiet() {
        var p = CardPlanner()
        p.observe(quiet: true, now: t0)
        #expect(p.isQuiet)
        #expect(p.plan(pending: [.eyes], settings: settings, now: t0) == nil)
    }

    @Test func nothingWhileAlreadyShowing() {
        var p = CardPlanner()
        _ = p.plan(pending: [.eyes], settings: settings, now: t0)
        #expect(p.plan(pending: [.eyes, .water], settings: settings, now: t0.addingTimeInterval(5)) == nil)
    }

    @Test func breathingGapAfterDismissal() {
        var p = CardPlanner()
        // The 30-second breathing gap is the floor once the minimum gap is switched off.
        var settings = self.settings
        settings.minimumGapMinutes = 0
        _ = p.plan(pending: [.eyes], settings: settings, now: t0)
        p.cardDismissed(now: t0.addingTimeInterval(20))
        #expect(!p.isShowing)
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(49)) == nil)
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(50)) != nil)
    }

    // MARK: Minimum gap between two cards

    @Test func minimumGapKeepsTheNextCardAway() {
        var p = CardPlanner()   // defaults: 30 minutes
        _ = p.plan(pending: [.eyes], settings: settings, now: t0)
        p.cardDismissed(now: t0.addingTimeInterval(20))
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(29 * 60)) == nil)
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(30 * 60)) != nil)
    }

    /// Measured from when the last card appeared, so sitting on a card does not push the
    /// next one further out than the gap the user asked for.
    @Test func minimumGapRunsFromWhenTheCardAppeared() {
        var p = CardPlanner()
        _ = p.plan(pending: [.eyes], settings: settings, now: t0)
        p.cardDismissed(now: t0.addingTimeInterval(10 * 60))   // left on screen for ten minutes
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(30 * 60)) != nil)
    }

    @Test func gapOfZeroFallsBackToTheBreathingGap() {
        var p = CardPlanner()
        var settings = self.settings
        settings.minimumGapMinutes = 0
        _ = p.plan(pending: [.eyes], settings: settings, now: t0)
        p.cardDismissed(now: t0.addingTimeInterval(5))
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(40)) != nil)
    }

    /// Everything that fell due while the gap was running arrives on one card, not a queue
    /// of cards fired back to back.
    @Test func remindersDueDuringTheGapArriveTogether() {
        var p = CardPlanner()
        _ = p.plan(pending: [.eyes], settings: settings, now: t0)
        p.cardDismissed(now: t0.addingTimeInterval(20))
        let later = t0.addingTimeInterval(30 * 60)
        let plan = p.plan(pending: [.water, .posture, .stretch], settings: settings, now: later)
        #expect(plan?.kinds == [.water, .posture, .stretch])
    }

    @Test func takeABreakNowIgnoresTheGapButRestartsIt() {
        var p = CardPlanner()
        _ = p.plan(pending: [.eyes], settings: settings, now: t0)
        p.cardDismissed(now: t0.addingTimeInterval(20))
        // Asked for explicitly, so it shows straight away.
        let forced = p.forcePlan(kinds: [.walk], settings: settings, now: t0.addingTimeInterval(60))
        #expect(forced != nil)
        p.cardDismissed(now: t0.addingTimeInterval(90))
        // ...and the next automatic card waits 30 minutes from when the forced one appeared
        // (t0 + 60s), not from t0.
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(30 * 60 + 59)) == nil)
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(30 * 60 + 60)) != nil)
    }

    @Test func settleGapAfterQuietEnds() {
        var p = CardPlanner()
        p.observe(quiet: true, now: t0)
        p.observe(quiet: false, now: t0.addingTimeInterval(100))
        #expect(!p.isQuiet)
        #expect(p.plan(pending: [.eyes], settings: settings, now: t0.addingTimeInterval(129)) == nil)
        #expect(p.plan(pending: [.eyes], settings: settings, now: t0.addingTimeInterval(130)) != nil)
    }

    @Test func countdownIsLongestBreakInGroup() {
        var p = CardPlanner()
        let plan = p.plan(pending: [.eyes, .walk, .water], settings: settings, now: t0)
        #expect(plan?.kinds == [.eyes, .walk, .water])
        #expect(plan?.countdownSeconds == 180)
        #expect(plan?.isTimed == true)
    }

    @Test func untimedGroupShowsForThirtySeconds() {
        var p = CardPlanner()
        let plan = p.plan(pending: [.water, .posture], settings: settings, now: t0)
        #expect(plan?.countdownSeconds == CardPlanner.untimedDisplaySeconds)
        #expect(plan?.isTimed == false)
    }

    @Test func forcePlanIgnoresGapsAndQuietButNotAnExistingCard() {
        var p = CardPlanner()
        p.observe(quiet: true, now: t0)
        let plan = p.forcePlan(kinds: [.walk], settings: settings, now: t0)
        #expect(plan == CardPlan(kinds: [.walk], countdownSeconds: 180, isTimed: true))
        #expect(p.isShowing)
        #expect(p.forcePlan(kinds: [.eyes], settings: settings, now: t0) == nil)
    }

    @Test func customBreakLengthIsUsed() {
        var s = settings
        s.setReminder(ReminderSetting(intervalMinutes: 20, breakSeconds: 45), for: .eyes)
        var p = CardPlanner()
        #expect(p.plan(pending: [.eyes], settings: s, now: t0)?.countdownSeconds == 45)
    }
}
