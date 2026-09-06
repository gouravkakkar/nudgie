import Foundation

/// How many breaks were taken or snoozed, per local day. Only today and yesterday are kept.
public struct DailyStats: Codable, Equatable, Sendable {
    public struct DayCount: Codable, Equatable, Sendable {
        public var taken: Int
        public var snoozed: Int
        public init(taken: Int = 0, snoozed: Int = 0) {
            self.taken = taken
            self.snoozed = snoozed
        }
    }

    public private(set) var days: [String: DayCount] = [:]

    public init() {}

    /// "2026-09-07" style key in the calendar's time zone.
    public static func key(for date: Date, calendar: Calendar) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }

    public mutating func record(taken: Int = 0, snoozed: Int = 0, on date: Date, calendar: Calendar) {
        let key = Self.key(for: date, calendar: calendar)
        var count = days[key] ?? DayCount()
        count.taken += taken
        count.snoozed += snoozed
        days[key] = count
        prune(keeping: date, calendar: calendar)
    }

    public func count(on date: Date, calendar: Calendar) -> DayCount {
        days[Self.key(for: date, calendar: calendar)] ?? DayCount()
    }

    private mutating func prune(keeping date: Date, calendar: Calendar) {
        let today = Self.key(for: date, calendar: calendar)
        let yesterday = Self.key(for: calendar.date(byAdding: .day, value: -1, to: date) ?? date, calendar: calendar)
        days = days.filter { $0.key == today || $0.key == yesterday }
    }
}
