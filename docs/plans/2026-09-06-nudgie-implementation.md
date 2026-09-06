# Nudgie Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Nudgie, a free, quirky macOS menu-bar app that nudges you to rest your eyes, walk, drink water, fix posture and stretch, counting only active screen time and staying quiet during meetings.

**Architecture:** One Swift package. `NudgieCore` is a pure-logic library (no AppKit) that owns settings, the active-time timer engine, the meeting quiet policy, card planning, copy and stats, all driven by plain values so tests use fake clocks. `Nudgie` is the thin app target: OS probes (idle time, lock/sleep, camera, mic, front app), a 1-second coordinator, a non-activating floating card panel, the menu bar item and a settings window. A shell script assembles `build/Nudgie.app`.

**Tech Stack:** Swift 6.2 (language mode 6), Swift Package Manager (`swift-tools-version: 6.2`), SwiftUI + AppKit, Swift Testing (`import Testing`), CoreMediaIO, CoreAudio, CoreGraphics, ServiceManagement. macOS 14+ deployment target. No third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-09-06-nudgie-design.md` (read it first; this plan argues from it).

## Global Constraints

- Swift language mode 6. The `Nudgie` app target uses `.defaultIsolation(MainActor.self)`. `NudgieCore` must not import AppKit or SwiftUI.
- Deployment target `.macOS(.v14)`. Bundle id `com.gouravkakkar.nudgie`. App name `Nudgie`. Version `0.1.0`.
- Reminder defaults (interval min / break s): eyes 20/20, water 45/0, walk 60/180, posture 30/0, stretch 60/60. Interval range 5–180 min. Snooze default 5 min.
- Away threshold 300 s (5 min) resets all accumulators. Active = not locked, not asleep, idle < 300 s.
- Card: breathing gap 30 s between cards, settle gap 30 s after quiet ends, untimed reminders display 30 s then count as done.
- Quiet rules in v1: camera-or-mic busy, quiet-app-in-front (bundle id prefix match). No Focus rule.
- Card panel: `NSPanel`, `.nonactivatingPanel`, level `.floating`, `[.canJoinAllSpaces, .fullScreenAuxiliary]`, top-right of the menu-bar screen, 16 pt inset, about 340 × 170 pt. Never takes keyboard focus.
- Accents: eyes electric mint `#3DF5B4`, water sky `#4DB8FF`, walk tangerine `#FF8C42`, posture bubblegum `#FF6FB5`, stretch lemon `#FFE24D`. Ink `#1B1B1F`, cream `#FFF8EE`. Text contrast ≥ 4.5:1. SF Rounded.
- Sound default on, default name `Pop`, files in `/System/Library/Sounds/<name>.aiff`. Never play while quiet.
- Respect Reduce Motion (no wobble, no confetti).
- Nothing leaves the machine. Only `UserDefaults` is written.
- Licence: PolyForm Shield 1.0.0. README says "free and source-available", never "open source".
- Every commit message ends with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Never `git push`.
- Commands run from the repo root `/Users/gouravkakkar/PycharmProjects/Mac health app` (note the spaces: quote the path).

## Verified on this Mac (2026-09-06)

These were run before writing the plan, so the code below is known to work here:

- `swift-tools-version: 6.2` package with `.defaultIsolation(MainActor.self)` on an executable target builds; `swift test` with Swift Testing passes; a `MenuBarExtra` app compiles in a SwiftPM executable.
- `CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)` returns idle seconds.
- CoreMediaIO `kCMIODevicePropertyDeviceIsRunningSomewhere` answers status 0 for all 4 camera devices; CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` answers for both input devices. No permission prompt.
- `~/Library/DoNotDisturb/DB/` is blocked ("Operation not permitted") without Full Disk Access, hence no Focus rule.
- `/System/Library/Sounds` contains Basso Blow Bottle Frog Funk Glass Hero Morse Ping Pop Purr Sosumi Submarine Tink.

## File map

```
Package.swift                              targets: NudgieCore, Nudgie, NudgieCoreTests
Makefile                                   test / build / app / run / install / clean
.gitignore
Sources/NudgieCore/
  ReminderKind.swift                       the five reminders and their defaults
  NudgieSettings.swift                     Codable settings + ReminderSetting + WorkHours
  ActivityState.swift                      idle/locked/asleep value
  QuietState.swift                         camera/mic/frontmost value + QuietReason
  QuietPolicy.swift                        state + settings -> QuietReason?
  TimerEngine.swift                        accumulators, pending, done/snooze/pause/work hours
  CardPlanner.swift                        when to show, grouping, countdown
  CopyPicker.swift                         cheeky lines, no immediate repeats
  DailyStats.swift                         taken/snoozed per day
Sources/Nudgie/
  main.swift                               --probe / --demo / app entry
  NudgieApp.swift                          App scenes: MenuBarExtra + Settings
  AppDelegate.swift                        accessory activation policy
  Coordinator.swift                        1 s heartbeat, owns engine/planner/card
  Probes/ActivityProbe.swift               idle + lock + sleep
  Probes/QuietProbe.swift                  camera + mic + frontmost
  Persistence/Store.swift                  UserDefaults JSON
  Sound.swift                              NSSound wrapper
  UI/Theme.swift                           colours, fonts, sticker modifier
  UI/MascotView.swift                      the blob and its poses
  UI/ConfettiView.swift                    burst on Did it!
  UI/CardView.swift                        card content
  UI/CardPanel.swift                       NSPanel host + placement
  UI/MenuBarIcon.swift                     template icon frames
  UI/MenuBarView.swift                     menu contents
  UI/SettingsView.swift                    three tabs
Tests/NudgieCoreTests/
  ReminderKindTests.swift, NudgieSettingsTests.swift, QuietPolicyTests.swift,
  TimerEngineTests.swift, CardPlannerTests.swift, CopyPickerTests.swift, DailyStatsTests.swift
Resources/Info.plist                       LSUIElement etc.
Resources/Nudgie.icns                      generated once by tools/make-icon.swift, committed
tools/make-app.sh                          assemble + ad-hoc sign build/Nudgie.app
tools/make-icon.swift                      render mascot -> .icns
docs/user-guide.md, docs/qa-checklist.md, README.md, LICENSE, CONTRIBUTING.md, CHANGELOG.md
.github/workflows/ci.yml
```

---

### Task 1: Package scaffold, Makefile, smoke test

**Files:**
- Create: `Package.swift`, `Makefile`, `.gitignore`
- Create: `Sources/NudgieCore/ReminderKind.swift` (placeholder, replaced in Task 2)
- Create: `Sources/Nudgie/main.swift` (placeholder, replaced in Task 8)
- Test: `Tests/NudgieCoreTests/SmokeTests.swift`

**Interfaces:**
- Produces: package targets `NudgieCore` (library), `Nudgie` (executable), `NudgieCoreTests`; `make test`, `make build`.

- [ ] **Step 1: Write the failing smoke test**

`Tests/NudgieCoreTests/SmokeTests.swift`:
```swift
import Testing
@testable import NudgieCore

@Test func coreModuleLinks() {
    #expect(NudgieCore.version == "0.1.0")
}
```

- [ ] **Step 2: Create Package.swift**

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Nudgie",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "NudgieCore", targets: ["NudgieCore"]),
        .executable(name: "Nudgie", targets: ["Nudgie"]),
    ],
    targets: [
        .target(name: "NudgieCore"),
        .executableTarget(
            name: "Nudgie",
            dependencies: ["NudgieCore"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(name: "NudgieCoreTests", dependencies: ["NudgieCore"]),
    ]
)
```

- [ ] **Step 3: Create the two placeholder sources**

`Sources/NudgieCore/ReminderKind.swift`:
```swift
/// Placeholder so the module has a symbol. Replaced in Task 2.
public enum NudgieCore {
    public static let version = "0.1.0"
}
```

`Sources/Nudgie/main.swift`:
```swift
import NudgieCore
print("Nudgie \(NudgieCore.version)")
```

- [ ] **Step 4: Create Makefile and .gitignore**

`Makefile` (tabs, not spaces, before each command):
```makefile
APP_NAME=Nudgie
BUILD_DIR=build

.PHONY: test build app run install clean

test:
	swift test

build:
	swift build

app:
	./tools/make-app.sh

run: app
	open $(BUILD_DIR)/$(APP_NAME).app

install: app
	rm -rf /Applications/$(APP_NAME).app
	cp -R $(BUILD_DIR)/$(APP_NAME).app /Applications/

clean:
	rm -rf .build $(BUILD_DIR)
```

`.gitignore`:
```
.build/
build/
*.xcodeproj
.swiftpm/
.DS_Store
```

- [ ] **Step 5: Run the test and verify it passes**

Run: `swift test 2>&1 | tail -3`
Expected: `✔ Test run with 1 test in 0 suites passed`.

Run: `swift build 2>&1 | tail -1 && .build/debug/Nudgie`
Expected: `Build complete!` then `Nudgie 0.1.0`.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Makefile .gitignore Sources Tests
git commit -m "chore: scaffold Swift package with core, app and test targets

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: ReminderKind catalogue

**Files:**
- Replace: `Sources/NudgieCore/ReminderKind.swift`
- Test: `Tests/NudgieCoreTests/ReminderKindTests.swift`
- Delete: `Tests/NudgieCoreTests/SmokeTests.swift` (the `NudgieCore.version` placeholder moves into this file)

**Interfaces:**
- Produces: `public enum ReminderKind: String, CaseIterable, Codable, Sendable { case eyes, water, walk, posture, stretch }` with `title: String`, `emoji: String`, `instruction: String`, `defaultIntervalMinutes: Int`, `defaultBreakSeconds: Int`; `public enum NudgieCore { static let version }`.

- [ ] **Step 1: Write the failing tests**

`Tests/NudgieCoreTests/ReminderKindTests.swift`:
```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `rm Tests/NudgieCoreTests/SmokeTests.swift && swift test 2>&1 | grep -E "error|passed|failed" | head`
Expected: compile errors such as `cannot find 'ReminderKind' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/NudgieCore/ReminderKind.swift`:
```swift
/// Library-wide constants.
public enum NudgieCore {
    public static let version = "0.1.0"
}

/// The five things Nudgie nudges you about. Order here is display order.
public enum ReminderKind: String, CaseIterable, Codable, Sendable {
    case eyes, water, walk, posture, stretch

    public var title: String {
        switch self {
        case .eyes: "Eyes"
        case .water: "Water"
        case .walk: "Walk"
        case .posture: "Posture"
        case .stretch: "Stretch"
        }
    }

    public var emoji: String {
        switch self {
        case .eyes: "👀"
        case .water: "💧"
        case .walk: "🚶"
        case .posture: "🪑"
        case .stretch: "🙆"
        }
    }

    /// The plain instruction shown under the cheeky line.
    public var instruction: String {
        switch self {
        case .eyes: "Look at something 20 feet away for 20 seconds."
        case .water: "Drink a glass of water."
        case .walk: "Stand up and walk for a few minutes."
        case .posture: "Sit up, shoulders back, screen at eye level."
        case .stretch: "Stretch your neck, shoulders and wrists."
        }
    }

    public var defaultIntervalMinutes: Int {
        switch self {
        case .eyes: 20
        case .water: 45
        case .walk: 60
        case .posture: 30
        case .stretch: 60
        }
    }

