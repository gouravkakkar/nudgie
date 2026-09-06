import AppKit
import Foundation
import Observation
import NudgieCore

/// One line for the menu bar.
enum EngineStatus: Equatable {
    case counting
    case quiet(QuietReason)
    case paused(until: Date)
    case offTheClock
    case away

    var label: String {
        switch self {
        case .counting: "Counting"
        case .quiet(let reason): "Quiet: \(reason.label)"
        case .paused(let until): "Paused until \(until.formatted(date: .omitted, time: .shortened))"
        case .offTheClock: "Off the clock"
        case .away: "Away"
        }
    }
}

/// The card currently on screen.
struct CardPresentation: Equatable {
    let id: UUID
    let plan: CardPlan
    let headline: String
    let startedAt: Date
    /// "Take a break now" cards are not hidden by a meeting: the user asked for them.
    let isForced: Bool
    var secondsLeft: Int

    /// The first reminder sets the card's colour and mascot pose.
    var accentKind: ReminderKind { plan.kinds[0] }
}

/// A later task caches menu-bar images by state, hence `Hashable`.
enum IconState: Hashable { case normal, blink, shh, zzz }

/// The 1-second heartbeat. Reads probes, drives the engine and planner, owns the card state.
@Observable
final class Coordinator {
    struct NextUp: Equatable {
        let kind: ReminderKind
        let seconds: Double
    }

    private(set) var settings: NudgieSettings
    private(set) var engine: TimerEngine
    private(set) var planner = CardPlanner()
    private(set) var stats: DailyStats
    private(set) var status: EngineStatus = .counting
    private(set) var card: CardPresentation?
    private(set) var iconState: IconState = .normal
    private(set) var now = Date()

    /// The window layer hooks these (Task 10). Nil until then.
    var onShowCard: (() -> Void)?
    var onHideCard: (() -> Void)?

    private var copy = CopyPicker()
    private let store: Store
    private let activityProbe: any ActivitySampling
    private let quietProbe: any QuietSampling
    private let clock: () -> Date
    private var timer: Timer?
    private var tickCount = 0
    private let calendar = Calendar.current
    private let verbose = CommandLine.arguments.contains("--verbose")
    /// Keeps the heartbeat's Timer from being throttled by App Nap while Nudgie has no window up.
    private var activityToken: NSObjectProtocol?

    init(store: Store = Store(),
         activity: any ActivitySampling = ActivityProbe(),
         quiet: any QuietSampling = QuietProbe(),
         clock: @escaping () -> Date = { Date() }) {
        self.store = store
        self.activityProbe = activity
        self.quietProbe = quiet
        self.clock = clock
        // @Observable turns `settings` into an accessor, so it cannot be read until every
        // stored property is initialised. Go through a local.
        let loaded = store.loadSettings()
        settings = loaded
        engine = TimerEngine(settings: loaded)
        stats = store.loadStats()
    }

