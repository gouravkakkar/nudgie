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
        _ = p.plan(pending: [.eyes], settings: settings, now: t0)
        p.cardDismissed(now: t0.addingTimeInterval(20))
        #expect(!p.isShowing)
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(49)) == nil)
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(50)) != nil)
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
        let plan = p.forcePlan(kinds: [.walk], settings: settings)
        #expect(plan == CardPlan(kinds: [.walk], countdownSeconds: 180, isTimed: true))
        #expect(p.isShowing)
        #expect(p.forcePlan(kinds: [.eyes], settings: settings) == nil)
    }

    @Test func customBreakLengthIsUsed() {
        var s = settings
        s.setReminder(ReminderSetting(intervalMinutes: 20, breakSeconds: 45), for: .eyes)
        var p = CardPlanner()
        #expect(p.plan(pending: [.eyes], settings: s, now: t0)?.countdownSeconds == 45)
    }
}