    /// 0 means "no timed break": the card shows for a fixed time, then counts as done.
    public var defaultBreakSeconds: Int {
        switch self {
        case .eyes: 20
        case .water: 0
        case .walk: 180
        case .posture: 0
        case .stretch: 60
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -2`
Expected: `✔ Test run with 9 tests in 1 suite passed` (5 parameterised cases + 4).

- [ ] **Step 5: Commit**

```bash
git add Sources/NudgieCore/ReminderKind.swift Tests/NudgieCoreTests
git commit -m "feat(core): add ReminderKind catalogue with spec defaults

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: NudgieSettings (Codable settings model)

**Files:**
- Create: `Sources/NudgieCore/NudgieSettings.swift`
- Test: `Tests/NudgieCoreTests/NudgieSettingsTests.swift`

**Interfaces:**
- Consumes: `ReminderKind` (Task 2).
- Produces:
  - `public struct ReminderSetting: Codable, Equatable, Sendable { var isEnabled: Bool; var intervalMinutes: Int; var breakSeconds: Int; var intervalSeconds: Double; static func `default`(for:) }`
  - `public struct WorkHours: Codable, Equatable, Sendable { var isEnabled; var startMinute; var endMinute; var weekdays: Set<Int>; func allows(_ date: Date, calendar: Calendar) -> Bool }`
  - `public struct NudgieSettings: Codable, Equatable, Sendable` with fields `version, reminders: [ReminderKind: ReminderSetting], quietOnCameraOrMic, quietOnQuietApps, quietAppPrefixes: [String], workHours, snoozeMinutes, soundEnabled, soundName, launchAtLogin`; `static let defaults`, `static let intervalRange = 5...180`, `static let defaultQuietAppPrefixes: [String]`, `func reminder(_:) -> ReminderSetting`, `mutating func setReminder(_:for:)`, `var enabledKinds: [ReminderKind]`, `static func decode(_ data: Data) -> NudgieSettings?`, `func encoded() throws -> Data`.

- [ ] **Step 1: Write the failing tests**

`Tests/NudgieCoreTests/NudgieSettingsTests.swift`:
```swift
import Foundation
import Testing
@testable import NudgieCore

@Suite struct NudgieSettingsTests {
    // 2026-09-07 is a Monday, 2026-09-12 a Saturday.
    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

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

    @Test func workHoursAllowsEverythingWhenDisabled() {
        let w = WorkHours(isEnabled: false)
        #expect(w.allows(Self.date(2026, 9, 12, 3, 0), calendar: Self.utc))
    }

    @Test func workHoursWindowWeekdaysNineToSix() {
        let w = WorkHours(isEnabled: true, startMinute: 9 * 60, endMinute: 18 * 60, weekdays: [2, 3, 4, 5, 6])
        #expect(w.allows(Self.date(2026, 9, 7, 10, 0), calendar: Self.utc))    // Monday 10:00
        #expect(w.allows(Self.date(2026, 9, 7, 9, 0), calendar: Self.utc))     // Monday 09:00 inclusive start
        #expect(!w.allows(Self.date(2026, 9, 7, 18, 0), calendar: Self.utc))   // Monday 18:00 exclusive end
        #expect(!w.allows(Self.date(2026, 9, 7, 8, 59), calendar: Self.utc))
        #expect(!w.allows(Self.date(2026, 9, 12, 10, 0), calendar: Self.utc))  // Saturday
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'NudgieSettings' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/NudgieCore/NudgieSettings.swift`:
```swift
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
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = NudgieSettings.defaults
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? d.version
        reminders = try c.decodeIfPresent([ReminderKind: ReminderSetting].self, forKey: .reminders) ?? d.reminders
        quietOnCameraOrMic = try c.decodeIfPresent(Bool.self, forKey: .quietOnCameraOrMic) ?? d.quietOnCameraOrMic
        quietOnQuietApps = try c.decodeIfPresent(Bool.self, forKey: .quietOnQuietApps) ?? d.quietOnQuietApps
        quietAppPrefixes = try c.decodeIfPresent([String].self, forKey: .quietAppPrefixes) ?? d.quietAppPrefixes
        workHours = try c.decodeIfPresent(WorkHours.self, forKey: .workHours) ?? d.workHours
        snoozeMinutes = try c.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? d.snoozeMinutes
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

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -2`
Expected: all tests pass (9 from Task 2 + 8 here = 17).

If `remindersEncodeAsObjectKeyedByKindName` fails because the dictionary encoded as an array, the `CodingKeyRepresentable` extension is missing. Do not switch to `[String: ReminderSetting]`.

- [ ] **Step 5: Commit**

```bash
git add Sources/NudgieCore/NudgieSettings.swift Tests/NudgieCoreTests/NudgieSettingsTests.swift
git commit -m "feat(core): add Codable NudgieSettings with defaults and work hours

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: ActivityState, QuietState and QuietPolicy

**Files:**
- Create: `Sources/NudgieCore/ActivityState.swift`, `Sources/NudgieCore/QuietState.swift`, `Sources/NudgieCore/QuietPolicy.swift`
- Test: `Tests/NudgieCoreTests/QuietPolicyTests.swift`

**Interfaces:**
- Consumes: `NudgieSettings` (Task 3).
- Produces:
  - `public struct ActivityState: Equatable, Sendable { var idleSeconds: Double; var isLocked: Bool; var isAsleep: Bool; static let awayThresholdSeconds: Double = 300; var isAway: Bool }`
  - `public struct QuietState: Equatable, Sendable { var cameraBusy: Bool; var micBusy: Bool; var frontmostBundleID: String? }`
  - `public enum QuietReason: Equatable, Sendable { case cameraBusy, micBusy, quietApp(bundleID: String); var label: String }`
  - `public enum QuietPolicy { static func reason(for state: QuietState, settings: NudgieSettings) -> QuietReason?; static func matches(bundleID: String, prefixes: [String]) -> Bool }`

- [ ] **Step 1: Write the failing tests**

`Tests/NudgieCoreTests/QuietPolicyTests.swift`:
```swift
import Testing
@testable import NudgieCore

@Suite struct QuietPolicyTests {
    let settings = NudgieSettings.defaults

    @Test func nothingBusyMeansNotQuiet() {
        #expect(QuietPolicy.reason(for: QuietState(), settings: settings) == nil)
    }

    @Test func cameraBusyIsQuiet() {
        let s = QuietState(cameraBusy: true, frontmostBundleID: "com.apple.Terminal")
        #expect(QuietPolicy.reason(for: s, settings: settings) == .cameraBusy)
    }

    @Test func micBusyIsQuiet() {
        let s = QuietState(micBusy: true)
        #expect(QuietPolicy.reason(for: s, settings: settings) == .micBusy)
    }

    @Test func cameraRuleCanBeDisabled() {
        var off = settings
        off.quietOnCameraOrMic = false
        let s = QuietState(cameraBusy: true, micBusy: true)
        #expect(QuietPolicy.reason(for: s, settings: off) == nil)
    }

    @Test func browserInFrontIsQuiet() {
        let s = QuietState(frontmostBundleID: "com.google.Chrome")
        #expect(QuietPolicy.reason(for: s, settings: settings) == .quietApp(bundleID: "com.google.Chrome"))
    }

    @Test func chromeWebAppMatchesByPrefix() {
        let id = "com.google.Chrome.app.kjgfgldnnfoeklkmfkjfagphfepbbdan"
        let s = QuietState(frontmostBundleID: id)
        #expect(QuietPolicy.reason(for: s, settings: settings) == .quietApp(bundleID: id))
    }

    @Test func prefixMatchIsCaseInsensitive() {
        #expect(QuietPolicy.matches(bundleID: "US.ZOOM.XOS", prefixes: ["us.zoom.xos"]))
        #expect(!QuietPolicy.matches(bundleID: "com.apple.Terminal", prefixes: ["com.apple.Safari"]))
    }

    @Test func nonQuietAppInFrontIsNotQuiet() {
        let s = QuietState(frontmostBundleID: "com.apple.Terminal")
        #expect(QuietPolicy.reason(for: s, settings: settings) == nil)
    }

    @Test func appRuleCanBeDisabled() {
        var off = settings
        off.quietOnQuietApps = false
        let s = QuietState(frontmostBundleID: "us.zoom.xos")
        #expect(QuietPolicy.reason(for: s, settings: off) == nil)
    }

    @Test func cameraWinsOverAppWhenBoth() {
        let s = QuietState(cameraBusy: true, frontmostBundleID: "us.zoom.xos")
        #expect(QuietPolicy.reason(for: s, settings: settings) == .cameraBusy)
    }

    @Test func activityAwayRules() {
        #expect(!ActivityState(idleSeconds: 299).isAway)
        #expect(ActivityState(idleSeconds: 300).isAway)
        #expect(ActivityState(idleSeconds: 1, isLocked: true).isAway)
        #expect(ActivityState(idleSeconds: 1, isAsleep: true).isAway)
    }

    @Test func labelsAreHumanReadable() {
        #expect(QuietReason.cameraBusy.label == "Camera is on")
        #expect(QuietReason.micBusy.label == "Mic is on")
        #expect(QuietReason.quietApp(bundleID: "x").label == "Meeting app in front")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'QuietPolicy' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/NudgieCore/ActivityState.swift`:
```swift
/// What the OS tells us about the person at the keyboard, as plain values.
public struct ActivityState: Equatable, Sendable {
    /// Seconds since the last keyboard or mouse event.
    public var idleSeconds: Double
    public var isLocked: Bool
    public var isAsleep: Bool

    /// Away for this long counts as a break and resets every timer.
    public static let awayThresholdSeconds: Double = 300

    public init(idleSeconds: Double = 0, isLocked: Bool = false, isAsleep: Bool = false) {
        self.idleSeconds = idleSeconds
        self.isLocked = isLocked
        self.isAsleep = isAsleep
    }

    /// Locked or asleep is away at once; idle counts as away after the threshold.
    public var isAway: Bool {
        isLocked || isAsleep || idleSeconds >= Self.awayThresholdSeconds
    }
}
```

`Sources/NudgieCore/QuietState.swift`:
```swift
/// Meeting signals from the OS, as plain values.
public struct QuietState: Equatable, Sendable {
    public var cameraBusy: Bool
    public var micBusy: Bool
    public var frontmostBundleID: String?

    public init(cameraBusy: Bool = false, micBusy: Bool = false, frontmostBundleID: String? = nil) {
        self.cameraBusy = cameraBusy
        self.micBusy = micBusy
        self.frontmostBundleID = frontmostBundleID
    }
}

/// Why Nudgie is holding its tongue right now.
public enum QuietReason: Equatable, Sendable {
    case cameraBusy
    case micBusy
    case quietApp(bundleID: String)

    public var label: String {
        switch self {
        case .cameraBusy: "Camera is on"
        case .micBusy: "Mic is on"
        case .quietApp: "Meeting app in front"
        }
    }
}
```

`Sources/NudgieCore/QuietPolicy.swift`:
```swift
/// Turns raw meeting signals plus the user's rule toggles into one answer.
public enum QuietPolicy {
    /// Camera and mic are checked first because they are the strongest signal.
    public static func reason(for state: QuietState, settings: NudgieSettings) -> QuietReason? {
        if settings.quietOnCameraOrMic {
            if state.cameraBusy { return .cameraBusy }
            if state.micBusy { return .micBusy }
        }
        if settings.quietOnQuietApps, let id = state.frontmostBundleID,
           matches(bundleID: id, prefixes: settings.quietAppPrefixes) {
            return .quietApp(bundleID: id)
        }
        return nil
    }

    /// Prefix match so "com.google.Chrome.app.<id>" (a Chrome web app) counts as Chrome.
    public static func matches(bundleID: String, prefixes: [String]) -> Bool {
        let id = bundleID.lowercased()
        return prefixes.contains { id.hasPrefix($0.lowercased()) }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -2`
Expected: all pass (17 + 12 = 29).

- [ ] **Step 5: Commit**

```bash
git add Sources/NudgieCore/ActivityState.swift Sources/NudgieCore/QuietState.swift Sources/NudgieCore/QuietPolicy.swift Tests/NudgieCoreTests/QuietPolicyTests.swift
git commit -m "feat(core): add activity/quiet state values and QuietPolicy

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: TimerEngine (active-time accumulators)

**Files:**
- Create: `Sources/NudgieCore/TimerEngine.swift`
- Test: `Tests/NudgieCoreTests/TimerEngineTests.swift`

**Interfaces:**
- Consumes: `NudgieSettings`, `ReminderKind`, `ActivityState`.
- Produces: `public struct TimerEngine: Equatable, Sendable` with
  - `init(settings:)`, `private(set) var settings`, `private(set) var activeSeconds: [ReminderKind: Double]`, `private(set) var pending: [ReminderKind]`, `private(set) var manualPauseUntil: Date?`
  - `enum TickOutcome: Equatable, Sendable { case counting, paused(until: Date), offTheClock, away, resetAfterAway }`
  - `@discardableResult mutating func tick(now: Date, activity: ActivityState, elapsed: Double = 1, calendar: Calendar = .current) -> TickOutcome`
  - `mutating func markDone(_ kinds: [ReminderKind])`, `mutating func snooze(_ kinds: [ReminderKind])`, `mutating func triggerNow(_ kind: ReminderKind)`, `mutating func resetAll()`, `mutating func pause(until: Date)`, `mutating func resume()`, `mutating func updateSettings(_:)`
  - `func isPaused(at: Date) -> Bool`, `func secondsUntilDue(_ kind: ReminderKind) -> Double?` (nil when disabled, 0 when pending)

Behaviour rules (from spec sections 7 and 8):
1. Manual pause and off-the-clock both stop counting **and reset everything**, so resuming never fires a stale reminder.
2. Away (locked, asleep, or idle ≥ 300 s) stops counting. Once the away stretch has lasted 300 s, reset everything exactly once (`.resetAfterAway`). Idle time that already elapsed counts toward the stretch, so "idle 300 s" resets immediately while "locked 10 s ago" resets 290 s later.
3. While active, every enabled reminder that is not already pending gains `elapsed` seconds; reaching its interval appends it to `pending` once.
4. Quiet mode is not the engine's business. Counting continues in meetings; the planner decides when to show.

- [ ] **Step 1: Write the failing tests**

`Tests/NudgieCoreTests/TimerEngineTests.swift`:
```swift
import Foundation
import Testing
@testable import NudgieCore

@Suite struct TimerEngineTests {
    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    /// Monday 2026-09-07 10:00 UTC.
    static let start = utc.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 10, minute: 0))!

    /// Drives the engine one second at a time. `activity` is built from the tick index so idle can grow.
    @discardableResult
    static func run(_ engine: inout TimerEngine, from now: inout Date, seconds: Int,
                    activity: (Int) -> ActivityState = { _ in ActivityState() }) -> [TimerEngine.TickOutcome] {
        var outcomes: [TimerEngine.TickOutcome] = []
        for i in 0..<seconds {
            now = now.addingTimeInterval(1)
            outcomes.append(engine.tick(now: now, activity: activity(i), calendar: utc))
        }
        return outcomes
    }

    @Test func eyesBecomesPendingAfterTwentyActiveMinutes() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 20 * 60 - 1)
        #expect(e.pending.isEmpty)
        #expect(e.secondsUntilDue(.eyes) == 1)
        Self.run(&e, from: &now, seconds: 1)
        #expect(e.pending == [.eyes])
        #expect(e.secondsUntilDue(.eyes) == 0)
    }

    @Test func lockedSecondsDoNotCount() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 10 * 60)
        let locked = Self.run(&e, from: &now, seconds: 3 * 60) { i in ActivityState(idleSeconds: Double(i), isLocked: true) }
        #expect(locked.allSatisfy { $0 == .away })
        Self.run(&e, from: &now, seconds: 10 * 60 - 1)
        #expect(e.pending.isEmpty)
        Self.run(&e, from: &now, seconds: 1)
        #expect(e.pending == [.eyes])
    }

    @Test func idleUnderFiveMinutesStillCounts() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        let out = Self.run(&e, from: &now, seconds: 20 * 60) { _ in ActivityState(idleSeconds: 200) }
        #expect(out.allSatisfy { $0 == .counting })
        #expect(e.pending == [.eyes])
    }

    @Test func idleReachingFiveMinutesResetsOnce() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 15 * 60)
        #expect(e.secondsUntilDue(.eyes) == 300)
        let out = Self.run(&e, from: &now, seconds: 310) { i in ActivityState(idleSeconds: Double(i + 1)) }
        // idle 1...299 is still active, idle 300 resets at once, idle 301...310 is away
        #expect(out[298] == .counting)
        #expect(out[299] == .resetAfterAway)
        #expect(out[300] == .away)
        #expect(out.filter { $0 == .resetAfterAway }.count == 1)
        #expect(e.secondsUntilDue(.eyes) == 1200)
    }

    @Test func lockResetsAfterFiveMinutesLocked() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 15 * 60)
        let out = Self.run(&e, from: &now, seconds: 305) { i in ActivityState(idleSeconds: Double(i), isLocked: true) }
        #expect(out.filter { $0 == .resetAfterAway }.count == 1)
        #expect(out.firstIndex(of: .resetAfterAway) == 300)
        #expect(e.activeSeconds[.eyes] == nil || e.activeSeconds[.eyes] == 0)
    }

    @Test func shortLockDoesNotReset() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 15 * 60)
        Self.run(&e, from: &now, seconds: 120) { i in ActivityState(idleSeconds: Double(i), isLocked: true) }
        Self.run(&e, from: &now, seconds: 5 * 60)
        #expect(e.pending == [.eyes])
    }

    @Test func eachReminderPendsOnceInDueOrder() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 60 * 60)
        #expect(e.pending == [.eyes, .posture, .water, .walk, .stretch])
        Self.run(&e, from: &now, seconds: 60 * 60)
        #expect(e.pending == [.eyes, .posture, .water, .walk, .stretch])
    }

    @Test func markDoneClearsPendingAndRestartsTimer() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 20 * 60)
        e.markDone([.eyes])
        #expect(e.pending.isEmpty)
        #expect(e.secondsUntilDue(.eyes) == 1200)
    }

    @Test func snoozeComesBackAfterSnoozeMinutes() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 20 * 60)
        e.snooze([.eyes])
        #expect(e.pending.isEmpty)
        #expect(e.secondsUntilDue(.eyes) == 300)
        Self.run(&e, from: &now, seconds: 300)
        #expect(e.pending == [.eyes])
    }

    @Test func offTheClockResetsAndDoesNotCount() {
        var s = NudgieSettings.defaults
        s.workHours = WorkHours(isEnabled: true, startMinute: 9 * 60, endMinute: 18 * 60, weekdays: [2, 3, 4, 5, 6])
        var e = TimerEngine(settings: s)
        var now = Self.start                                   // Monday 10:00, inside
        Self.run(&e, from: &now, seconds: 10 * 60)
        #expect(e.secondsUntilDue(.eyes) == 600)
        now = Self.utc.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 18, minute: 30))!
        let out = Self.run(&e, from: &now, seconds: 5)
        #expect(out.allSatisfy { $0 == .offTheClock })
        #expect(e.secondsUntilDue(.eyes) == 1200)
    }

    @Test func manualPauseResetsStopsAndExpires() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 10 * 60)
        e.pause(until: now.addingTimeInterval(61))   // ticks land on now+1 ... now+60, all before expiry
        #expect(e.isPaused(at: now))
        #expect(e.secondsUntilDue(.eyes) == 1200)
        let paused = Self.run(&e, from: &now, seconds: 60)
        #expect(paused.allSatisfy { if case .paused = $0 { true } else { false } })
        let after = Self.run(&e, from: &now, seconds: 1)
        #expect(after == [.counting])
        #expect(!e.isPaused(at: now))
    }

    @Test func resumeClearsPause() {
        var e = TimerEngine(settings: .defaults)
        e.pause(until: Self.start.addingTimeInterval(3600))
        e.resume()
        #expect(!e.isPaused(at: Self.start))
    }

    @Test func triggerNowMakesPendingImmediately() {
        var e = TimerEngine(settings: .defaults)
        e.triggerNow(.water)
        #expect(e.pending == [.water])
        #expect(e.secondsUntilDue(.water) == 0)
        e.triggerNow(.water)
        #expect(e.pending == [.water])
    }

    @Test func disabledKindNeverPends() {
        var s = NudgieSettings.defaults
        s.setReminder(ReminderSetting(isEnabled: false, intervalMinutes: 20, breakSeconds: 20), for: .eyes)
        var e = TimerEngine(settings: s)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 60 * 60)
        #expect(!e.pending.contains(.eyes))
        #expect(e.secondsUntilDue(.eyes) == nil)
        e.triggerNow(.eyes)
        #expect(!e.pending.contains(.eyes))
    }

    @Test func updateSettingsDropsDisabledPending() {
        var e = TimerEngine(settings: .defaults)
        var now = Self.start
        Self.run(&e, from: &now, seconds: 20 * 60)
        var s = NudgieSettings.defaults
        s.setReminder(ReminderSetting(isEnabled: false, intervalMinutes: 20, breakSeconds: 20), for: .eyes)
        e.updateSettings(s)
        #expect(e.pending.isEmpty)
        #expect(e.settings == s)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'TimerEngine' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/NudgieCore/TimerEngine.swift`:
```swift
import Foundation

/// Counts active seconds per reminder and says when each is due.
/// Pure value type: the app feeds it one tick per second with what the OS reported.
public struct TimerEngine: Equatable, Sendable {
    public enum TickOutcome: Equatable, Sendable {
        case counting
        case paused(until: Date)
        case offTheClock
        case away
        case resetAfterAway
    }

    public private(set) var settings: NudgieSettings
    public private(set) var activeSeconds: [ReminderKind: Double] = [:]
    /// Due reminders waiting for a card, in the order they became due. Never contains duplicates.
    public private(set) var pending: [ReminderKind] = []
    public private(set) var manualPauseUntil: Date?
    /// Start of the current away stretch, nil while active.
    private var awayStartedAt: Date?
    private var didResetForThisAway = false

    public init(settings: NudgieSettings) {
        self.settings = settings
    }

    // MARK: Heartbeat

    @discardableResult
    public mutating func tick(now: Date, activity: ActivityState, elapsed: Double = 1,
                              calendar: Calendar = .current) -> TickOutcome {
        if let until = manualPauseUntil {
            if now < until { return .paused(until: until) }
            manualPauseUntil = nil
        }
        guard settings.workHours.allows(now, calendar: calendar) else {
            resetAll()
            return .offTheClock
        }
        if activity.isAway {
            if awayStartedAt == nil {
                // Idle time already elapsed counts toward the away stretch.
                let alreadyAway = min(activity.idleSeconds, ActivityState.awayThresholdSeconds)
                awayStartedAt = now.addingTimeInterval(-alreadyAway)
                didResetForThisAway = false
            }
            if !didResetForThisAway,
               now.timeIntervalSince(awayStartedAt!) >= ActivityState.awayThresholdSeconds {
                resetAll()
                didResetForThisAway = true
                return .resetAfterAway
            }
            return .away
        }
        awayStartedAt = nil
        didResetForThisAway = false
        for kind in settings.enabledKinds where !pending.contains(kind) {
            let total = (activeSeconds[kind] ?? 0) + elapsed
            activeSeconds[kind] = total
            if total >= settings.reminder(kind).intervalSeconds {
                pending.append(kind)
            }
        }
        return .counting
    }

    // MARK: User actions

    public mutating func markDone(_ kinds: [ReminderKind]) {
        for kind in kinds { activeSeconds[kind] = 0 }
        pending.removeAll { kinds.contains($0) }
    }

    public mutating func snooze(_ kinds: [ReminderKind]) {
        let snoozeSeconds = Double(settings.snoozeMinutes) * 60
        for kind in kinds {
            activeSeconds[kind] = max(0, settings.reminder(kind).intervalSeconds - snoozeSeconds)
        }
        pending.removeAll { kinds.contains($0) }
    }

    /// "Take a break now" from the menu.
    public mutating func triggerNow(_ kind: ReminderKind) {
        guard settings.reminder(kind).isEnabled, !pending.contains(kind) else { return }
        activeSeconds[kind] = settings.reminder(kind).intervalSeconds
        pending.append(kind)
    }

    public mutating func resetAll() {
        activeSeconds = [:]
        pending = []
    }

    public mutating func pause(until: Date) {
        manualPauseUntil = until
        resetAll()
    }

    public mutating func resume() {
        manualPauseUntil = nil
    }

    public mutating func updateSettings(_ new: NudgieSettings) {
        settings = new
        for kind in ReminderKind.allCases where !new.reminder(kind).isEnabled {
            activeSeconds[kind] = nil
            pending.removeAll { $0 == kind }
        }
    }

    // MARK: Queries

    public func isPaused(at now: Date) -> Bool {
        guard let until = manualPauseUntil else { return false }
        return now < until
    }

    /// nil when the reminder is switched off, 0 when it is already due.
    public func secondsUntilDue(_ kind: ReminderKind) -> Double? {
        let setting = settings.reminder(kind)
        guard setting.isEnabled else { return nil }
        if pending.contains(kind) { return 0 }
        return max(0, setting.intervalSeconds - (activeSeconds[kind] ?? 0))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -2`
Expected: all pass (29 + 15 = 44). If `idleReachingFiveMinutesResetsOnce` is off by one, check that the reset compares with `>=` and that `alreadyAway` uses the idle seconds from the first away tick.

- [ ] **Step 5: Commit**

```bash
git add Sources/NudgieCore/TimerEngine.swift Tests/NudgieCoreTests/TimerEngineTests.swift
git commit -m "feat(core): add TimerEngine with active-time counting, away reset, snooze and pause

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: CardPlanner (when to show, grouping, countdown)

**Files:**
- Create: `Sources/NudgieCore/CardPlanner.swift`
- Test: `Tests/NudgieCoreTests/CardPlannerTests.swift`

**Interfaces:**
- Consumes: `NudgieSettings`, `ReminderKind`.
- Produces:
  - `public struct CardPlan: Equatable, Sendable { var kinds: [ReminderKind]; var countdownSeconds: Int; var isTimed: Bool }`
  - `public struct CardPlanner: Equatable, Sendable` with `static let breathingGapSeconds: Double = 30`, `static let settleAfterQuietSeconds: Double = 30`, `static let untimedDisplaySeconds = 30`, `private(set) var isShowing`, `var isQuiet: Bool`, `mutating func observe(quiet: Bool, now: Date)`, `mutating func plan(pending: [ReminderKind], settings: NudgieSettings, now: Date) -> CardPlan?`, `mutating func forcePlan(kinds: [ReminderKind], settings: NudgieSettings) -> CardPlan?` (ignores gaps and quiet, used by "Take a break now"), `mutating func cardDismissed(now: Date)`.

- [ ] **Step 1: Write the failing tests**

`Tests/NudgieCoreTests/CardPlannerTests.swift`:
```swift
import Foundation
import Testing
@testable import NudgieCore

@Suite struct CardPlannerTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    let settings = NudgieSettings.defaults

    @Test func showsWhenPendingAndClear() {
        var p = CardPlanner()
        let plan = p.plan(pending: [.eyes], settings: settings, now: t0)
        #expect(plan == CardPlan(kinds: [.eyes], countdownSeconds: 20, isTimed: true))
        #expect(p.isShowing)
    }

    @Test func nothingWhenNoPending() {
        var p = CardPlanner()
        #expect(p.plan(pending: [], settings: settings, now: t0) == nil)
        #expect(!p.isShowing)
    }

    @Test func nothingWhileQuiet() {
        var p = CardPlanner()
        p.observe(quiet: true, now: t0)
        #expect(p.isQuiet)
        #expect(p.plan(pending: [.eyes], settings: settings, now: t0) == nil)
    }

    @Test func nothingWhileAlreadyShowing() {
        var p = CardPlanner()
        _ = p.plan(pending: [.eyes], settings: settings, now: t0)
        #expect(p.plan(pending: [.eyes, .water], settings: settings, now: t0.addingTimeInterval(5)) == nil)
    }

    @Test func breathingGapAfterDismissal() {
        var p = CardPlanner()
        _ = p.plan(pending: [.eyes], settings: settings, now: t0)
        p.cardDismissed(now: t0.addingTimeInterval(20))
        #expect(!p.isShowing)
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(49)) == nil)
        #expect(p.plan(pending: [.water], settings: settings, now: t0.addingTimeInterval(50)) != nil)
    }

    @Test func settleGapAfterQuietEnds() {
        var p = CardPlanner()
        p.observe(quiet: true, now: t0)
        p.observe(quiet: false, now: t0.addingTimeInterval(100))
        #expect(!p.isQuiet)
        #expect(p.plan(pending: [.eyes], settings: settings, now: t0.addingTimeInterval(129)) == nil)
        #expect(p.plan(pending: [.eyes], settings: settings, now: t0.addingTimeInterval(130)) != nil)
    }

    @Test func countdownIsLongestBreakInGroup() {
        var p = CardPlanner()
        let plan = p.plan(pending: [.eyes, .walk, .water], settings: settings, now: t0)
        #expect(plan?.kinds == [.eyes, .walk, .water])
        #expect(plan?.countdownSeconds == 180)
        #expect(plan?.isTimed == true)
    }

    @Test func untimedGroupShowsForThirtySeconds() {
        var p = CardPlanner()
        let plan = p.plan(pending: [.water, .posture], settings: settings, now: t0)
        #expect(plan?.countdownSeconds == CardPlanner.untimedDisplaySeconds)
        #expect(plan?.isTimed == false)
    }

    @Test func forcePlanIgnoresGapsAndQuietButNotAnExistingCard() {
        var p = CardPlanner()
        p.observe(quiet: true, now: t0)
        let plan = p.forcePlan(kinds: [.walk], settings: settings)
        #expect(plan == CardPlan(kinds: [.walk], countdownSeconds: 180, isTimed: true))
        #expect(p.isShowing)
        #expect(p.forcePlan(kinds: [.eyes], settings: settings) == nil)
    }

    @Test func customBreakLengthIsUsed() {
        var s = settings
        s.setReminder(ReminderSetting(intervalMinutes: 20, breakSeconds: 45), for: .eyes)
        var p = CardPlanner()
        #expect(p.plan(pending: [.eyes], settings: s, now: t0)?.countdownSeconds == 45)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'CardPlanner' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/NudgieCore/CardPlanner.swift`:
```swift
import Foundation

/// One card on screen: which reminders it lists and how long its ring runs.
public struct CardPlan: Equatable, Sendable {
    public var kinds: [ReminderKind]
    public var countdownSeconds: Int
    /// false when every listed reminder is untimed (water, posture): the card just shows for a while.
    public var isTimed: Bool

    public init(kinds: [ReminderKind], countdownSeconds: Int, isTimed: Bool) {
        self.kinds = kinds
        self.countdownSeconds = countdownSeconds
        self.isTimed = isTimed
    }
}

/// Decides *when* pending reminders may become a card. Knows nothing about windows.
public struct CardPlanner: Equatable, Sendable {
    public static let breathingGapSeconds: Double = 30
    public static let settleAfterQuietSeconds: Double = 30
    public static let untimedDisplaySeconds = 30

    public private(set) var isShowing = false
    public private(set) var lastDismissedAt: Date?
    public private(set) var quietEndedAt: Date?
    private var wasQuiet = false

    public init() {}

    public var isQuiet: Bool { wasQuiet }

    /// Call once per tick, before `plan`, so the settle gap starts when a meeting ends.
    public mutating func observe(quiet: Bool, now: Date) {
        if wasQuiet && !quiet { quietEndedAt = now }
        wasQuiet = quiet
    }

    /// Returns a card to show now, or nil. A returned plan marks the planner as showing.
    public mutating func plan(pending: [ReminderKind], settings: NudgieSettings, now: Date) -> CardPlan? {
        guard !isShowing, !wasQuiet, !pending.isEmpty else { return nil }
        if let last = lastDismissedAt, now.timeIntervalSince(last) < Self.breathingGapSeconds { return nil }
        if let ended = quietEndedAt, now.timeIntervalSince(ended) < Self.settleAfterQuietSeconds { return nil }
        let longest = pending.map { settings.reminder($0).breakSeconds }.max() ?? 0
        isShowing = true
        return CardPlan(kinds: pending,
                        countdownSeconds: longest > 0 ? longest : Self.untimedDisplaySeconds,
                        isTimed: longest > 0)
    }

    /// "Take a break now": show at once, even mid-meeting, unless a card is already up.
    public mutating func forcePlan(kinds: [ReminderKind], settings: NudgieSettings) -> CardPlan? {
        guard !isShowing, !kinds.isEmpty else { return nil }
        let longest = kinds.map { settings.reminder($0).breakSeconds }.max() ?? 0
        isShowing = true
        return CardPlan(kinds: kinds,
                        countdownSeconds: longest > 0 ? longest : Self.untimedDisplaySeconds,
                        isTimed: longest > 0)
    }

    /// Any way the card leaves the screen: Did it, snooze, close, countdown finished, or hidden by a meeting.
    public mutating func cardDismissed(now: Date) {
        isShowing = false
        lastDismissedAt = now
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -2`
Expected: all pass (44 + 10 = 54).

- [ ] **Step 5: Commit**

```bash
git add Sources/NudgieCore/CardPlanner.swift Tests/NudgieCoreTests/CardPlannerTests.swift
git commit -m "feat(core): add CardPlanner with grouping, breathing gap and post-meeting settle

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: CopyPicker and DailyStats

**Files:**
- Create: `Sources/NudgieCore/CopyPicker.swift`, `Sources/NudgieCore/DailyStats.swift`
- Test: `Tests/NudgieCoreTests/CopyPickerTests.swift`, `Tests/NudgieCoreTests/DailyStatsTests.swift`

**Interfaces:**
- Produces:
  - `public struct CopyPicker: Equatable, Sendable { static let lines: [ReminderKind: [String]]; init(); mutating func line(for: ReminderKind, using: inout some RandomNumberGenerator) -> String; mutating func line(for: ReminderKind) -> String }`
  - `public struct DailyStats: Codable, Equatable, Sendable { struct DayCount: Codable, Equatable, Sendable { var taken: Int; var snoozed: Int }; private(set) var days: [String: DayCount]; init(); static func key(for: Date, calendar: Calendar) -> String; mutating func record(taken: Int = 0, snoozed: Int = 0, on: Date, calendar: Calendar); func count(on: Date, calendar: Calendar) -> DayCount }`

- [ ] **Step 1: Write the failing tests**

`Tests/NudgieCoreTests/CopyPickerTests.swift`:
```swift
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
```

`Tests/NudgieCoreTests/DailyStatsTests.swift`:
```swift
import Foundation
import Testing
@testable import NudgieCore

@Suite struct DailyStatsTests {
    static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    static func day(_ d: Int, hour: Int = 12) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 9, day: d, hour: hour))!
    }

    @Test func keyIsISODate() {
        #expect(DailyStats.key(for: Self.day(7), calendar: Self.utc) == "2026-09-07")
    }

    @Test func recordAccumulatesWithinADay() {
        var s = DailyStats()
        s.record(taken: 1, on: Self.day(7, hour: 9), calendar: Self.utc)
        s.record(taken: 2, snoozed: 1, on: Self.day(7, hour: 17), calendar: Self.utc)
        #expect(s.count(on: Self.day(7), calendar: Self.utc) == DailyStats.DayCount(taken: 3, snoozed: 1))
    }

    @Test func unknownDayIsZero() {
        #expect(DailyStats().count(on: Self.day(7), calendar: Self.utc) == DailyStats.DayCount(taken: 0, snoozed: 0))
    }

    @Test func keepsOnlyTodayAndYesterday() {
        var s = DailyStats()
        s.record(taken: 1, on: Self.day(5), calendar: Self.utc)
        s.record(taken: 1, on: Self.day(6), calendar: Self.utc)
        s.record(taken: 1, on: Self.day(7), calendar: Self.utc)
        #expect(s.days.keys.sorted() == ["2026-09-06", "2026-09-07"])
    }

    @Test func roundTripsThroughJSON() throws {
        var s = DailyStats()
        s.record(taken: 4, snoozed: 2, on: Self.day(7), calendar: Self.utc)
        let data = try JSONEncoder().encode(s)
        #expect(try JSONDecoder().decode(DailyStats.self, from: data) == s)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test 2>&1 | grep -E "error:" | head -3`
Expected: `cannot find 'CopyPicker' in scope` / `cannot find 'DailyStats' in scope`.

- [ ] **Step 3: Write the implementations**

`Sources/NudgieCore/CopyPicker.swift`:
```swift
/// The cheeky one-liners. Picks at random, never the same line twice in a row.
public struct CopyPicker: Equatable, Sendable {
    public static let lines: [ReminderKind: [String]] = [
        .eyes: [
            "Your eyeballs called. They want a vacation.",
            "Stare at something 20 feet away. The wall counts.",
            "Blink. Blink again. Now look far away.",
            "Give the pixels a break. Find a window.",
        ],
        .water: [
            "Hydrate or dydrate.",
            "Plants get watered. So should you.",
            "Sip happens.",
            "Your brain is 75% water. Top it up.",
        ],
        .walk: [
            "Legs. Remember those? Take them for a spin.",
            "Go touch grass, or at least the kitchen.",
            "Your chair needs some alone time.",
            "A short lap now beats a stiff back later.",
        ],
        .posture: [
            "You're doing the shrimp again.",
            "Shoulders down. Chin up. You've got this.",
            "Sit like someone's taking your photo.",
            "Unfold yourself. Slowly. Like a lawn chair.",
        ],
        .stretch: [
            "Reach for the ceiling. It's not going anywhere.",
            "Roll those shoulders like you mean it.",
            "Wrists, neck, shoulders. Go.",
            "Stretch now, thank yourself at 5 pm.",
        ],
    ]

    private var lastIndex: [ReminderKind: Int] = [:]

    public init() {}

    public mutating func line(for kind: ReminderKind, using generator: inout some RandomNumberGenerator) -> String {
        let options = Self.lines[kind] ?? [kind.instruction]
        guard options.count > 1 else { return options[0] }
        var index = Int.random(in: 0..<options.count, using: &generator)
        if index == lastIndex[kind] {
            index = (index + 1) % options.count
        }
        lastIndex[kind] = index
        return options[index]
    }

    public mutating func line(for kind: ReminderKind) -> String {
        var generator = SystemRandomNumberGenerator()
        return line(for: kind, using: &generator)
    }
}
```

`Sources/NudgieCore/DailyStats.swift`:
```swift
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
        prune(keeping: date, calendar: calendar)
    }

    public func count(on date: Date, calendar: Calendar) -> DayCount {
        days[Self.key(for: date, calendar: calendar)] ?? DayCount()
    }

    private mutating func prune(keeping date: Date, calendar: Calendar) {
        let today = Self.key(for: date, calendar: calendar)
        let yesterday = Self.key(for: calendar.date(byAdding: .day, value: -1, to: date) ?? date, calendar: calendar)
        days = days.filter { $0.key == today || $0.key == yesterday }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test 2>&1 | tail -2`
Expected: all pass (54 + 9 = 63).

- [ ] **Step 5: Commit**

```bash
git add Sources/NudgieCore/CopyPicker.swift Sources/NudgieCore/DailyStats.swift Tests/NudgieCoreTests/CopyPickerTests.swift Tests/NudgieCoreTests/DailyStatsTests.swift
git commit -m "feat(core): add CopyPicker lines and DailyStats

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: App skeleton, OS probes, storage and `--probe` mode

**Files:**
- Replace: `Sources/Nudgie/main.swift`
- Create: `Sources/Nudgie/NudgieApp.swift`, `Sources/Nudgie/AppDelegate.swift`, `Sources/Nudgie/Probes/ActivityProbe.swift`, `Sources/Nudgie/Probes/QuietProbe.swift`, `Sources/Nudgie/Probes/ProbeRunner.swift`, `Sources/Nudgie/Persistence/Store.swift`

**Interfaces:**
- Consumes: `ActivityState`, `QuietState`, `NudgieSettings`, `DailyStats` from Core.
- Produces (all main-actor, the target's default isolation):
  - `final class ActivityProbe { init(); func sample() -> ActivityState }`
  - `final class QuietProbe { init(); func sample(now: Date) -> QuietState; static func appName(forBundleID: String) -> String? }`
  - `struct Store { init(defaults: UserDefaults = .standard); func loadSettings() -> NudgieSettings; func save(_: NudgieSettings); func loadStats() -> DailyStats; func save(_: DailyStats) }`
  - `final class AppDelegate: NSObject, NSApplicationDelegate` (Task 9 adds the coordinator to it)
  - `struct NudgieApp: App`

There are no unit tests for this task: it is all OS glue. Verification is running `--probe` against the real OS (your contract-discipline rule).

- [ ] **Step 1: Write the probes**

`Sources/Nudgie/Probes/ActivityProbe.swift`:
```swift
import AppKit
import CoreGraphics
import NudgieCore

/// Idle time from CoreGraphics; lock and sleep from system notifications.
final class ActivityProbe {
    private(set) var isLocked = false
    private(set) var isAsleep = false
    private var tokens: [NSObjectProtocol] = []

    init() {
        let dnc = DistributedNotificationCenter.default()
        tokens.append(dnc.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.isLocked = true }
        })
        tokens.append(dnc.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { self.isLocked = false }
        })
        let wnc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            tokens.append(wnc.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { self.isAsleep = true }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            tokens.append(wnc.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { self.isAsleep = false }
            })
        }
    }

    /// Seconds since the last keyboard or mouse event, any type.
    var idleSeconds: Double {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    func sample() -> ActivityState {
        ActivityState(idleSeconds: idleSeconds, isLocked: isLocked, isAsleep: isAsleep)
    }
}
```

`Sources/Nudgie/Probes/QuietProbe.swift`:
```swift
import AppKit
import CoreAudio
import CoreMediaIO
import NudgieCore
import os

