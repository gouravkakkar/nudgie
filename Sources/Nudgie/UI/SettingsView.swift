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
            Section("Pacing") {
                Stepper(gapLabel, value: $draft.minimumGapMinutes,
                        in: NudgieSettings.minimumGapRange, step: 5)
                Text("Anything that falls due inside the gap waits and arrives on the next card, so several reminders come as one nudge instead of a run of them.")
                    .font(.caption).foregroundStyle(.secondary)
                if let squeezed {
                    Text(squeezed).font(.caption).foregroundStyle(.orange)
                }
            }
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

    private var gapLabel: String {
        draft.minimumGapMinutes == 0
            ? "No minimum gap between cards"
            : "At least \(draft.minimumGapMinutes) min between cards"
    }

    /// A gap wider than a reminder's own interval quietly overrides it. Say so rather than
    /// letting someone wonder why their 20 minute eye break arrives every 30.
    private var squeezed: String? {
        let tight = draft.enabledKinds
            .filter { draft.reminder($0).intervalMinutes < draft.minimumGapMinutes }
        guard !tight.isEmpty else { return nil }
        let names = tight.map(\.title).joined(separator: ", ")
        return "\(names) asked for less than this, so \(tight.count == 1 ? "it comes" : "they come") every \(draft.minimumGapMinutes) min instead."
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
        // Keep the window valid: end always after start, otherwise "Off the clock" would never end.
        .onChange(of: draft.workHours.startMinute) { _, start in
            if draft.workHours.endMinute <= start { draft.workHours.endMinute = min(start + 30, 24 * 60) }
        }
        .onChange(of: draft.workHours.endMinute) { _, end in
            if draft.workHours.startMinute >= end { draft.workHours.startMinute = max(end - 30, 0) }
        }
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
    @State private var loginEnabled = LaunchAtLogin.isEnabled
    @State private var loginNote: String? = LaunchAtLogin.note

    /// The system's login-item status is the truth; the toggle follows it and rolls back on failure.
    private var launchBinding: Binding<Bool> {
        Binding(get: { loginEnabled }, set: { wanted in
            do {
                try LaunchAtLogin.set(wanted)
                loginNote = LaunchAtLogin.note
            } catch {
                loginNote = "Could not change the login item: \(error.localizedDescription). This only works from the built Nudgie.app, not from swift run."
            }
            loginEnabled = LaunchAtLogin.isEnabled
            draft.launchAtLogin = loginEnabled
        })
    }

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
                Stepper("Snooze for \(draft.snoozeMinutes) min", value: $draft.snoozeMinutes,
                        in: NudgieSettings.snoozeRange)
            }
            Section("Startup") {
                Toggle("Launch Nudgie at login", isOn: launchBinding)
                if let loginNote {
                    Text(loginNote).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                Button("Reset everything to defaults") { coordinator.resetSettingsToDefaults() }
                Text("Nudgie \(NudgieCore.version) · free and source-available · PolyForm Shield 1.0.0 · nothing leaves your Mac")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // Someone may have changed it in System Settings → Login Items.
            loginEnabled = LaunchAtLogin.isEnabled
            loginNote = LaunchAtLogin.note
        }
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

    static var note: String? {
        switch SMAppService.mainApp.status {
        case .requiresApproval: "Waiting for your approval in System Settings → General → Login Items."
        default: nil
        }
    }
}
