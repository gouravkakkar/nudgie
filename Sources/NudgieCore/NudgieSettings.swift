import Foundation

/// Lets `[ReminderKind: ReminderSetting]` encode as a JSON object keyed by "eyes", "water", ...
extension ReminderKind: CodingKeyRepresentable {}

/// Per-reminder user choices.
public struct ReminderSetting: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var intervalMinutes: Int
    public var breakSeconds: Int

    public init(isEnabled: Bool = true, intervalMinutes: Int, breakSeconds: Int) {
        self.isEnabled = isEnabled
        self.intervalMinutes = intervalMinutes
        self.breakSeconds = breakSeconds
    }

    public static func `default`(for kind: ReminderKind) -> ReminderSetting {
        ReminderSetting(intervalMinutes: kind.defaultIntervalMinutes, breakSeconds: kind.defaultBreakSeconds)
    }

    public var intervalSeconds: Double { Double(intervalMinutes) * 60 }
}

/// Optional window outside which Nudgie does nothing. Minutes are from local midnight.
/// `weekdays` uses Calendar's numbering: 1 = Sunday ... 7 = Saturday.
public struct WorkHours: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var startMinute: Int
    public var endMinute: Int
    public var weekdays: Set<Int>

    public init(isEnabled: Bool = false, startMinute: Int = 9 * 60, endMinute: Int = 18 * 60,
                weekdays: Set<Int> = [2, 3, 4, 5, 6]) {
        self.isEnabled = isEnabled
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.weekdays = weekdays
    }

    /// True when Nudgie may count and show reminders at `date`.
    public func allows(_ date: Date, calendar: Calendar) -> Bool {
        guard isEnabled else { return true }
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard let weekday = parts.weekday, weekdays.contains(weekday),
              let hour = parts.hour, let minute = parts.minute else { return false }
        let minuteOfDay = hour * 60 + minute
        return minuteOfDay >= startMinute && minuteOfDay < endMinute
    }
}

/// Everything the user can change. Stored as one JSON blob.
public struct NudgieSettings: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    public static let intervalRange = 5...180
    public static let breakRange = 0...3600
    public static let snoozeRange = 1...30
    public static let defaultQuietAppPrefixes: [String] = [
        // Browsers
        "com.apple.Safari", "com.google.Chrome", "org.chromium.Chromium",
        "company.thebrowser.Browser", "com.brave.Browser", "com.microsoft.edgemac",
        "org.mozilla.firefox", "com.operasoftware.Opera", "com.vivaldi.Vivaldi",
        "app.zen-browser.zen", "com.kagi.kagimacOS",
        // Meeting apps
        "us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams",
        "com.tinyspeck.slackmacgap", "com.apple.FaceTime",
        "com.webex.meetingmanager", "com.cisco.webexmeetingsapp", "com.hnc.Discord",
    ]

    public var version: Int
    public var reminders: [ReminderKind: ReminderSetting]
    public var quietOnCameraOrMic: Bool
    public var quietOnQuietApps: Bool
    public var quietAppPrefixes: [String]
    public var workHours: WorkHours
    public var snoozeMinutes: Int
    public var soundEnabled: Bool
    public var soundName: String
    public var launchAtLogin: Bool

    public init(
        version: Int = NudgieSettings.currentVersion,
        reminders: [ReminderKind: ReminderSetting] = Dictionary(
            uniqueKeysWithValues: ReminderKind.allCases.map { ($0, ReminderSetting.default(for: $0)) }),
        quietOnCameraOrMic: Bool = true,
        quietOnQuietApps: Bool = true,
        quietAppPrefixes: [String] = NudgieSettings.defaultQuietAppPrefixes,
        workHours: WorkHours = WorkHours(),
        snoozeMinutes: Int = 5,
        soundEnabled: Bool = true,
        soundName: String = "Pop",
        launchAtLogin: Bool = false
    ) {
        self.version = version
        self.reminders = reminders
        self.quietOnCameraOrMic = quietOnCameraOrMic
        self.quietOnQuietApps = quietOnQuietApps
        self.quietAppPrefixes = quietAppPrefixes
        self.workHours = workHours
        self.snoozeMinutes = snoozeMinutes
        self.soundEnabled = soundEnabled
        self.soundName = soundName
        self.launchAtLogin = launchAtLogin
    }

    public static let defaults = NudgieSettings()

    /// Missing keys fall back to defaults so older or hand-edited JSON still loads.
    /// Out-of-range numbers are clamped: an interval of 0 would otherwise show a card every 30 seconds.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = NudgieSettings.defaults
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? d.version
        reminders = (try c.decodeIfPresent([ReminderKind: ReminderSetting].self, forKey: .reminders) ?? d.reminders)
            .mapValues(Self.clamped)
        quietOnCameraOrMic = try c.decodeIfPresent(Bool.self, forKey: .quietOnCameraOrMic) ?? d.quietOnCameraOrMic
        quietOnQuietApps = try c.decodeIfPresent(Bool.self, forKey: .quietOnQuietApps) ?? d.quietOnQuietApps
        quietAppPrefixes = try c.decodeIfPresent([String].self, forKey: .quietAppPrefixes) ?? d.quietAppPrefixes
        workHours = try c.decodeIfPresent(WorkHours.self, forKey: .workHours) ?? d.workHours
        snoozeMinutes = Self.clamp(try c.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? d.snoozeMinutes, to: Self.snoozeRange)
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? d.soundEnabled
        soundName = try c.decodeIfPresent(String.self, forKey: .soundName) ?? d.soundName
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? d.launchAtLogin
    }

    public func reminder(_ kind: ReminderKind) -> ReminderSetting {
        reminders[kind] ?? ReminderSetting.default(for: kind)
    }

    public mutating func setReminder(_ setting: ReminderSetting, for kind: ReminderKind) {
        reminders[kind] = setting
    }

    /// Enabled reminders in catalogue order.
    public var enabledKinds: [ReminderKind] {
        ReminderKind.allCases.filter { reminder($0).isEnabled }
    }

    public static func decode(_ data: Data) -> NudgieSettings? {
        try? JSONDecoder().decode(NudgieSettings.self, from: data)
    }

    static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private static func clamped(_ setting: ReminderSetting) -> ReminderSetting {
        ReminderSetting(isEnabled: setting.isEnabled,
                        intervalMinutes: clamp(setting.intervalMinutes, to: intervalRange),
                        breakSeconds: clamp(setting.breakSeconds, to: breakRange))
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
