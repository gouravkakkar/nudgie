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

    @Test func versionIsSet() {
        #expect(NudgieCore.version == "0.1.0")
    }
}
