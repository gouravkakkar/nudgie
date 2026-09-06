import Foundation
import NudgieCore

/// Settings and stats as JSON blobs in UserDefaults. The only thing Nudgie writes to disk.
struct Store {
    static let settingsKey = "nudgie.settings"
    static let settingsBackupKey = "nudgie.settings.backup"
    static let statsKey = "nudgie.stats"

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadSettings() -> NudgieSettings {
        guard let data = defaults.data(forKey: Self.settingsKey) else { return .defaults }
        if let settings = NudgieSettings.decode(data) { return settings }
        // Keep the broken blob so nothing is silently lost, then start from defaults.
        defaults.set(data, forKey: Self.settingsBackupKey)
        return .defaults
    }

    func save(_ settings: NudgieSettings) {
        if let data = try? settings.encoded() {
            defaults.set(data, forKey: Self.settingsKey)
        }
    }

    func loadStats() -> DailyStats {
        guard let data = defaults.data(forKey: Self.statsKey),
              let stats = try? JSONDecoder().decode(DailyStats.self, from: data) else { return DailyStats() }
        return stats
    }

    func save(_ stats: DailyStats) {
        if let data = try? JSONEncoder().encode(stats) {
            defaults.set(data, forKey: Self.statsKey)
        }
    }
}
