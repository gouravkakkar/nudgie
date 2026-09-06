# Nudgie — design spec

Date: 2026-09-06
Status: draft for review
Owner: Gourav Kakkar (gouravkakkar)

## 1. What we are building

Nudgie is a free, quirky macOS menu-bar app that reminds you to look after
yourself while you work: rest your eyes, stand up and walk, drink water, fix
your posture and stretch. It counts only the time you actually spend using the
Mac, and it stays quiet while you are in a meeting.

Everything runs on your machine. No account, no network, no analytics.

## 2. Decisions already made

| Topic | Decision |
|---|---|
| Reminders in v1 | Eyes (20-20-20), stand and walk, drink water, posture check, stretch |
| Meeting rule | Smart detection: camera or mic in use, browser or meeting app in front, or Focus on. Each rule can be turned off. |
| How a reminder looks | A floating card in a screen corner with a countdown and Done / Snooze buttons. Optional sound. |
| Timing | Active time only. Pauses when locked or asleep. Away 5+ minutes counts as a break and resets timers. Optional work-hours window. |
| Look and feel | Quirky and cool: a mascot, sticker-style cards, cheeky copy, confetti. |
| Distribution | Free for anyone to download and use. Source published on GitHub. Only the author may sell it. |
| Tech | Native Swift 6.2 / SwiftUI, built with Swift Package Manager on macOS 26. No Electron, no runtime. |

## 3. Name, positioning and SEO copy

**Name:** Nudgie. (A web search found no existing Mac break app with this
name.) Bundle id: `com.gouravkakkar.nudgie`.

**Positioning:** the free, native, quirky alternative to paid Mac break
reminder apps. Competitors found on 2026-09-06: LookAway (paid, from $19
one-time), Time Out (free with $3.99 / $7.99 / $14.99 supporter unlocks),
Stretchly and BreakTimer (free, Electron-based), Intermission and Rest (paid).

**Repo tagline (GitHub "About", under 350 characters):**

> Free, quirky break reminder for macOS. 20-20-20 eye breaks, posture, water,
> walk and stretch nudges that auto-mute during meetings. Native Swift menu bar
> app, no Electron. A free alternative to LookAway and Time Out.

**README headline (H1):**

> Nudgie — the free break reminder for Mac (20-20-20 eye breaks, posture,
> water and stretch nudges that stay quiet in meetings)

**README opening paragraph:**

> Nudgie is a free break reminder app for macOS that lives in your menu bar and
> nudges you to rest your eyes with the 20-20-20 rule, sit up straight, drink
> water, stand up and stretch. It only counts time you are actually at the Mac,
> so it never nags you after lunch, and it automatically goes quiet when your
> camera or mic is on, when a browser or meeting app is in front, or when a
> Focus mode is active. Native Swift, no Electron, nothing leaves your machine.
> Nudgie is a free alternative to paid Mac break apps such as LookAway (from
> $19) and Time Out's paid upgrades, and a lighter native alternative to
> Stretchly.

**Search phrases to weave into the README naturally:** break reminder mac,
20-20-20 rule app, eye strain app for Mac, posture reminder mac, drink water
reminder mac, stand up reminder, RSI prevention, menu bar app, free LookAway
alternative, free Time Out alternative, Stretchly alternative, meeting-aware
break timer.

**GitHub topics:** macos, swift, swiftui, menu-bar-app, break-reminder,
eye-strain, 20-20-20, posture, wellness, productivity, rsi.

## 4. Licence

Requirement: anyone may download, use and share it for free, including at
work, but nobody except the author may sell it.

A licence that the Open Source Initiative recognises (MIT, Apache, GPL) cannot
do this: all of them let anyone sell copies. So Nudgie is **source-available**,
not "open source" in the strict sense. The README says "free and
source-available" and never claims OSI open source.

