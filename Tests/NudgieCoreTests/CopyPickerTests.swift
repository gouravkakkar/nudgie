import Testing
@testable import NudgieCore

/// Deterministic generator so the test is repeatable.
struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Suite struct CopyPickerTests {
    @Test func everyKindHasAtLeastThreeLines() {
        for kind in ReminderKind.allCases {
            #expect((CopyPicker.lines[kind]?.count ?? 0) >= 3, "\(kind) needs 3+ lines")
        }
    }

    @Test func neverRepeatsThePreviousLine() {
        var picker = CopyPicker()
        var rng = SplitMix64(state: 42)
        for kind in ReminderKind.allCases {
            var previous = picker.line(for: kind, using: &rng)
            for _ in 0..<200 {
                let next = picker.line(for: kind, using: &rng)
                #expect(next != previous)
                previous = next
            }
        }
    }

    @Test func eventuallyUsesEveryLine() {
        var picker = CopyPicker()
        var rng = SplitMix64(state: 7)
        var seen = Set<String>()
        for _ in 0..<300 { seen.insert(picker.line(for: .eyes, using: &rng)) }
        #expect(seen == Set(CopyPicker.lines[.eyes]!))
    }

    @Test func linesAreRealText() {
        for (_, lines) in CopyPicker.lines {
            for line in lines { #expect(line.count > 10) }
        }
    }

    @Test func everyKindHasThreeBenefits() {
        for kind in ReminderKind.allCases {
            #expect((CopyPicker.benefits[kind]?.count ?? 0) >= 3, "\(kind) needs 3+ benefit lines")
        }
    }

    @Test func benefitNeverRepeatsThePreviousLine() {
        var picker = CopyPicker()
        var rng = SplitMix64(state: 99)
        for kind in ReminderKind.allCases {
            var previous = picker.benefit(for: kind, using: &rng)
            for _ in 0..<200 {
                let next = picker.benefit(for: kind, using: &rng)
                #expect(next != previous)
                previous = next
            }
        }
    }

    @Test func eventuallyUsesEveryBenefit() {
        var picker = CopyPicker()
        var rng = SplitMix64(state: 11)
        var seen = Set<String>()
        for _ in 0..<300 { seen.insert(picker.benefit(for: .water, using: &rng)!) }
        #expect(seen == Set(CopyPicker.benefits[.water]!))
    }

    /// A card can appear at 9am or 10pm, so a benefit line must not claim to know which.
    /// "Keeps your energy steady through the afternoon" was wrong on a card shown at 8pm.
    @Test func benefitsNeverAssumeATimeOfDay() {
        let clockWords = ["morning", "afternoon", "evening", "tonight", "midday",
                          "noon", "o'clock", " am ", " pm", "end of the day",
                          "start of the day", "rest of the day"]
        for (kind, lines) in CopyPicker.benefits {
            for line in lines {
                let lowered = line.lowercased()
                for word in clockWords {
                    #expect(!lowered.contains(word), "\(kind) benefit assumes a time of day: \(line)")
                }
            }
        }
    }
}