/// Camera and mic "is running somewhere" flags plus the frontmost app.
/// We never open a device, so no permission prompt appears.
final class QuietProbe {
    static let deviceCheckInterval: TimeInterval = 2
    private static let log = Logger(subsystem: "com.gouravkakkar.nudgie", category: "probe")
    private static var loggedCameraFailure = false
    private static var loggedMicFailure = false

    private var cachedCameraBusy = false
    private var cachedMicBusy = false
    private var lastDeviceCheck = Date.distantPast

    init() {}

    func sample(now: Date = Date()) -> QuietState {
        if now.timeIntervalSince(lastDeviceCheck) >= Self.deviceCheckInterval {
            cachedCameraBusy = Self.isAnyCameraRunning()
            cachedMicBusy = Self.isAnyMicRunning()
            lastDeviceCheck = now
        }
        return QuietState(cameraBusy: cachedCameraBusy,
                          micBusy: cachedMicBusy,
                          frontmostBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    static func appName(forBundleID id: String) -> String? {
        NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName
    }

    // MARK: Camera (CoreMediaIO)

    static func isAnyCameraRunning() -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == 0 else {
            logOnce(&loggedCameraFailure, "camera device list size query failed")
            return false
        }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &ids) == 0 else {
            logOnce(&loggedCameraFailure, "camera device list query failed")
            return false
        }
        for id in ids {
            var runningAddress = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
            var running: UInt32 = 0
            let wanted = UInt32(MemoryLayout<UInt32>.size)
            var got: UInt32 = 0
            if CMIOObjectGetPropertyData(id, &runningAddress, 0, nil, wanted, &got, &running) == 0, running != 0 {
                return true
            }
        }
        return false
    }

