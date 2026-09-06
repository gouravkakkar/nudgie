import Foundation
import Testing
import NudgieCore
@testable import Nudgie

@MainActor @Suite struct StoreTests {
    @Test func settingsRoundTrip() {
        let testDefaults = TestDefaults()
        defer { testDefaults.cleanUp() }
        let store = Store(defaults: testDefaults.defaults)
        var s = NudgieSettings.defaults
        s.snoozeMinutes = 7
        store.save(s)
        #expect(store.loadSettings() == s)
    }

    @Test func missingSettingsGiveDefaults() {
        let testDefaults = TestDefaults()
        defer { testDefaults.cleanUp() }
        #expect(Store(defaults: testDefaults.defaults).loadSettings() == .defaults)
    }

    @Test func brokenSettingsFallBackAndKeepABackup() {
        let testDefaults = TestDefaults()
        defer { testDefaults.cleanUp() }
        let defaults = testDefaults.defaults
        let broken = Data("{broken".utf8)
        defaults.set(broken, forKey: Store.settingsKey)
        let store = Store(defaults: defaults)
        #expect(store.loadSettings() == .defaults)
        #expect(defaults.data(forKey: Store.settingsBackupKey) == broken)
    }

    @Test func statsRoundTrip() {
        let testDefaults = TestDefaults()
        defer { testDefaults.cleanUp() }
        let store = Store(defaults: testDefaults.defaults)
        var stats = DailyStats()
        stats.record(taken: 2, snoozed: 1, on: Date(), calendar: .current)
        store.save(stats)
        #expect(store.loadStats() == stats)
    }
}
