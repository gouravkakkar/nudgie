import Foundation
import Testing
@testable import NudgieCore

@Suite struct DailyStatsTests {
    static let utc = TestClock.utc
    static func day(_ d: Int, hour: Int = 12) -> Date { TestClock.date(2026, 9, d, hour) }

    @Test func keyIsISODate() {
        #expect(DailyStats.key(for: Self.day(7), calendar: Self.utc) == "2026-09-07")
    }

    @Test func recordAccumulatesWithinADay() {
        var s = DailyStats()
        s.record(taken: 1, on: Self.day(7, hour: 9), calendar: Self.utc)
        s.record(taken: 2, snoozed: 1, on: Self.day(7, hour: 17), calendar: Self.utc)
        #expect(s.count(on: Self.day(7), calendar: Self.utc) == DailyStats.DayCount(taken: 3, snoozed: 1))
    }

    @Test func unknownDayIsZero() {
        #expect(DailyStats().count(on: Self.day(7), calendar: Self.utc) == DailyStats.DayCount(taken: 0, snoozed: 0))
    }

    @Test func keepsOnlyTodayAndYesterday() {
        var s = DailyStats()
        s.record(taken: 1, on: Self.day(5), calendar: Self.utc)
        s.record(taken: 1, on: Self.day(6), calendar: Self.utc)
        s.record(taken: 1, on: Self.day(7), calendar: Self.utc)
        #expect(s.days.keys.sorted() == ["2026-09-06", "2026-09-07"])
    }

    @Test func roundTripsThroughJSON() throws {
        var s = DailyStats()
        s.record(taken: 4, snoozed: 2, on: Self.day(7), calendar: Self.utc)
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(DailyStats.self, from: data) == s)
    }
}