    // MARK: Microphone (CoreAudio)

    static func isAnyMicRunning() -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        let system = AudioObjectID(kAudioObjectSystemObject)
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == 0 else {
            logOnce(&loggedMicFailure, "audio device list size query failed")
            return false
        }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == 0 else {
            logOnce(&loggedMicFailure, "audio device list query failed")
            return false
        }
        for id in ids {
            // Only devices with input streams can be microphones.
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain)
            var inputSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &inputAddress, 0, nil, &inputSize) == 0, inputSize > 0 else { continue }
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(id, &runningAddress, 0, nil, &runningSize, &running) == 0, running != 0 {
                return true
            }
        }
        return false
    }

    private static func logOnce(_ flag: inout Bool, _ message: String) {
        guard !flag else { return }
        flag = true
        log.error("\(message, privacy: .public)")
    }
}
```

`Sources/Nudgie/Probes/ProbeRunner.swift`:
```swift
import Foundation
import NudgieCore

/// `Nudgie --probe`: print live detector values once a second. Ctrl-C to stop.
enum ProbeRunner {
    static func run() {
        let activity = ActivityProbe()
        let quiet = QuietProbe()
        print("Nudgie probe. Move the mouse, lock the screen, open Photo Booth, switch apps. Ctrl-C to stop.")
        let timer = Timer(timeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                let a = activity.sample()
                let q = quiet.sample()
                let front = q.frontmostBundleID ?? "nil"
                print(String(format: "idle %6.1fs  locked %@  asleep %@  camera %@  mic %@  front %@",
                             a.idleSeconds, "\(a.isLocked)", "\(a.isAsleep)", "\(q.cameraBusy)", "\(q.micBusy)", front))
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.run()
    }
}
```

- [ ] **Step 2: Write the store**

`Sources/Nudgie/Persistence/Store.swift`:
```swift
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
```

- [ ] **Step 3: Write the app entry, delegate and a minimal menu**

`Sources/Nudgie/AppDelegate.swift`:
```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // No Dock icon, even when run straight from .build without a bundle.
        NSApp.setActivationPolicy(.accessory)
    }
}
```

`Sources/Nudgie/NudgieApp.swift`:
```swift
import SwiftUI

struct NudgieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Nudgie", systemImage: "face.smiling") {
            Button("Quit Nudgie") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
```

`Sources/Nudgie/main.swift`:
```swift
import AppKit
import NudgieCore

if CommandLine.arguments.contains("--probe") {
    ProbeRunner.run()
} else {
    NudgieApp.main()
}
```

- [ ] **Step 4: Build and verify against the real OS**

Run: `swift build 2>&1 | tail -1`
Expected: `Build complete!`

Run (prints 4 lines then stops):
```bash
(.build/debug/Nudgie --probe & PID=$!; sleep 4; kill $PID) 2>/dev/null
```
Expected: lines like `idle    0.4s  locked false  asleep false  camera false  mic false  front dev.warp.Warp-Stable` with a growing idle value.

Then, with the probe running in one terminal, open **Photo Booth** and confirm `camera true`; quit it and confirm `camera false`. Start a **FaceTime** call preview (or a browser tab on https://webcamtests.com) and confirm `mic true`. Click into Safari and confirm `front com.apple.Safari`. Lock the screen (Ctrl-Cmd-Q), unlock, and confirm the log shows `locked true` lines while locked. Record the results in the commit message body.

Run the app itself: `swift run Nudgie` shows a face icon in the menu bar with a Quit item and no Dock icon. Quit it.

- [ ] **Step 5: Commit**

```bash
git add Sources/Nudgie
git commit -m "feat(app): add activity/quiet probes, store, --probe mode and app skeleton

