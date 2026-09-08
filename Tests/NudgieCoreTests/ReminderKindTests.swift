import Testing
@testable import NudgieCore

@Suite struct ReminderKindTests {
    @Test func hasExactlyFiveKindsInSpecOrder() {
        #expect(ReminderKind.allCases == [.eyes, .water, .walk, .posture, .stretch])
    }

    @Test(arguments: [
        (ReminderKind.eyes, 20, 20),
        (ReminderKind.water, 45, 0),
        (ReminderKind.walk, 60, 180),
        (ReminderKind.posture, 30, 0),
        (ReminderKind.stretch, 60, 60),
    ])
    func defaultsMatchSpec(kind: ReminderKind, interval: Int, breakSeconds: Int) {
        #expect(kind.defaultIntervalMinutes == interval)
        #expect(kind.defaultBreakSeconds == breakSeconds)
    }

    @Test func everyKindHasTitleEmojiAndInstruction() {
        for kind in ReminderKind.allCases {
            #expect(!kind.title.isEmpty)
            #expect(!kind.emoji.isEmpty)
            #expect(!kind.instruction.isEmpty)
        }
    }

    @Test func rawValuesAreStableForPersistence() {
        #expect(ReminderKind.eyes.rawValue == "eyes")
        #expect(ReminderKind(rawValue: "posture") == .posture)
    }

    /// Checks the shape, not a literal: pinning the number here meant every release began with
    /// a failing test, which teaches you to edit the test rather than to read it.
    @Test func versionIsSet() {
        let version = NudgieCore.version
        #expect(version.wholeMatch(of: /\d+\.\d+\.\d+/) != nil, "expected a semver, got \(version)")
        #expect(version != "0.0.0")
    }
}
