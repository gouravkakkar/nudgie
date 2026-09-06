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
        prune(currentDate: date, currentKey: key, calendar: calendar)
    }

    public func count(on date: Date, calendar: Calendar) -> DayCount {
        days[Self.key(for: date, calendar: calendar)] ?? DayCount()
    }

    /// Keeps only the latest day seen across every `record` call (not just this one) and the day
    /// before it. Anchoring on the latest key, rather than on `currentKey`, stops an older
    /// out-of-order `record` from pruning away a newer day that was already stored.
    private mutating func prune(currentDate: Date, currentKey: String, calendar: Calendar) {
        let latestKey = max(currentKey, days.keys.max() ?? currentKey)
        let anchorKey: String
        let previousKey: String
        if let previous = Self.previousDayKey(before: latestKey, calendar: calendar) {
            anchorKey = latestKey
            previousKey = previous
        } else {
            // The stored key didn't parse (e.g. corrupted data) — fall back to anchoring on the
            // current date rather than risk deleting everything.
            anchorKey = currentKey
            previousKey = Self.key(for: calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate, calendar: calendar)
        }
        days = days.filter { $0.key == anchorKey || $0.key == previousKey }
    }

    /// Parses a "yyyy-MM-dd" key back into a date, steps it back one day, and re-keys it.
    /// Returns `nil` if `key` isn't a well-formed date in this calendar.
    private static func previousDayKey(before key: String, calendar: Calendar) -> String? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              let previousDate = calendar.date(byAdding: .day, value: -1, to: date)
        else {
            return nil
        }
        return Self.key(for: previousDate, calendar: calendar)
    }
}