Verified on this Mac: camera flag flips with Photo Booth, mic flag with a call,
front bundle id follows app switches, locked flag follows screen lock.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 9: Coordinator heartbeat and menu bar menu

**Files:**
- Create: `Sources/Nudgie/Coordinator.swift`, `Sources/Nudgie/UI/MenuBarView.swift`
- Modify: `Sources/Nudgie/AppDelegate.swift`, `Sources/Nudgie/NudgieApp.swift`

**Interfaces:**
- Consumes: `ActivityProbe`, `QuietProbe`, `Store` (Task 8); `TimerEngine`, `CardPlanner`, `CopyPicker`, `DailyStats`, `QuietPolicy` (Core).
- Produces:
  - `enum EngineStatus: Equatable { case counting, quiet(QuietReason), paused(until: Date), offTheClock, away; var label: String }`
  - `struct CardPresentation: Equatable { let plan: CardPlan; let headline: String; let startedAt: Date; var secondsLeft: Int; var accentKind: ReminderKind }`
  - `enum IconState: Equatable { case normal, blink, shh, zzz }`
  - `@Observable final class Coordinator` with `settings`, `card: CardPresentation?`, `status`, `iconState`, `now`, `nextUp: [NextUp]`, `today: DailyStats.DayCount`, `onShowCard: (() -> Void)?`, `onHideCard: (() -> Void)?`, and methods `start(demo:)`, `tick()`, `didIt()`, `snooze()`, `close()`, `takeBreakNow()`, `pause(hours:)`, `pauseUntilTomorrow()`, `resume()`, `updateSettings(_:)`, `resetSettingsToDefaults()`.
  - `AppDelegate.coordinator` (the single instance), `AppDelegate.demoKind() -> ReminderKind?`.

- [ ] **Step 1: Write the coordinator**

`Sources/Nudgie/Coordinator.swift`:
```swift
import AppKit
import Foundation
import Observation
import NudgieCore

/// One line for the menu bar.
enum EngineStatus: Equatable {
    case counting
    case quiet(QuietReason)
    case paused(until: Date)
    case offTheClock
    case away

    var label: String {
        switch self {
        case .counting: "Counting"
        case .quiet(let reason): "Quiet: \(reason.label)"
        case .paused(let until): "Paused until \(until.formatted(date: .omitted, time: .shortened))"
        case .offTheClock: "Off the clock"
        case .away: "Away"
        }
    }
}

/// The card currently on screen.
struct CardPresentation: Equatable {
    let plan: CardPlan
    let headline: String
    let startedAt: Date
    var secondsLeft: Int

    /// The first reminder sets the card's colour and mascot pose.
    var accentKind: ReminderKind { plan.kinds[0] }
}

enum IconState: Equatable { case normal, blink, shh, zzz }

/// The 1-second heartbeat. Reads probes, drives the engine and planner, owns the card state.
@Observable
final class Coordinator {
    struct NextUp: Equatable {
        let kind: ReminderKind
        let seconds: Double
    }

    private(set) var settings: NudgieSettings
    private(set) var engine: TimerEngine
    private(set) var planner = CardPlanner()
    private(set) var stats: DailyStats
    private(set) var status: EngineStatus = .counting
    private(set) var card: CardPresentation?
    private(set) var iconState: IconState = .normal
    private(set) var now = Date()

    /// The window layer hooks these (Task 10). Nil until then.
    var onShowCard: (() -> Void)?
    var onHideCard: (() -> Void)?

    private var copy = CopyPicker()
    private let store: Store
    private let activityProbe = ActivityProbe()
    private let quietProbe = QuietProbe()
    private var timer: Timer?
    private var tickCount = 0
    private let calendar = Calendar.current
    private let verbose = CommandLine.arguments.contains("--verbose")

    init(store: Store = Store()) {
        self.store = store
        settings = store.loadSettings()
        engine = TimerEngine(settings: settings)
        stats = store.loadStats()
    }

    func start(demo: ReminderKind? = nil) {
        if let demo { engine.triggerNow(demo) }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        tick()
    }

    // MARK: Heartbeat

    func tick() {
        now = Date()
        tickCount += 1
        let activity = activityProbe.sample()
        let quietReason = QuietPolicy.reason(for: quietProbe.sample(now: now), settings: settings)
        let outcome = engine.tick(now: now, activity: activity, calendar: calendar)
        planner.observe(quiet: quietReason != nil, now: now)
        status = Self.status(outcome: outcome, quiet: quietReason)
        iconState = Self.icon(for: status, tick: tickCount)

        let engineStopped: Bool = switch outcome {
        case .counting, .away: false
        case .paused, .offTheClock, .resetAfterAway: true
        }

        if let current = card {
            if quietReason != nil || engineStopped {
                hideCard()
                return
            }
            let elapsed = Int(now.timeIntervalSince(current.startedAt).rounded(.down))
            let left = max(0, current.plan.countdownSeconds - elapsed)
            card?.secondsLeft = left
            if left == 0 { didIt() }   // finishing the countdown counts as taking the break
        } else if let plan = planner.plan(pending: engine.pending, settings: settings, now: now) {
            show(plan)
        }
    }

    private func show(_ plan: CardPlan) {
        let headline = copy.line(for: plan.kinds[0])
        card = CardPresentation(plan: plan, headline: headline, startedAt: now, secondsLeft: plan.countdownSeconds)
        log("show \(plan.kinds.map(\.rawValue)) for \(plan.countdownSeconds)s")
        onShowCard?()
    }

    private func hideCard() {
        guard card != nil else { return }
        card = nil
        planner.cardDismissed(now: now)
        log("hide")
        onHideCard?()
    }

    // MARK: Card actions

    func didIt() {
        guard let current = card else { return }
        engine.markDone(current.plan.kinds)
        stats.record(taken: current.plan.kinds.count, on: now, calendar: calendar)
        store.save(stats)
        hideCard()
    }

    func snooze() {
        guard let current = card else { return }
        engine.snooze(current.plan.kinds)
        stats.record(snoozed: current.plan.kinds.count, on: now, calendar: calendar)
        store.save(stats)
        hideCard()
    }

    /// The tiny ✕: restart those timers, count nothing.
    func close() {
        guard let current = card else { return }
        engine.markDone(current.plan.kinds)
        hideCard()
    }

    // MARK: Menu actions

    func takeBreakNow() {
        guard card == nil, let soonest = nextUp.min(by: { $0.seconds < $1.seconds }) else { return }
        engine.triggerNow(soonest.kind)
        if let plan = planner.forcePlan(kinds: [soonest.kind], settings: settings) {
            show(plan)
        }
    }

    func pause(hours: Double) {
        hideCard()
        engine.pause(until: now.addingTimeInterval(hours * 3600))
        tick()
    }

    func pauseUntilTomorrow() {
        hideCard()
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        engine.pause(until: tomorrow)
        tick()
    }

    func resume() {
        engine.resume()
        tick()
    }

    func updateSettings(_ new: NudgieSettings) {
        settings = new
        engine.updateSettings(new)
        store.save(new)
    }

    func resetSettingsToDefaults() {
        updateSettings(.defaults)
    }

    // MARK: Queries

    var nextUp: [NextUp] {
        settings.enabledKinds.compactMap { kind in
            engine.secondsUntilDue(kind).map { NextUp(kind: kind, seconds: $0) }
        }
    }

    var today: DailyStats.DayCount {
        stats.count(on: now, calendar: calendar)
    }

    // MARK: Helpers

    static func status(outcome: TimerEngine.TickOutcome, quiet: QuietReason?) -> EngineStatus {
        switch outcome {
        case .paused(let until): .paused(until: until)
        case .offTheClock: .offTheClock
        case .away, .resetAfterAway: .away
        case .counting: quiet.map { .quiet($0) } ?? .counting
        }
    }

    static func icon(for status: EngineStatus, tick: Int) -> IconState {
        switch status {
        case .quiet: .shh
        case .paused, .offTheClock: .zzz
        case .counting, .away: tick % 30 == 0 ? .blink : .normal
        }
    }

    private func log(_ message: String) {
        if verbose { print("[nudgie] \(message)") }
    }
}
```

- [ ] **Step 2: Write the menu**

`Sources/Nudgie/UI/MenuBarView.swift`:
```swift
import SwiftUI
import NudgieCore

struct MenuBarView: View {
    let coordinator: Coordinator

    var body: some View {
        Text(coordinator.status.label)
        Divider()
        ForEach(coordinator.nextUp, id: \.kind) { item in
            Text("\(item.kind.emoji) \(item.kind.title) \(Self.dueText(item.seconds))")
        }
        Text("Today: \(coordinator.today.taken) breaks taken, \(coordinator.today.snoozed) snoozed")
        Divider()
        Button("Take a break now") { coordinator.takeBreakNow() }
            .disabled(coordinator.card != nil || coordinator.nextUp.isEmpty)
        Menu("Pause") {
            Button("For 1 hour") { coordinator.pause(hours: 1) }
            Button("Until tomorrow") { coordinator.pauseUntilTomorrow() }
            Button("Resume") { coordinator.resume() }
        }
        Divider()
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Button("Quit Nudgie") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    static func dueText(_ seconds: Double) -> String {
        if seconds <= 0 { return "now" }
        let minutes = Int((seconds / 60).rounded(.up))
        return minutes <= 1 ? "in 1 min" : "in \(minutes) min"
    }
}
```

- [ ] **Step 3: Wire the delegate and app**

`Sources/Nudgie/AppDelegate.swift` (replace):
```swift
import AppKit
import NudgieCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = Coordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator.start(demo: Self.demoKind())
    }

    /// `Nudgie --demo eyes` shows a card for that reminder right away.
    static func demoKind() -> ReminderKind? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--demo"), args.indices.contains(i + 1) else { return nil }
        return ReminderKind(rawValue: args[i + 1])
    }
}
```

`Sources/Nudgie/NudgieApp.swift` (replace):
```swift
import SwiftUI

struct NudgieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(coordinator: appDelegate.coordinator)
        } label: {
            Image(systemName: "face.smiling")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            Text("Settings arrive in Task 12").padding(40)
        }
    }
}
```

- [ ] **Step 4: Build and verify by running**

Run: `swift build 2>&1 | grep -E "error|warning: var|Build complete" | head`
Expected: `Build complete!` and no errors.

Run: `swift run Nudgie --verbose --demo eyes`
Expected within 2 seconds: `[nudgie] show ["eyes"] for 20s`, then after 20 more seconds `[nudgie] hide`. While it runs, click the face icon: the menu shows "Counting", five "in N min" rows (Eyes shows "now" during the demo), a "Today:" line, Take a break now, Pause, Settings…, Quit. Choose Pause → For 1 hour: the status line changes to "Paused until …" and the rows show "in 20 min" etc. again (timers were reset). Choose Pause → Resume. Quit with ⌘Q from the menu.

- [ ] **Step 5: Commit**

```bash
git add Sources/Nudgie
git commit -m "feat(app): add Coordinator heartbeat and menu bar menu

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: The sticker card (theme, mascot, confetti, panel, sound)

**Files:**
- Create: `Sources/Nudgie/UI/Theme.swift`, `Sources/Nudgie/UI/MascotView.swift`, `Sources/Nudgie/UI/ConfettiView.swift`, `Sources/Nudgie/UI/CardView.swift`, `Sources/Nudgie/UI/CardPanel.swift`, `Sources/Nudgie/Sound.swift`
- Modify: `Sources/Nudgie/Coordinator.swift` (play sound in `show`), `Sources/Nudgie/AppDelegate.swift` (own the panel controller)

**Interfaces:**
- Consumes: `Coordinator`, `CardPresentation` (Task 9); `ReminderKind` (Core).
- Produces: `enum Theme`, `extension View { func sticker(fill:outline:shadow:) }`, `enum MascotPose { case eyes, water, walk, posture, stretch, shh, sleepy; init(kind:) }`, `struct MascotView(pose:accent:size:)`, `struct ConfettiView(colors:)`, `struct CardView(coordinator:)` with `static let width: CGFloat = 340`, `static let height: CGFloat = 170`, `struct PillButtonStyle`, `final class CardPanelController(coordinator:)`, `enum Sound { static let available: [String]; static func play(_ name: String) }`.

- [ ] **Step 1: Theme and sticker modifier**

`Sources/Nudgie/UI/Theme.swift`:
```swift
import SwiftUI
import NudgieCore

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Colours and type for the "sticker buddy" look (spec section 9).
enum Theme {
    static let ink = Color(hex: 0x1B1B1F)
    static let cream = Color(hex: 0xFFF8EE)
    static let cornerRadius: CGFloat = 24
    static let outline: CGFloat = 3

    static func accent(_ kind: ReminderKind) -> Color {
        switch kind {
        case .eyes: Color(hex: 0x3DF5B4)      // electric mint
        case .water: Color(hex: 0x4DB8FF)     // sky
        case .walk: Color(hex: 0xFF8C42)      // tangerine
        case .posture: Color(hex: 0xFF6FB5)   // bubblegum
        case .stretch: Color(hex: 0xFFE24D)   // lemon
        }
    }

    static func headline(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .medium, design: .rounded) }

    static func ground(_ scheme: ColorScheme) -> Color { scheme == .dark ? ink : cream }
    static func text(_ scheme: ColorScheme) -> Color { scheme == .dark ? cream : ink }
}

/// Flat fill, thick outline, hard offset shadow: a paper sticker.
struct StickerStyle: ViewModifier {
    var fill: Color
    var outline: Color
    var shadow: Color
    var radius: CGFloat = Theme.cornerRadius

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(shadow).offset(x: 6, y: 6)
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
                RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(outline, lineWidth: Theme.outline)
            }
        )
    }
}

extension View {
    func sticker(fill: Color, outline: Color, shadow: Color) -> some View {
        modifier(StickerStyle(fill: fill, outline: outline, shadow: shadow))
    }
}
```

- [ ] **Step 2: Mascot**

`Sources/Nudgie/UI/MascotView.swift`:
```swift
import SwiftUI
import NudgieCore

enum MascotPose: Equatable {
    case eyes, water, walk, posture, stretch, shh, sleepy