    func start(demo: ReminderKind? = nil) {
        guard timer == nil else { return }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep], reason: "Nudgie heartbeat")
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
        // `--demo` means "show me this card now": use the same forced path as "Take a break
        // now" so a Mac idle for 300+ seconds at launch still shows it, instead of relying on
        // the normal scheduled path, which the very first tick above may have already gated on
        // away/reset. If the kind is disabled in settings, triggerNow is a no-op: no card shows.
        if let demo {
            engine.triggerNow(demo)
            if let plan = planner.forcePlan(kinds: [demo], settings: settings) {
                show(plan, forced: true)
            }
        }
    }

    // MARK: Heartbeat

    func tick() {
        now = clock()
        tickCount += 1
        let activity = activityProbe.sample()
        let quietReason = QuietPolicy.reason(for: quietProbe.sample(now: now), settings: settings)
        let outcome = engine.tick(now: now, activity: activity, calendar: calendar)
        planner.observe(quiet: quietReason != nil, now: now)
        status = Self.status(outcome: outcome, quiet: quietReason)
        iconState = Self.icon(for: status, tick: tickCount)

        let engineStopped: Bool = switch outcome {
        case .counting, .away: false
        case .paused, .offTheClock, .resetAfterAway: true
        }
        // Locked or asleep: nobody is looking. Hide any card (it stays pending) and show nothing new.
        let screenGone = activity.isLocked || activity.isAsleep

        if let current = card {
            // A meeting hides a scheduled card (it stays pending); a forced card stays up.
            if engineStopped || screenGone || (quietReason != nil && !current.isForced) {
                hideCard()
                return
            }
            let elapsed = Int(now.timeIntervalSince(current.startedAt).rounded(.down))
            let left = max(0, current.plan.countdownSeconds - elapsed)
            card?.secondsLeft = left
            if left == 0 { didIt() }   // finishing the countdown counts as taking the break
        } else if !activity.isAway,
                  let plan = planner.plan(pending: engine.pending, settings: settings, now: now) {
            show(plan)
        }
    }

    private func show(_ plan: CardPlan, forced: Bool = false) {
        let headline = copy.line(for: plan.kinds[0])
        card = CardPresentation(id: UUID(), plan: plan, headline: headline, startedAt: now, isForced: forced,
                                secondsLeft: plan.countdownSeconds)
        if settings.soundEnabled, !planner.isQuiet {
            Sound.play(settings.soundName)
        }
        log("show \(plan.kinds.map(\.rawValue)) for \(plan.countdownSeconds)s")
        onShowCard?()
    }

    private func hideCard() {
        guard card != nil else { return }
        card = nil
        planner.cardDismissed(now: now)
        log("hide")
        onHideCard?()
    }

    // MARK: Card actions

    /// Pass the card's id from a delayed caller (the confetti) so a stale call cannot complete a newer card.
    func didIt(cardID: UUID? = nil) {
        guard let current = card, cardID == nil || cardID == current.id else { return }
        engine.markDone(current.plan.kinds)
        stats.record(taken: current.plan.kinds.count, on: now, calendar: calendar)
        store.save(stats)
        hideCard()
    }

    func snooze() {
        guard let current = card else { return }
        engine.snooze(current.plan.kinds)
        stats.record(snoozed: current.plan.kinds.count, on: now, calendar: calendar)
        store.save(stats)
        hideCard()
    }

    /// The tiny ✕: restart those timers, count nothing.
    func close() {
        guard let current = card else { return }
        engine.markDone(current.plan.kinds)
        hideCard()
    }

    // MARK: Menu actions

    func takeBreakNow() {
        guard canTakeBreakNow, let soonest = nextUp.min(by: { $0.seconds < $1.seconds }) else { return }
        engine.triggerNow(soonest.kind)
        if let plan = planner.forcePlan(kinds: [soonest.kind], settings: settings) {
            show(plan, forced: true)
        }
    }

    func pause(hours: Double) {
        hideCard()
        engine.pause(until: now.addingTimeInterval(hours * 3600))
        tick()
    }

    func pauseUntilTomorrow() {
        hideCard()
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        engine.pause(until: tomorrow)
        tick()
    }

    func resume() {
        engine.resume()
        tick()
    }

    func updateSettings(_ new: NudgieSettings) {
        settings = new
        engine.updateSettings(new)
        store.save(new)
        reconcileCard()
    }

    /// Drop reminders the user just switched off from the card on screen; hide it if none remain.
    private func reconcileCard() {
        guard let current = card else { return }
        let kept = current.plan.kinds.filter { settings.reminder($0).isEnabled }
        if kept.isEmpty {
            hideCard()
        } else if kept != current.plan.kinds {
            let longest = kept.map { settings.reminder($0).breakSeconds }.max() ?? 0
            let plan = CardPlan(kinds: kept,
                                countdownSeconds: longest > 0 ? longest : CardPlanner.untimedDisplaySeconds,
                                isTimed: longest > 0)
            // Recompute from startedAt (not the old secondsLeft): the dropped kind may have had a
            // longer break, and the elapsed time already spent must count against the new, shorter one.
            let elapsed = Int(now.timeIntervalSince(current.startedAt).rounded(.down))
            let secondsLeft = max(0, plan.countdownSeconds - elapsed)
            card = CardPresentation(id: current.id, plan: plan, headline: current.headline,
                                    startedAt: current.startedAt, isForced: current.isForced,
                                    secondsLeft: secondsLeft)
            if secondsLeft == 0 { didIt() }   // the shorter countdown already ran out
        }
    }

    func resetSettingsToDefaults() {
        updateSettings(.defaults)
    }

    // MARK: Queries

    var nextUp: [NextUp] {
        settings.enabledKinds.compactMap { kind in
            engine.secondsUntilDue(kind).map { NextUp(kind: kind, seconds: $0) }
        }
    }

    /// "Take a break now" only makes sense while Nudgie is actually counting: paused, off the
    /// clock, or away would either flash a card and hide it again, or leave a kind pending that
    /// ambushes the user once the pause ends.
    var canTakeBreakNow: Bool {
        guard card == nil, !nextUp.isEmpty else { return false }
        switch status {
        case .counting, .quiet: return true
        case .paused, .offTheClock, .away: return false
        }
    }

    var today: DailyStats.DayCount {
        stats.count(on: now, calendar: calendar)
    }

    // MARK: Helpers

    static func status(outcome: TimerEngine.TickOutcome, quiet: QuietReason?) -> EngineStatus {
        switch outcome {
        case .paused(let until): .paused(until: until)
        case .offTheClock: .offTheClock
        case .away, .resetAfterAway: .away
        case .counting: quiet.map { .quiet($0) } ?? .counting
        }
    }

    static func icon(for status: EngineStatus, tick: Int) -> IconState {
        switch status {
        case .quiet: .shh
        case .paused, .offTheClock: .zzz
        case .counting, .away: tick % 30 == 0 ? .blink : .normal
        }
    }

    private func log(_ message: String) {
        if verbose { print("[nudgie] \(message)") }
    }
}