| Option | Anyone can use it, even at work | Nobody else can sell it | Notes |
|---|---|---|---|
| **PolyForm Shield 1.0.0 (chosen)** | Yes | Yes. Also bars free competing forks. | Plain-English, lawyer-drafted, has an SPDX id. |
| PolyForm Noncommercial 1.0.0 | No, businesses would need permission | Yes | Too strict for "free for anyone". |
| MIT + Commons Clause | Yes | Yes | Widely criticised as vague; confuses people who see "MIT". |

Files:

- `LICENSE`: the verbatim PolyForm Shield 1.0.0 text plus the required notice:
  `Copyright 2026 Gourav Kakkar. Licensed under the PolyForm Shield License 1.0.0`.
- `CONTRIBUTING.md`: contributors agree that their contribution is licensed to
  the project under the same licence **and** grant Gourav Kakkar a perpetual,
  irrevocable right to relicense and sell it. Without this, a contributor could
  block the author from selling code they wrote.
- Practical consequence: the app cannot go into Homebrew's main cask list
  (it requires OSI licences). A personal tap works fine.

## 5. Architecture

One Swift package, three targets, one build script.

```
Nudgie/
  Package.swift
  Sources/NudgieCore/      pure logic, no AppKit. Fully unit-tested.
  Sources/Nudgie/          the app: AppKit/SwiftUI, OS probes, windows.
  Tests/NudgieCoreTests/   swift test
  Resources/               Info.plist template, Nudgie.icns, sounds
  tools/make-app.sh        assembles build/Nudgie.app and ad-hoc signs it
  Makefile                 make test | make app | make run | make install
  docs/                    this spec, plans, user guide
```

Why SwiftPM instead of an Xcode project: builds and tests from the terminal
with no extra tools, opens in Xcode by double-clicking `Package.swift`, and
keeps the logic in a library that tests can drive with fake clocks and probes.
Swift language mode 6, with the app target using default MainActor isolation.

### Units and their one job

| Unit | Lives in | Does | Depends on |
|---|---|---|---|
| `ReminderKind` + `ReminderCatalog` | Core | The five reminders, their defaults, colours, mascot pose and copy lines | nothing |
| `NudgieSettings` | Core | Codable settings struct, defaults, migration | nothing |
| `ActivityState` | Core | Value type: idle seconds, locked, asleep, now | nothing |
| `QuietState` | Core | Value type: camera/mic busy, frontmost bundle id, focus on, manual pause | nothing |
| `QuietPolicy` | Core | Turns `QuietState` + settings into "quiet: yes/no, reason" | settings |
| `TimerEngine` | Core | Advances per-reminder accumulators from `ActivityState`, produces pending reminders, applies snooze/done/reset/work-hours | settings, `QuietPolicy` |
| `CardPlanner` | Core | Groups pending reminders into one card, enforces the 30 s breathing gap and the 30 s post-meeting settle | `TimerEngine` |
| `DailyStats` | Core | Counts taken / snoozed per day | nothing |
| `ActivityProbe` | App | Real values from `CGEventSource` idle time, screen lock notifications, sleep/wake | AppKit, CoreGraphics |
| `QuietProbe` | App | Camera via CoreMediaIO "running somewhere", mic via CoreAudio "running somewhere", frontmost app via `NSWorkspace`, Focus via `~/Library/DoNotDisturb/DB/Assertions.json` | CoreMediaIO, CoreAudio, AppKit |
| `Coordinator` | App | The 1 s heartbeat: read probes, feed the engine, ask the planner, show cards, persist | everything above |
| `CardPanel` | App | Non-activating floating `NSPanel` hosting the SwiftUI card | AppKit, SwiftUI |
| `MenuBar` | App | `MenuBarExtra` with status, next-up list, pause, settings, quit | SwiftUI |
| `SettingsWindow` | App | Three tabs: Reminders, Meetings and hours, General | SwiftUI |
| `Persistence` | App | Settings and stats in `UserDefaults` as JSON | Foundation |

Core has no AppKit import. Everything the OS tells us enters Core as a plain
value, so tests never touch the real OS.