    init(kind: ReminderKind) {
        switch kind {
        case .eyes: self = .eyes
        case .water: self = .water
        case .walk: self = .walk
        case .posture: self = .posture
        case .stretch: self = .stretch
        }
    }
}

/// Nudgie: a round blob with big eyes, drawn entirely with shapes. One pose per reminder.
struct MascotView: View {
    let pose: MascotPose
    let accent: Color
    var size: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wiggle = false

    var body: some View {
        ZStack {
            if pose == .walk {
                HStack(spacing: size * 0.18) {
                    leg.rotationEffect(.degrees(wiggle ? 14 : -14))
                    leg.rotationEffect(.degrees(wiggle ? -14 : 14))
                }
                .offset(y: size * 0.42)
            }
            Ellipse()
                .fill(accent)
                .overlay(Ellipse().stroke(Theme.ink, lineWidth: Theme.outline))
                .scaleEffect(x: bodyScale.width, y: bodyScale.height)
                .offset(y: bounce)
            face.offset(y: bounce)
            if pose == .water {
                glass.offset(x: size * 0.42, y: size * 0.22)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { wiggle = true }
        }
    }

    // MARK: Pose geometry

    private var bodyScale: CGSize {
        switch pose {
        case .stretch: CGSize(width: 0.8, height: wiggle ? 1.28 : 1.08)   // taffy
        case .posture: CGSize(width: 1.05, height: wiggle ? 1.0 : 0.8)    // slouch, then sit up
        default: CGSize(width: 1, height: 1)
        }
    }

    private var bounce: CGFloat { pose == .walk && wiggle ? -6 : 0 }

    private var pupilOffset: CGFloat {
        switch pose {
        case .eyes: wiggle ? size * 0.07 : -size * 0.07   // looking far away, left then right
        case .sleepy: 0
        default: size * 0.02
        }
    }

    // MARK: Parts

    private var leg: some View {
        Capsule().fill(Theme.ink).frame(width: size * 0.1, height: size * 0.28)
    }

    private var glass: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.white.opacity(0.9))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.accent(.water)).frame(height: size * 0.16).padding(2)
            }
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.ink, lineWidth: 2))
            .frame(width: size * 0.22, height: size * 0.3)
    }

    private var face: some View {
        VStack(spacing: size * 0.06) {
            HStack(spacing: size * 0.12) {
                eye
                eye
            }
            mouth
        }
    }

    private var eye: some View {
        ZStack {
            Circle().fill(.white).overlay(Circle().stroke(Theme.ink, lineWidth: 2))
            if pose == .sleepy {
                Capsule().fill(Theme.ink).frame(width: size * 0.14, height: 2)
            } else {
                Circle().fill(Theme.ink)
                    .frame(width: size * 0.08, height: size * 0.08)
                    .offset(x: pupilOffset)
            }
        }
        .frame(width: size * 0.22, height: size * 0.22)
    }

    @ViewBuilder private var mouth: some View {
        switch pose {
        case .shh:
            ZStack {
                Circle().fill(Theme.ink).frame(width: size * 0.09, height: size * 0.09)
                Capsule().fill(Theme.ink)
                    .frame(width: size * 0.05, height: size * 0.24)
                    .rotationEffect(.degrees(12))
                    .offset(x: size * 0.04)
            }
        case .sleepy:
            Text("z z")
                .font(.system(size: size * 0.16, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
        case .posture:
            Capsule().fill(Theme.ink).frame(width: size * 0.18, height: 2.5)
        default:
            SmileShape()
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: size * 0.22, height: size * 0.1)
        }
    }
}

/// A smile: the lower arc of a circle.
struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY), radius: rect.width / 2,
                    startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
        return path
    }
}
```

- [ ] **Step 3: Confetti and sound**

`Sources/Nudgie/UI/ConfettiView.swift`:
```swift
import SwiftUI

/// A one-shot burst. Put it in the view tree when you want it to fire; it animates on appear.
struct ConfettiView: View {
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [Particle] = []
    @State private var fired = false

    struct Particle: Identifiable {
        let id = UUID()
        let angle: Double
        let distance: CGFloat
        let color: Color
        let size: CGFloat
        let spin: Double
    }

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 0.6)
                    .rotationEffect(.degrees(fired ? p.spin : 0))
                    .offset(x: fired ? cos(p.angle) * p.distance : 0,
                            y: fired ? sin(p.angle) * p.distance + 30 : 0)
                    .opacity(fired ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            particles = (0..<28).map { _ in
                Particle(angle: .random(in: 0..<(2 * .pi)),
                         distance: .random(in: 60...140),
                         color: colors.randomElement() ?? Theme.ink,
                         size: .random(in: 6...11),
                         spin: .random(in: -360...360))
            }
            withAnimation(.easeOut(duration: 0.8)) { fired = true }
        }
    }
}
```

`Sources/Nudgie/Sound.swift`:
```swift
import AppKit

/// Plays one of the built-in macOS alert sounds.
enum Sound {
    static let available = ["Pop", "Tink", "Glass", "Ping", "Purr", "Blow", "Bottle", "Frog",
                            "Funk", "Hero", "Morse", "Submarine", "Basso", "Sosumi"]
    private static var current: NSSound?

    static func play(_ name: String) {
        let path = "/System/Library/Sounds/\(name).aiff"
        guard let sound = NSSound(contentsOfFile: path, byReference: true) else { return }
        current = sound   // keep it alive until it finishes
        sound.play()
    }
}
```

- [ ] **Step 4: Card view**

`Sources/Nudgie/UI/CardView.swift`:
```swift
import SwiftUI
import NudgieCore

/// The floating reminder card: ring + mascot on the left, copy and buttons on the right.
struct CardView: View {
    static let width: CGFloat = 340
    static let height: CGFloat = 170
    /// Extra room around the card for the sticker shadow and the entry tilt.
    static let margin: CGFloat = 12

    let coordinator: Coordinator

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var celebrating = false

    var body: some View {
        ZStack {
            if let card = coordinator.card {
                content(card)
            }
            if celebrating {
                ConfettiView(colors: ReminderKind.allCases.map(Theme.accent))
            }
        }
        .frame(width: Self.width + Self.margin * 2, height: Self.height + Self.margin * 2)
    }

    private func content(_ card: CardPresentation) -> some View {
        let accent = Theme.accent(card.accentKind)
        let text = Theme.text(scheme)
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(text.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress(card))
                    .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: card.secondsLeft)
                MascotView(pose: MascotPose(kind: card.accentKind), accent: accent, size: 64)
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 6) {
                Text(card.headline)
                    .font(Theme.headline())
                    .foregroundStyle(text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle(card))
                    .font(Theme.body())
                    .foregroundStyle(text.opacity(0.8))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Button { celebrate() } label: { Text("Did it!").font(Theme.headline(13)) }
                        .buttonStyle(PillButtonStyle(fill: accent, outline: Theme.ink, text: Theme.ink))
                    Button { coordinator.snooze() } label: {
                        Text("\(coordinator.settings.snoozeMinutes) more min").font(Theme.body(12))
                    }
                    .buttonStyle(PillButtonStyle(fill: .clear, outline: text, text: text))
                    Spacer()
                    Text(timeLeft(card))
                        .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(text.opacity(0.7))
                }
            }
        }
        .padding(18)
        .frame(width: Self.width, height: Self.height)
        .sticker(fill: Theme.ground(scheme), outline: text, shadow: scheme == .dark ? accent : Theme.ink)
        .overlay(alignment: .topTrailing) {
            Button { coordinator.close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(text.opacity(0.6))
                    .padding(8)
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("Close without counting")
        }
        .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -2))
        .scaleEffect(appeared || reduceMotion ? 1 : 0.92)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { appeared = true }
            }
        }
    }

    private func progress(_ card: CardPresentation) -> Double {
        guard card.plan.countdownSeconds > 0 else { return 0 }
        return Double(card.secondsLeft) / Double(card.plan.countdownSeconds)
    }

    private func timeLeft(_ card: CardPresentation) -> String {
        guard card.plan.isTimed else { return "" }
        return String(format: "%d:%02d", card.secondsLeft / 60, card.secondsLeft % 60)
    }

    private func subtitle(_ card: CardPresentation) -> String {
        if card.plan.kinds.count == 1 { return card.accentKind.instruction }
        return card.plan.kinds.map { "\($0.emoji) \($0.title)" }.joined(separator: " · ")
    }

    private func celebrate() {
        if reduceMotion {
            coordinator.didIt()
            return
        }
        celebrating = true
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            coordinator.didIt()
            celebrating = false
        }
    }
}

struct PillButtonStyle: ButtonStyle {
    var fill: Color
    var outline: Color
    var text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(outline, lineWidth: 2))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
```

- [ ] **Step 5: Panel controller and wiring**

`Sources/Nudgie/UI/CardPanel.swift`:
```swift
import AppKit
import SwiftUI

/// Floats the card in the top-right of the menu-bar screen without ever taking keyboard focus.
final class CardPanelController {
    private var panel: NSPanel?
    private let coordinator: Coordinator

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
        coordinator.onShowCard = { [weak self] in self?.show() }
        coordinator.onHideCard = { [weak self] in self?.hide() }
    }

    func show() {
        hide()
        let size = NSSize(width: CardView.width + CardView.margin * 2, height: CardView.height + CardView.margin * 2)
        // A fresh hosting view each time so the entry wobble replays.
        let hosting = NSHostingView(rootView: CardView(coordinator: coordinator))
        hosting.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false               // the sticker draws its own
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = hosting

        // screens[0] is the one with the menu bar. Inset the *visible* card 16 pt from the corner.
        if let screen = NSScreen.screens.first {
            let visible = screen.visibleFrame
            let inset = 16 - CardView.margin
            panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - inset,
                                         y: visible.maxY - size.height - inset))
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}
```

In `Sources/Nudgie/Coordinator.swift`, inside `show(_ plan:)` after the `card = ...` line, add:
```swift
        if settings.soundEnabled, !planner.isQuiet {
            Sound.play(settings.soundName)
        }
```

In `Sources/Nudgie/AppDelegate.swift`, add a stored property and create it before starting:
```swift
    private var cardPanel: CardPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        cardPanel = CardPanelController(coordinator: coordinator)
        coordinator.start(demo: Self.demoKind())
    }
```

- [ ] **Step 6: Build and check every visual claim in the spec**

Run: `swift build 2>&1 | grep -E "error|Build complete" | head`
Expected: `Build complete!`

Run each of these and look at the top-right corner of the main screen:

1. `swift run Nudgie --demo eyes`: mint card, ring drains over 20 s, pupils dart left and right, headline is one of the eyes lines, subtitle is the 20-feet instruction, "0:20" counts down, then the card disappears on its own and the Pop sound played when it appeared.
2. `swift run Nudgie --demo walk`: tangerine, legs swinging, "3:00".
3. `swift run Nudgie --demo water`: sky blue, glass beside the blob, no time text, gone after 30 s.
4. `swift run Nudgie --demo posture`: pink, blob squashes and sits up.
5. `swift run Nudgie --demo stretch`: lemon, blob stretches tall, "1:00".
6. Click "Did it!": confetti, then the card leaves. Click "5 more min" on the next demo: card leaves at once. Click ✕: card leaves.
7. Focus test: open TextEdit, start typing, run `--demo eyes` from the terminal, keep typing while the card appears. The cursor must stay in TextEdit.
8. Full-screen test: put Safari in full screen, run `--demo posture`. The card must appear over it.
9. Dark mode: System Settings → Appearance → Dark, run `--demo eyes`. Ink card, cream text, mint shadow.
10. Reduce Motion: System Settings → Accessibility → Display → Reduce motion on, run `--demo eyes`: no wobble, no darting pupils, "Did it!" gives no confetti. Turn it back off.

Fix anything that does not match before committing.

- [ ] **Step 7: Commit**

```bash
git add Sources/Nudgie
git commit -m "feat(ui): add sticker card with mascot, countdown ring, confetti, floating panel and sound

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: Menu bar icon (drawn template image with blink, shh, zzz)

**Files:**
- Create: `Sources/Nudgie/UI/MenuBarIcon.swift`
- Modify: `Sources/Nudgie/NudgieApp.swift` (use the drawn icon as the label)

**Interfaces:**
- Consumes: `IconState` (Task 9).
- Produces: `enum MenuBarIcon { static func image(for state: IconState) -> NSImage }`.

- [ ] **Step 1: Draw the icon**

`Sources/Nudgie/UI/MenuBarIcon.swift`:
```swift
import AppKit

/// Nudgie's face at 18 pt as a template image, so it follows light and dark menu bars.
enum MenuBarIcon {
    static func image(for state: IconState) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let body = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 2.5))
            body.lineWidth = 1.8
            body.stroke()

            let eyeY = rect.midY + 1
            for x in [rect.midX - 3.2, rect.midX + 3.2] {
                switch state {
                case .blink, .zzz:
                    let line = NSBezierPath()
                    line.move(to: NSPoint(x: x - 1.5, y: eyeY))
                    line.line(to: NSPoint(x: x + 1.5, y: eyeY))
                    line.lineWidth = 1.5
                    line.lineCapStyle = .round
                    line.stroke()
                case .normal, .shh:
                    NSBezierPath(ovalIn: NSRect(x: x - 1.4, y: eyeY - 1.4, width: 2.8, height: 2.8)).fill()
                }
            }

            switch state {
            case .shh:
                NSBezierPath(ovalIn: NSRect(x: rect.midX - 1, y: rect.midY - 4.5, width: 2, height: 2)).fill()
                let finger = NSBezierPath()
                finger.move(to: NSPoint(x: rect.midX + 0.5, y: rect.midY - 6.5))
                finger.line(to: NSPoint(x: rect.midX + 2.5, y: rect.midY - 1))
                finger.lineWidth = 1.6
                finger.lineCapStyle = .round
                finger.stroke()
            case .zzz:
                let z = NSAttributedString(string: "z", attributes: [
                    .font: NSFont.systemFont(ofSize: 7, weight: .black),
                    .foregroundColor: NSColor.black,
                ])
                z.draw(at: NSPoint(x: rect.maxX - 6, y: rect.maxY - 8))
            case .normal, .blink:
                let smile = NSBezierPath()
                smile.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY - 1.5), radius: 3,
                                startAngle: 200, endAngle: 340, clockwise: false)
                smile.lineWidth = 1.5
                smile.lineCapStyle = .round
                smile.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
```

- [ ] **Step 2: Use it as the label**

In `Sources/Nudgie/NudgieApp.swift`, replace the `label:` closure:
```swift
        } label: {
            Image(nsImage: MenuBarIcon.image(for: appDelegate.coordinator.iconState))
        }
```

