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
}