## 6. Reminders and defaults

| Reminder | Every | Break lasts | Card behaviour |
|---|---|---|---|
| Eyes (20-20-20) | 20 min | 20 s | Countdown ring; auto-Done when it hits zero |
| Stand and walk | 60 min | 3 min | Countdown; auto-Done at zero |
| Drink water | 45 min | none | Shows for 30 s, then counts as Done |
| Posture check | 30 min | none | Shows for 30 s, then counts as Done |
| Stretch | 60 min | 1 min | Countdown; auto-Done at zero |

Each reminder can be switched off, and its interval (5–180 min) and break
length can be changed in Settings. Snooze length is one global setting,
default 5 min.

## 7. Timing engine

- Heartbeat: once per second on the main run loop.
- A second counts as **active** when the screen is not locked, the Mac is not
  asleep, and the last keyboard or mouse input was under 5 minutes ago.
  Reading without touching the mouse still counts, on purpose.
- **Away reset:** once the user has been away (idle, locked or asleep) for 5
  minutes or more, every accumulator resets to zero. The away time was the
  break.
- **Due:** when a reminder's accumulator reaches its interval it becomes
  *pending*. A reminder has at most one pending entry, so a 1-hour meeting
  produces one eye reminder afterwards, not three.
- **Done** (button, or countdown finished): accumulator back to zero.
- **Snooze:** accumulator set to `interval − snooze length`, so it comes back
  in 5 minutes.
- **Work hours** (off by default; preset weekdays 09:00–18:00): outside the
  window nothing counts and nothing shows. Menu bar shows "Off the clock".
- **Manual pause:** 1 hour, until tomorrow, or resume. Counting stops.

## 8. Quiet mode (meeting detection)

`QuietPolicy` says "quiet" when any enabled rule fires:

| Rule | Default | How the app knows | Permission needed |
|---|---|---|---|
| Camera or mic in use | on | CoreMediaIO device property "is running somewhere"; CoreAudio input device property "is running somewhere" | none (we never record, we only read a flag) |
| Browser or meeting app in front | on | `NSWorkspace.frontmostApplication` bundle id matched by prefix against the quiet list | none |
| Focus / Do Not Disturb on | on | Read `~/Library/DoNotDisturb/DB/Assertions.json`; non-empty assertion records means a Focus is on. Best effort: if the file is missing or unreadable, treat as not in Focus. | none (app is not sandboxed) |
| Manual pause | — | Menu bar | — |

Default quiet list (bundle id prefixes, editable in Settings):
Safari `com.apple.Safari`, Chrome `com.google.Chrome` (also matches Chrome
web apps such as Google Meet), Chromium `org.chromium.Chromium`, Arc
`company.thebrowser.Browser`, Brave `com.brave.Browser`, Edge
`com.microsoft.edgemac`, Firefox `org.mozilla.firefox`, Opera
`com.operasoftware.Opera`, Vivaldi `com.vivaldi.Vivaldi`, Zen
`app.zen-browser.zen`, Orion `com.kagi.kagimacOS`; Zoom `us.zoom.xos`, Teams
`com.microsoft.teams2` and `com.microsoft.teams`, Slack
`com.tinyspeck.slackmacgap`, FaceTime `com.apple.FaceTime`, Webex
`com.webex.meetingmanager` and `com.cisco.webexmeetingsapp`, Discord
`com.hnc.Discord`.

Behaviour while quiet: accumulators keep counting (you are still staring at a
screen), pending reminders wait, nothing is shown, and the menu bar icon shows
a "shh" face. When quiet ends, `CardPlanner` waits 30 seconds before showing
anything, so you are not hit the moment you hang up.

Probes are sampled every 2 seconds for camera, mic and Focus, and immediately
on app-switch notifications for the frontmost app.

## 9. The card: presentation and visual design