- [ ] **Step 3: Build and verify**

Run: `swift build 2>&1 | grep -E "error|Build complete" | head` → `Build complete!`

Run `swift run Nudgie` and watch the menu bar: a small round face with two dots and a smile. It blinks (eyes become lines) for one second roughly every 30 seconds. Choose Pause → For 1 hour: the face shows closed eyes with a "z". Resume. Open Photo Booth (camera on): within 2 seconds the face shows the finger-on-lips pose. Quit Photo Booth: face returns to normal within 2 seconds. Switch the menu bar between light and dark (System Settings → Appearance): the icon stays legible in both.

- [ ] **Step 4: Commit**

```bash
git add Sources/Nudgie/UI/MenuBarIcon.swift Sources/Nudgie/NudgieApp.swift
git commit -m "feat(ui): draw menu bar face icon with blink, shh and zzz states

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 12: Settings window (Reminders, Meetings and hours, General)

**Files:**
- Create: `Sources/Nudgie/UI/SettingsView.swift`
- Modify: `Sources/Nudgie/NudgieApp.swift` (real Settings scene)

**Interfaces:**
- Consumes: `Coordinator.settings`, `Coordinator.updateSettings(_:)`, `Coordinator.resetSettingsToDefaults()`, `Sound.available`, `Sound.play`, `MascotView`, `Theme`.
- Produces: `struct SettingsView(coordinator:)`, `enum LaunchAtLogin { static func set(_ enabled: Bool) throws; static var isEnabled: Bool }`.

Design: the window edits a local `draft` copy of the settings and pushes every change to the coordinator, which saves it. If the coordinator's settings change from elsewhere (reset to defaults), the draft follows.

- [ ] **Step 1: Write the settings views**

`Sources/Nudgie/UI/SettingsView.swift`:
```swift
import AppKit
import ServiceManagement
import SwiftUI
import NudgieCore

struct SettingsView: View {
    let coordinator: Coordinator
    @State private var draft: NudgieSettings

    init(coordinator: Coordinator) {
        self.coordinator = coordinator
        _draft = State(initialValue: coordinator.settings)
    }

    var body: some View {
        TabView {
            RemindersTab(draft: $draft)
                .tabItem { Label("Reminders", systemImage: "bell") }
            MeetingsTab(draft: $draft)
                .tabItem { Label("Meetings & hours", systemImage: "video") }
            GeneralTab(draft: $draft, coordinator: coordinator)
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 540, height: 480)
        .overlay(alignment: .bottomTrailing) {
            MascotView(pose: .eyes, accent: Theme.accent(.eyes), size: 44)
                .padding(12)
                .allowsHitTesting(false)
        }
        .onChange(of: draft) { _, new in coordinator.updateSettings(new) }
        .onChange(of: coordinator.settings) { _, new in
            if new != draft { draft = new }
        }
    }
}

// MARK: - Reminders

struct RemindersTab: View {
    @Binding var draft: NudgieSettings

