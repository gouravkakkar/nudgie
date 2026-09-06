import Foundation
import Testing
import NudgieCore
@testable import Nudgie

@MainActor @Suite struct StoreTests {
    func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "nudgie.tests.\(UUID().uuidString)")!
    }

    @Test func settingsRoundTrip() {
        let store = Store(defaults: freshDefaults())
        var s = NudgieSettings.defaults
        s.snoozeMinutes = 7
        store.save(s)
        #expect(store.loadSettings() == s)
    }

    @Test func missingSettingsGiveDefaults() {
        #expect(Store(defaults: freshDefaults()).loadSettings() == .defaults)
    }

    @Test func brokenSettingsFallBackAndKeepABackup() {
        let defaults = freshDefaults()
        let broken = Data("{broken".utf8)
        defaults.set(broken, forKey: Store.settingsKey)
        let store = Store(defaults: defaults)
        #expect(store.loadSettings() == .defaults)
        #expect(defaults.data(forKey: Store.settingsBackupKey) == broken)
    }

    @Test func statsRoundTrip() {
        let store = Store(defaults: freshDefaults())
        var stats = DailyStats()
        stats.record(taken: 2, snoozed: 1, on: Date(), calendar: .current)
        store.save(stats)
        #expect(store.loadStats() == stats)
    }
}