**Window:** an `NSPanel` that never takes keyboard focus
(`nonactivatingPanel`), floats above other windows, appears on every Space and
over full-screen apps, sits in the top-right corner of the screen that has the
menu bar, 16 pt in from the edges. Roughly 340 × 170 pt. Typing is never
interrupted.

**Grouping:** if several reminders are pending at once they share one card as
a short list ("Walk 3 min · Stretch · Water"). Done and Snooze apply to all of
them. The countdown is the longest break in the group.

**Visual direction: "sticker buddy".**

- **Mascot:** Nudgie, a round blob with big eyes, drawn entirely with SwiftUI
  shapes (no image assets). One pose per reminder: eyes rolling far away
  (Eyes), holding a glass with bubbles (Water), tiny legs mid-bounce (Walk),
  slouched-then-straightening (Posture), stretched tall like taffy (Stretch),
  and a "shh" finger-on-lips face for quiet mode.
- **Card style:** flat vivid fill, 3 pt ink outline, 24 pt corners, a hard
  offset shadow like a paper sticker, enters with a small spring wobble and a
  −2° tilt that settles to level.
- **Colours:** one accent per reminder. Eyes: electric mint. Water: sky blue.
  Walk: tangerine. Posture: bubblegum pink. Stretch: lemon. Card ground is
  cream in light mode and ink in dark mode. All text contrast ≥ 4.5:1.
- **Type:** SF Rounded, heavy weight for the headline, regular for the
  cheeky line.
- **Countdown:** a chunky progress ring around the mascot, ticking down.
- **Buttons:** "Did it!" (primary, accent-filled pill) and "5 more min"
  (ghost pill). A tiny ✕ closes without counting.
- **Delight:** confetti burst on "Did it!". Respects Reduce Motion: no wobble,
  no confetti, plain fade.
- **Sound:** optional (default on), a soft system sound from
  `/System/Library/Sounds` (starting with "Pop"). Never plays while quiet.

**Copy:** three to five rotating lines per reminder, never the same line
twice in a row. Starter set:

- Eyes: "Your eyeballs called. They want a vacation." / "Stare at something
  20 feet away. The wall counts." / "Blink. Blink again. Now look far away."
- Water: "Hydrate or dydrate." / "Plants get watered. So should you." /
  "Sip happens."
- Walk: "Legs. Remember those? Take them for a spin." / "Go touch grass,
  or at least the kitchen." / "Your chair needs some alone time."
- Posture: "You're doing the shrimp again." / "Shoulders down. Chin up.
  You've got this." / "Sit like someone's taking your photo."
- Stretch: "Reach for the ceiling. It's not going anywhere." / "Roll those
  shoulders like you mean it." / "Wrists, neck, shoulders. Go."

## 10. Menu bar and settings

**Menu bar:** Nudgie's face as a monochrome template icon (blinks every ~30 s;
"shh" face while quiet; "zzz" while paused). Clicking opens a menu:

- Status line: "Counting", "Quiet: camera is on", "Paused until 3:14 pm",
  "Off the clock".
- Next up: one row per enabled reminder, e.g. "👀 Eyes in 12 min".
- "Today: 7 breaks taken, 2 snoozed."
- Take a break now (shows the card for the reminder that is due soonest).
- Pause ▸ 1 hour / Until tomorrow / Resume.
- Settings… (⌘,), About Nudgie, Quit.

**Settings window,** three tabs, same sticker styling, mascot reacting in the
corner:

1. **Reminders:** per reminder, an on/off toggle, interval, break length.
2. **Meetings and hours:** the three quiet rules, the editable quiet-app list
   (add by picking a running app, remove with ✕), work hours toggle and range.
3. **General:** sound on/off and pick, snooze length, launch at login
   (`SMAppService`), "reset to defaults".

## 11. Persistence and stats

- `NudgieSettings` is stored as JSON under one `UserDefaults` key, with a
  `version` field for future migration.
- `DailyStats` keeps taken/snoozed counts keyed by local date; only today and
  yesterday are kept.
- Nothing else is written to disk.