    var body: some View {
        Form {
            ForEach(ReminderKind.allCases, id: \.self) { kind in
                Section {
                    Toggle(isOn: binding(kind).isEnabled) {
                        Text("\(kind.emoji) \(kind.title)").font(Theme.headline(14))
                    }
                    Stepper("Every \(draft.reminder(kind).intervalMinutes) min",
                            value: binding(kind).intervalMinutes,
                            in: NudgieSettings.intervalRange, step: 5)
                    if kind.defaultBreakSeconds > 0 {
                        Stepper("Break lasts \(draft.reminder(kind).breakSeconds) s",
                                value: binding(kind).breakSeconds, in: 10...600, step: 10)
                    }
                    Text(kind.instruction).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func binding(_ kind: ReminderKind) -> Binding<ReminderSetting> {
        Binding(get: { draft.reminder(kind) }, set: { draft.setReminder($0, for: kind) })
    }
}

// MARK: - Meetings and hours

struct MeetingsTab: View {
    @Binding var draft: NudgieSettings
    @State private var newPrefix = ""

    static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    struct RunningApp {
        let name: String
        let bundleID: String
    }

    var body: some View {
        Form {
            Section("Stay quiet when") {
                Toggle("The camera or microphone is in use", isOn: $draft.quietOnCameraOrMic)
                Toggle("A browser or meeting app is the front window", isOn: $draft.quietOnQuietApps)
                Text("Reminders that come due while quiet wait, then show 30 seconds after you are free.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Quiet apps (bundle id prefixes)") {
                ForEach(draft.quietAppPrefixes, id: \.self) { prefix in
                    HStack {
                        Text(prefix).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            draft.quietAppPrefixes.removeAll { $0 == prefix }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(prefix)")
                    }
                }
                HStack {
                    TextField("com.example.app", text: $newPrefix)
                    Button("Add") { add(newPrefix) }
                    Menu("Running app…") {
                        ForEach(runningApps, id: \.bundleID) { app in
                            Button(app.name) { add(app.bundleID) }
                        }
                    }
                }
                Button("Reset list to defaults") {
                    draft.quietAppPrefixes = NudgieSettings.defaultQuietAppPrefixes
                }
            }
            Section("Work hours") {
                Toggle("Only remind during work hours", isOn: $draft.workHours.isEnabled)
                Stepper("From \(clock(draft.workHours.startMinute))",
                        value: $draft.workHours.startMinute, in: 0...(24 * 60 - 30), step: 30)
                Stepper("To \(clock(draft.workHours.endMinute))",
                        value: $draft.workHours.endMinute, in: 30...(24 * 60), step: 30)
                HStack {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(Self.dayNames[day - 1], isOn: dayBinding(day)).toggleStyle(.button)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var runningApps: [RunningApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let id = app.bundleIdentifier, let name = app.localizedName else { return nil }
                return RunningApp(name: name, bundleID: id)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func add(_ raw: String) {
        let prefix = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty, !draft.quietAppPrefixes.contains(prefix) else { return }
        draft.quietAppPrefixes.append(prefix)
        newPrefix = ""
    }

    private func dayBinding(_ day: Int) -> Binding<Bool> {
        Binding(get: { draft.workHours.weekdays.contains(day) },
                set: { on in
                    if on { draft.workHours.weekdays.insert(day) } else { draft.workHours.weekdays.remove(day) }
                })
    }

    private func clock(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}

// MARK: - General

struct GeneralTab: View {
    @Binding var draft: NudgieSettings
    let coordinator: Coordinator
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Sound") {
                Toggle("Play a sound when a card appears", isOn: $draft.soundEnabled)
                HStack {
                    Picker("Sound", selection: $draft.soundName) {
                        ForEach(Sound.available, id: \.self) { Text($0) }
                    }
                    Button("Play") { Sound.play(draft.soundName) }
                }
                .disabled(!draft.soundEnabled)
            }
            Section("Snooze") {
                Stepper("Snooze for \(draft.snoozeMinutes) min", value: $draft.snoozeMinutes, in: 1...30)
            }
            Section("Startup") {
                Toggle("Launch Nudgie at login", isOn: $draft.launchAtLogin)
                    .onChange(of: draft.launchAtLogin) { _, on in
                        do {
                            try LaunchAtLogin.set(on)
                            loginError = nil
                        } catch {
                            loginError = "Could not change the login item: \(error.localizedDescription). This only works from the built Nudgie.app, not from swift run."
                        }
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
            Section {
                Button("Reset everything to defaults") { coordinator.resetSettingsToDefaults() }
                Text("Nudgie \(NudgieCore.version) · free and source-available · PolyForm Shield 1.0.0 · nothing leaves your Mac")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

enum LaunchAtLogin {
    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
}
```

- [ ] **Step 2: Real Settings scene**

In `Sources/Nudgie/NudgieApp.swift`, replace the placeholder `Settings { ... }` with:
```swift
        Settings {
            SettingsView(coordinator: appDelegate.coordinator)
        }
```

- [ ] **Step 3: Build and verify**

Run: `swift build 2>&1 | grep -E "error|Build complete" | head` → `Build complete!`

Run `swift run Nudgie`, open the menu, choose Settings…:
1. Reminders: toggle Eyes off. Open the menu again: the Eyes row is gone. Toggle it back on. Step "Every" for Water to 50: the menu's Water row shows a new time on next open.
2. Meetings: add `com.apple.TextEdit` via the Running app… menu (open TextEdit first). Click into TextEdit; the status line reads "Quiet: Meeting app in front". Remove it with the ✕; status returns to "Counting". Reset list to defaults restores 19 entries.
3. Work hours: switch on, set a window that excludes now; status reads "Off the clock". Switch off.
4. General: pick "Glass", click Play, hear it. Toggle Launch at login: expect the red note (not bundled yet); Task 13 makes it work. Reset everything to defaults: all tabs return to defaults.
5. Quit and relaunch: settings persisted (check the water interval you changed).

- [ ] **Step 4: Commit**

```bash
git add Sources/Nudgie
git commit -m "feat(ui): add settings window with reminders, meeting rules, work hours and general tabs

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 13: App bundle, icon and install

**Files:**
- Create: `Resources/Info.plist`, `tools/make-app.sh`, `tools/make-icon.swift`, `Resources/Nudgie.icns` (generated, committed)

**Interfaces:**
- Consumes: the `Nudgie` executable product; `Makefile` targets from Task 1 (`app`, `run`, `install`).
- Produces: `build/Nudgie.app`, ad-hoc signed, no Dock icon.

- [ ] **Step 1: Info.plist**

`Resources/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>Nudgie</string>
    <key>CFBundleIconFile</key><string>Nudgie</string>
    <key>CFBundleIdentifier</key><string>com.gouravkakkar.nudgie</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>Nudgie</string>
    <key>CFBundleDisplayName</key><string>Nudgie</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Gourav Kakkar. Licensed under the PolyForm Shield License 1.0.0.</string>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key><false/>
</dict>
</plist>
```

- [ ] **Step 2: Icon generator**

`tools/make-icon.swift` (run once with `swift tools/make-icon.swift` from the repo root; commits the result):
```swift
import AppKit
import Foundation

// Renders Nudgie's face into every size iconutil needs and writes Resources/Nudgie.icns.

let ink = NSColor(red: 0.106, green: 0.106, blue: 0.122, alpha: 1)
let cream = NSColor(red: 1.0, green: 0.973, blue: 0.933, alpha: 1)
let mint = NSColor(red: 0.239, green: 0.961, blue: 0.706, alpha: 1)

func draw(size s: CGFloat) {
    let background = NSBezierPath(roundedRect: NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88),
                                  xRadius: s * 0.2, yRadius: s * 0.2)
    cream.setFill(); background.fill()
    ink.setStroke(); background.lineWidth = s * 0.03; background.stroke()

    let blob = NSBezierPath(ovalIn: NSRect(x: s * 0.2, y: s * 0.2, width: s * 0.6, height: s * 0.56))
    mint.setFill(); blob.fill()
    blob.lineWidth = s * 0.03; blob.stroke()

    for x in [s * 0.4, s * 0.6] {
        let white = NSBezierPath(ovalIn: NSRect(x: x - s * 0.08, y: s * 0.44, width: s * 0.16, height: s * 0.16))
        NSColor.white.setFill(); white.fill()
        white.lineWidth = s * 0.02; white.stroke()
        let pupil = NSBezierPath(ovalIn: NSRect(x: x, y: s * 0.49, width: s * 0.06, height: s * 0.06))
        ink.setFill(); pupil.fill()
    }

    let smile = NSBezierPath()
    smile.appendArc(withCenter: NSPoint(x: s * 0.5, y: s * 0.42), radius: s * 0.08,
                    startAngle: 200, endAngle: 340, clockwise: false)
    smile.lineWidth = s * 0.025
    smile.lineCapStyle = .round
    smile.stroke()
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(size: CGFloat(pixels))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: "build/Nudgie.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, pixels) in sizes {
    try png(pixels: pixels).write(to: iconset.appendingPathComponent("\(name).png"))
}
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "Resources/Nudgie.icns"]
try iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Resources/Nudgie.icns" : "iconutil failed with \(iconutil.terminationStatus)")
```

Run: `mkdir -p build && swift tools/make-icon.swift && ls -la Resources/Nudgie.icns`
Expected: `Wrote Resources/Nudgie.icns` and a file of a few hundred KB. Open it with `qlmanage -p Resources/Nudgie.icns` to eyeball the face.

- [ ] **Step 3: Bundle script**

`tools/make-app.sh` (then `chmod +x tools/make-app.sh`):
```bash
#!/bin/bash
# Builds release and assembles build/Nudgie.app with an ad-hoc signature.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=Nudgie
OUT="build/$APP.app"

swift build -c release 2>&1 | tail -1

rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp ".build/release/$APP" "$OUT/Contents/MacOS/$APP"
cp Resources/Info.plist "$OUT/Contents/Info.plist"
cp Resources/Nudgie.icns "$OUT/Contents/Resources/Nudgie.icns"
printf 'APPL????' > "$OUT/Contents/PkgInfo"

codesign --force --sign - --identifier com.gouravkakkar.nudgie "$OUT"
echo "Built $OUT"
```

- [ ] **Step 4: Build, run, install, verify**

Run: `make app && codesign -dv build/Nudgie.app 2>&1 | grep -E "Identifier|Signature"`
Expected: `Built build/Nudgie.app`, `Identifier=com.gouravkakkar.nudgie`, `Signature=adhoc`.

Run: `make run`. The face appears in the menu bar, no Dock icon, no window. Finder shows the mint face icon on `build/Nudgie.app`. Open Settings → General → Launch at login: no red error now; `sfltool dumpbtm 2>/dev/null | grep -i nudgie` or System Settings → General → Login Items shows Nudgie. Switch it off again. Quit.

Run: `make install && ls /Applications | grep Nudgie` → `Nudgie.app`.

- [ ] **Step 5: Commit**

```bash
git add Resources tools Makefile
git commit -m "build: add Info.plist, icon generator, bundle script and install target

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 14: README (SEO), licence, contributor terms, user docs and CI

**Files:**
- Create: `README.md`, `LICENSE`, `CONTRIBUTING.md`, `CHANGELOG.md`, `docs/user-guide.md`, `docs/qa-checklist.md`, `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: spec sections 3, 4, 13, 14 (copy the wording; do not invent claims).

- [ ] **Step 1: Licence text from the source, not from memory**

```bash
{
  echo "Copyright 2026 Gourav Kakkar"
  echo "Licensed under the PolyForm Shield License 1.0.0"
  echo
  curl -fsSL https://raw.githubusercontent.com/polyformproject/polyform-licenses/1.0.0/PolyForm-Shield-1.0.0.md
} > LICENSE
head -6 LICENSE
```
Expected: the two notice lines, then `# PolyForm Shield License 1.0.0`. If curl fails, stop and say so; do not paste licence text from memory.

- [ ] **Step 2: README**

`README.md`:
```markdown
# Nudgie — the free break reminder for Mac (20-20-20 eye breaks, posture, water and stretch nudges that stay quiet in meetings)

Nudgie is a free break reminder app for macOS that lives in your menu bar and nudges you to rest your eyes with the 20-20-20 rule, sit up straight, drink water, stand up and stretch. It only counts time you are actually at the Mac, so it never nags you after lunch, and it automatically goes quiet when your camera or mic is on or when a browser or meeting app is in front. Native Swift, no Electron, nothing leaves your machine.

Nudgie is a free alternative to paid Mac break apps such as LookAway (from $19) and Time Out's paid upgrades, and a lighter native alternative to Stretchly.

> Free and source-available. Use it at home or at work. Only the author may sell it. See [Licence](#licence).

## What it nudges you about

| Reminder | Default | The nudge |
|---|---|---|
| 👀 Eyes (20-20-20 rule) | every 20 min, 20 s | Look at something 20 feet away |
| 🚶 Stand and walk | every 60 min, 3 min | A short lap beats a stiff back |
| 💧 Drink water | every 45 min | A glass, not a sip |
| 🪑 Posture check | every 30 min | Shoulders back, screen at eye level |
| 🙆 Stretch | every 60 min, 1 min | Neck, shoulders, wrists |

Every reminder can be switched off or retimed.

## Why Nudgie is different

- **Meeting-aware break timer.** Quiet when the camera or mic is in use, or when a browser or meeting app (Zoom, Teams, Slack, FaceTime, Webex, Discord, Chrome, Safari, Arc, Firefox…) is the front window. Reminders wait, then show 30 seconds after you are free.
- **Counts only active time.** Locked, asleep or away for 5 minutes resets the timers. Coming back from lunch never triggers a pile of stale reminders.
- **A card, not a nag.** A small sticker-style card in the corner with a countdown ring, "Did it!" and "5 more min". It never steals your keyboard focus and shows over full-screen apps.
- **Quirky on purpose.** Nudgie the blob changes pose per reminder, the copy is cheeky, and "Did it!" throws confetti. Reduce Motion is respected.
- **Private by design.** No account, no network, no analytics. Settings live in your user defaults and nowhere else.
- **Native Swift menu bar app.** No Electron, no background helpers, no permission prompts.

## Install

Nudgie is not yet notarised (that needs a paid Apple Developer account), so macOS shows a warning the first time you open a downloaded copy.

1. Download `Nudgie.app.zip` from the latest [release](../../releases) and unzip it.
2. Move `Nudgie.app` to `/Applications`.
3. Right-click `Nudgie.app` → **Open** → **Open**. You only have to do this once.

If you prefer the terminal:

```bash
xattr -d com.apple.quarantine /Applications/Nudgie.app
```

Or build it yourself (Xcode 26 or newer):

```bash
git clone https://github.com/gouravkakkar/nudgie.git
cd nudgie
make install
```

## Use

- Click the face in the menu bar for status, what is coming next, today's count, **Take a break now**, **Pause** and **Settings…**.
- Settings has three tabs: Reminders, Meetings & hours (quiet rules, quiet-app list, work hours) and General (sound, snooze length, launch at login).
- Full guide: [docs/user-guide.md](docs/user-guide.md).

## Build and test

```bash
make test     # unit tests for the core logic
make app      # build/Nudgie.app
make run      # build and launch it
```

`swift run Nudgie --probe` prints the live detector values (idle time, lock, camera, mic, front app) so you can check meeting detection on your Mac. `swift run Nudgie --demo eyes` shows a card at once.

## Licence

Nudgie is **free and source-available** under the [PolyForm Shield License 1.0.0](LICENSE). You may use it, at home or at work, change it and share it. You may not sell it or offer a product that competes with it. Only the author, Gourav Kakkar, may sell Nudgie. This is not an OSI open-source licence, on purpose.

## Contributing

Bug reports and pull requests are welcome. By contributing you agree to the terms in [CONTRIBUTING.md](CONTRIBUTING.md).

---

*Keywords: break reminder mac, 20-20-20 rule app, eye strain app for Mac, posture reminder mac, drink water reminder mac, stand up reminder, RSI prevention, menu bar app, free LookAway alternative, free Time Out alternative, Stretchly alternative, meeting-aware break timer.*
```

- [ ] **Step 3: Contributor terms, changelog, user guide, QA checklist**

`CONTRIBUTING.md`:
```markdown
# Contributing to Nudgie

Thanks for helping. Please read this before opening a pull request.

## Licence of contributions

Nudgie is licensed under the PolyForm Shield License 1.0.0. By submitting a contribution (code, docs, artwork, copy) you agree that:

1. You wrote it, or you have the right to contribute it.
2. Your contribution is licensed to the project under the PolyForm Shield License 1.0.0, and
3. You grant Gourav Kakkar a perpetual, worldwide, irrevocable, royalty-free licence to use, modify, sublicense, relicense and sell your contribution as part of Nudgie or derived products.

Point 3 is what keeps Nudgie free for everyone while letting one person, the author, offer paid versions later. If you are not comfortable with that, please open an issue instead of a pull request.

## How to contribute

- Open an issue first for anything bigger than a typo.
- Run `make test` before pushing. Core logic changes need tests in `Tests/NudgieCoreTests`.
- Keep the app free of network calls and third-party dependencies.
- Follow the spec in `docs/superpowers/specs/` for behaviour and the "sticker buddy" look.
```

`CHANGELOG.md`:
```markdown
# Changelog

## 0.1.0 — unreleased

- First version: eyes (20-20-20), walk, water, posture and stretch reminders.
- Active-time timers with away reset, work hours and manual pause.
- Meeting-aware quiet mode: camera or mic in use, browser or meeting app in front.
- Sticker-style floating card with mascot, countdown ring, confetti and sound.
- Menu bar face icon, settings window, launch at login.
```

`docs/user-guide.md`:
```markdown
# Nudgie user guide

## The menu bar face

Click it to see:

- **Status line:** Counting, Quiet (with the reason), Paused until a time, Off the clock, or Away.
- **Next up:** each reminder and when it is due. Only active screen time counts.
- **Today:** breaks taken and snoozed.
- **Take a break now:** shows the reminder that is due soonest, even during a meeting.
- **Pause:** for 1 hour or until tomorrow. Pausing resets the timers, so nothing fires the moment you resume.
- **Settings…** and **Quit**.

The face blinks now and then, shows a finger on its lips while quiet, and closes its eyes with a "z" while paused or off the clock.

## The card

Appears in the top-right corner of the screen with the menu bar, over any app, without taking your keyboard focus.

- **Did it!** counts the break as taken and restarts the timer. Confetti included.
- **N more min** snoozes (5 minutes by default).
- **✕** closes without counting; the timer restarts.
- When the ring runs out, the break counts as taken. Water and posture cards show for 30 seconds.
- If several reminders are due together they share one card, and the buttons apply to all of them.
- Cards are at least 30 seconds apart, and wait 30 seconds after a meeting ends.

## Quiet during meetings

Nudgie is quiet when:

- The camera or microphone is in use by any app (checked every 2 seconds, no recording, no permission prompt), or
- The front window belongs to an app whose bundle id starts with one of the prefixes in Settings → Meetings & hours. The default list covers Safari, Chrome and Chrome web apps, Chromium, Arc, Brave, Edge, Firefox, Opera, Vivaldi, Zen, Orion, Zoom, Teams, Slack, FaceTime, Webex and Discord.

Timers keep counting during a meeting. Each reminder waits at most once, so a long call yields one eye break afterwards, not three.

Focus / Do Not Disturb is not detected in this version: macOS does not let apps read it without Full Disk Access.

## Active time and away

- A second counts while the Mac is unlocked, awake and you have used the keyboard or mouse in the last 5 minutes. Reading without touching anything still counts.
- Away (locked, asleep or idle) for 5 minutes or more resets every timer. That time was your break.

## Work hours

Switch on "Only remind during work hours" and pick a window and weekdays. Outside the window nothing counts and nothing shows.

## Settings are yours

Everything is stored in your macOS user defaults under `com.gouravkakkar.nudgie` (or the `Nudgie` domain when run from source). Nothing is sent anywhere. To start over: Settings → General → Reset everything to defaults.

## Command-line switches

- `Nudgie --probe` prints live detector values once a second.
- `Nudgie --demo eyes|water|walk|posture|stretch` shows a card immediately.
- `Nudgie --verbose` logs card show/hide events to the terminal.
```

`docs/qa-checklist.md`:
```markdown
# Manual QA checklist

Run through this before tagging a release. Tick each line.

## Card
- [ ] `--demo eyes`: card top-right, mint, 20 s ring, sound played, auto-hides at 0.
- [ ] Typing in TextEdit while the card appears: cursor stays in TextEdit.
- [ ] Safari in full screen: card still appears over it.
- [ ] Did it! → confetti → card gone → menu "Today" count went up by 1.
- [ ] 5 more min → card gone → reminder due again in 5 min (menu shows "in 5 min").
- [ ] ✕ → card gone, Today count unchanged.
- [ ] Dark mode: ink card, cream text, readable.
- [ ] Reduce Motion on: no wobble, no confetti, no pupil darting.

## Meetings
- [ ] Open Photo Booth: status "Quiet: Camera is on", icon shows shh face, `--demo` card is hidden or does not appear.
- [ ] Quit Photo Booth: status back to Counting within 2 s; a pending card appears after about 30 s.
- [ ] Click into Safari: status "Quiet: Meeting app in front". Click into Terminal: Counting.
- [ ] Settings → toggle the camera rule off → Photo Booth no longer makes it quiet.

## Timing
- [ ] Lock the screen for 5+ minutes, unlock: every "Next up" row is back to its full interval.
- [ ] Lock for 1 minute, unlock: rows kept their countdown.
- [ ] Pause 1 hour: status shows the resume time, rows reset. Resume: Counting.
- [ ] Work hours on with a window that excludes now: Off the clock, nothing shows.

## Settings and bundle
- [ ] Change an interval, quit, relaunch: change persisted.
- [ ] Reset everything to defaults restores all tabs.
- [ ] `make app` → `codesign -dv` says adhoc; app has the face icon; no Dock icon.
- [ ] Launch at login from the built app: appears in System Settings → Login Items.
```

- [ ] **Step 4: CI**

`.github/workflows/ci.yml`:
```yaml
name: CI

on:
  push:
    branches: [main]
    tags: ["v*"]
  pull_request:

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Select the newest Xcode (Swift 6.2 needs Xcode 26+)
        run: |
          sudo xcode-select -s "$(ls -d /Applications/Xcode*.app | sort -V | tail -1)/Contents/Developer"
          swift --version
      - name: Unit tests
        run: swift test
      - name: Build app bundle
        run: ./tools/make-app.sh
      - name: Zip
        run: ditto -c -k --keepParent build/Nudgie.app build/Nudgie.app.zip
      - uses: actions/upload-artifact@v4
        with:
          name: Nudgie.app
          path: build/Nudgie.app.zip
      - name: Attach to release
        if: startsWith(github.ref, 'refs/tags/v')
        uses: softprops/action-gh-release@v2
        with:
          files: build/Nudgie.app.zip
```
If the hosted runner's newest Xcode is older than 26, change `runs-on` to `macos-26` (or the newest image GitHub offers) rather than lowering the Swift tools version.

- [ ] **Step 5: Verify links and wording, then commit**

Run: `grep -n "open source" README.md CONTRIBUTING.md docs/user-guide.md` → no matches (the phrase is "source-available"). Run: `head -3 LICENSE` shows the notice. `make test` still passes.

```bash
git add README.md LICENSE CONTRIBUTING.md CHANGELOG.md docs .github
git commit -m "docs: add README, PolyForm Shield licence, contributor terms, user guide, QA checklist and CI

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Plan self-review (done 2026-09-06)

**Spec coverage.** Section 2 decisions → Tasks 2–13. Section 3 name and SEO copy → Task 14 README (copied verbatim). Section 4 licence, contributor grant, "source-available" wording → Task 14. Section 5 architecture and units → Tasks 1–12 match the unit table one to one (`ReminderKind` T2, `NudgieSettings` T3, `ActivityState`/`QuietState`/`QuietPolicy` T4, `TimerEngine` T5, `CardPlanner` T6, `DailyStats`/`CopyPicker` T7, probes and `Store` T8, `Coordinator` and menu T9, card panel T10, icon T11, settings T12). Section 6 defaults → T2 tests. Section 7 timing rules → T5 tests. Section 8 quiet rules, default app list, settle gap → T4, T6, T8, T9. Section 9 window, grouping, visual direction, copy, sound, Reduce Motion → T7, T10. Section 10 menu and settings → T9, T11, T12. Section 11 persistence → T3, T7, T8. Section 12 error handling → T8 (`logOnce`, safe defaults), T8 store backup key. Section 13 tests and `--probe`/`--demo` → T2–T8, `docs/qa-checklist.md` in T14. Section 14 build, icon, CI, Gatekeeper note → T13, T14. Section 15 non-goals: nothing in the plan builds them.

**Placeholder scan.** No TBD/TODO. Every code step has full code. The one "fill in later" is the Settings scene placeholder in Task 9, replaced in Task 12, and the sound call added to `Coordinator.show` in Task 10, both spelled out.

**Type consistency.** `ReminderSetting(isEnabled:intervalMinutes:breakSeconds:)` used identically in T3, T5, T6, T12. `TimerEngine.TickOutcome` cases match between T5 and T9. `CardPlanner.forcePlan(kinds:settings:)` defined in T6, used in T9. `CardPresentation.accentKind` defined in T9, used in T10. `Coordinator.card`, `.settings`, `.didIt()`, `.snooze()`, `.close()` used in T10 match T9. `IconState` defined in T9, used in T11. `Sound.available`/`Sound.play` defined in T10, used in T12. `CardView.width/height/margin` defined and used in T10.

**Known risks to watch during execution.**
- Swift 6 strict concurrency around `addObserver` closures and `Timer` closures: the pattern used is `MainActor.assumeIsolated` inside `@Sendable` closures on the main queue. If the compiler objects to capturing `self`, mark the closure `[weak self]` and unwrap inside `assumeIsolated`.
- `MenuBarExtra` label images: if the blink does not visibly update, add `.id(appDelegate.coordinator.iconState)` to the `Image`.
- `SettingsLink` opens the Settings scene only on macOS 14+; the deployment target is 14, so this is fine.
