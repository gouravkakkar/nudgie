import Foundation
import Testing
@testable import NudgieCore

@Suite struct NudgieSettingsTests {
    @Test func defaultsMatchSpec() {
        let s = NudgieSettings.defaults
        #expect(s.version == NudgieSettings.currentVersion)
        for kind in ReminderKind.allCases {
            #expect(s.reminder(kind).isEnabled)
            #expect(s.reminder(kind).intervalMinutes == kind.defaultIntervalMinutes)
            #expect(s.reminder(kind).breakSeconds == kind.defaultBreakSeconds)
        }
        #expect(s.quietOnCameraOrMic)
        #expect(s.quietOnQuietApps)
        #expect(s.quietAppPrefixes.contains("com.apple.Safari"))
        #expect(s.quietAppPrefixes.contains("us.zoom.xos"))
        #expect(!s.workHours.isEnabled)
        #expect(s.snoozeMinutes == 5)
        #expect(s.soundEnabled)
        #expect(s.soundName == "Pop")
        #expect(!s.launchAtLogin)
        #expect(s.enabledKinds == ReminderKind.allCases)
    }

    @Test func roundTripsThroughJSON() throws {
        var s = NudgieSettings.defaults
        s.setReminder(ReminderSetting(isEnabled: false, intervalMinutes: 33, breakSeconds: 7), for: .walk)
        s.snoozeMinutes = 9
        s.workHours = WorkHours(isEnabled: true, startMinute: 8 * 60, endMinute: 17 * 60, weekdays: [2, 3])
        let data = try s.encoded()
        #expect(NudgieSettings.decode(data) == s)
    }

    @Test func remindersEncodeAsObjectKeyedByKindName() throws {
        let data = try NudgieSettings.defaults.encoded()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let reminders = json?["reminders"] as? [String: Any]
        #expect(reminders?["eyes"] != nil)
        #expect(reminders?.count == 5)
    }

    @Test func unknownFieldsAreIgnoredAndMissingFieldsGetDefaults() {
        let json = #"{"version":1,"snoozeMinutes":12,"someFutureField":true}"#
        let s = NudgieSettings.decode(Data(json.utf8))
        #expect(s?.snoozeMinutes == 12)
        #expect(s?.soundName == "Pop")
        #expect(s?.reminder(.eyes).intervalMinutes == 20)
    }

    @Test func brokenJSONDecodesToNil() {
        #expect(NudgieSettings.decode(Data("{not json".utf8)) == nil)
    }

    @Test func reminderFallsBackToDefaultWhenKindMissing() {
        var s = NudgieSettings.defaults
        s.reminders[.stretch] = nil
        #expect(s.reminder(.stretch) == ReminderSetting.default(for: .stretch))
        #expect(s.enabledKinds.contains(.stretch))
    }

    @Test func decodeClampsOutOfRangeValues() {
        let json = #"{"snoozeMinutes":0,"reminders":{"eyes":{"isEnabled":true,"intervalMinutes":0,"breakSeconds":99999}}}"#
        let s = NudgieSettings.decode(Data(json.utf8))
        #expect(s?.snoozeMinutes == 1)
        #expect(s?.reminder(.eyes).intervalMinutes == 5)
        #expect(s?.reminder(.eyes).breakSeconds == 3600)
    }

    @Test func workHoursAllowsEverythingWhenDisabled() {
        let w = WorkHours(isEnabled: false)
        #expect(w.allows(TestClock.date(2026, 9, 12, 3, 0), calendar: TestClock.utc))
    }

    @Test func workHoursWindowWeekdaysNineToSix() {
        let w = WorkHours(isEnabled: true, startMinute: 9 * 60, endMinute: 18 * 60, weekdays: [2, 3, 4, 5, 6])
        #expect(w.allows(TestClock.date(2026, 9, 7, 10, 0), calendar: TestClock.utc))    // Monday 10:00
        #expect(w.allows(TestClock.date(2026, 9, 7, 9, 0), calendar: TestClock.utc))     // Monday 09:00 inclusive start
        #expect(!w.allows(TestClock.date(2026, 9, 7, 18, 0), calendar: TestClock.utc))   // Monday 18:00 exclusive end
        #expect(!w.allows(TestClock.date(2026, 9, 7, 8, 59), calendar: TestClock.utc))
        #expect(!w.allows(TestClock.date(2026, 9, 12, 10, 0), calendar: TestClock.utc))  // Saturday
    }

    @Test func workHoursWithEndBeforeStartAllowsNothing() {
        // The settings window prevents this, but a hand-edited file must not crash or misbehave.
        let w = WorkHours(isEnabled: true, startMinute: 18 * 60, endMinute: 9 * 60, weekdays: [2])
        #expect(!w.allows(TestClock.date(2026, 9, 7, 10, 0), calendar: TestClock.utc))
    }

    @Test func partialReminderObjectFallsBackToKindDefaults() {
        // A hand-edited or corrupted settings file may have a reminder object missing
        // "intervalMinutes"/"breakSeconds". That must fall back to the kind's own defaults
        // instead of throwing keyNotFound and losing the whole settings file.
        let json = #"{"reminders":{"eyes":{"isEnabled":false}}}"#
        let s = NudgieSettings.decode(Data(json.utf8))
        #expect(s?.reminder(.eyes).isEnabled == false)
        #expect(s?.reminder(.eyes).intervalMinutes == 20)
        #expect(s?.reminder(.eyes).breakSeconds == 20)
        #expect(s?.reminder(.water) == ReminderSetting.default(for: .water))
    }

    @Test func partialWorkHoursFallsBackToDefaults() {
        // Same idea for workHours: a missing "startMinute" must not sink the whole decode.
        let json = #"{"workHours":{"isEnabled":true}}"#
        let s = NudgieSettings.decode(Data(json.utf8))
        #expect(s?.workHours.isEnabled == true)
        #expect(s?.workHours.startMinute == 540)
        #expect(s?.workHours.endMinute == 1080)
        #expect(s?.workHours.weekdays == [2, 3, 4, 5, 6])
    }
}