## 12. Error handling

- Every probe returns a safe default on failure (camera/mic: not busy; Focus:
  off; frontmost: nil) and logs once through `os.Logger`. The app never
  crashes because the OS refused a query.
- If the Focus file does not exist on this macOS version, the Focus rule shows
  "Not available on this macOS" in Settings and does nothing.
- If the settings JSON fails to decode, defaults are used and the broken blob
  is kept under a backup key.
- If the screen with the menu bar disappears (display unplugged), the card
  re-anchors to the new main screen on next show.

## 13. Testing

**Unit tests in `NudgieCoreTests` (`swift test`), written first:**

- `TimerEngine`: counts only while active; pauses when locked/asleep/idle;
  resets after 5 min away; one pending entry per reminder; Done and Snooze
  arithmetic; work-hours window; manual pause.
- `QuietPolicy`: each rule alone; rules disabled in settings; prefix matching
  of bundle ids; manual pause wins.
- `CardPlanner`: grouping, 30 s breathing gap between cards, 30 s settle after
  quiet ends, countdown is the longest break.
- `NudgieSettings`: round-trips through JSON; unknown fields ignored; broken
  JSON falls back to defaults.
- `CopyPicker`: never repeats the previous line.
- `DailyStats`: rolls over at midnight local time.

**Verification against the real OS** (your contract-discipline rule: the
consumer must be proven against the real producer, not a mock):

- `Nudgie --probe` prints live values every second: idle seconds, locked,
  frontmost bundle id, camera busy, mic busy, focus on. Used to confirm
  detection on this Mac with Zoom, FaceTime, Chrome and a Focus toggled on.
- `Nudgie --demo <reminder>` shows a card immediately for visual checks.
- A manual QA checklist in `docs/qa-checklist.md` covering: card never steals
  focus, card shows over a full-screen app, quiet during a FaceTime call,
  settle gap after the call, away reset after 5 min lock, launch at login.

## 14. Build, run and distribution

- `make test` runs the unit tests. `make app` builds release and assembles
  `build/Nudgie.app` (Info.plist with `LSUIElement` so there is no Dock icon,
  bundle id, version, icon), then ad-hoc code-signs it. `make run` launches
  it. `make install` copies it to `/Applications`.
- App icon: `tools/make-icon.swift` renders the mascot to `Nudgie.icns` once;
  the result is committed so builds need no extra step.
- CI: a GitHub Actions workflow on a macOS runner runs `make test` and
  `make app` on every push and pull request, and attaches `Nudgie.app.zip` to
  a GitHub Release when a version tag is pushed.
- Repo files: `README.md` (section 3 copy, screenshots, install steps),
  `LICENSE`, `CONTRIBUTING.md`, `CHANGELOG.md`, `docs/user-guide.md`,
  `docs/plans/`, `.github/workflows/ci.yml`.
- Gatekeeper: without an Apple Developer account ($99/year) the app is not
  notarised, so first launch needs right-click → Open, or
  `xattr -d com.apple.quarantine`. The README documents this. Notarisation
  is an open item for you (section 16).

## 15. Not in v1 (future ideas)

Deep breathing and long-break reminders, end-of-day stop nudge, screen-sharing
and full-screen-presentation detection, full-screen break mode, iPhone sync,
Shortcuts and AppleScript hooks, weekly stats, localisation, Homebrew tap,
Sparkle auto-update, App Store build (would need sandboxing and would lose the
Focus rule).

## 16. Open items for your review

1. Name "Nudgie" and bundle id `com.gouravkakkar.nudgie`. Say the word if you
   want another name; nothing else depends on it yet.
2. Licence: PolyForm Shield 1.0.0 as chosen above. Note it also blocks free
   competing forks, which is stricter than "nobody can sell it" but in your
   favour.
3. Notarisation: do you have or want an Apple Developer account? Without it
   users see a Gatekeeper warning on first launch.
4. Default intervals in section 6. Easy to change later in Settings anyway.
