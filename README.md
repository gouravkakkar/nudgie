# Nudgie — the free break reminder for Mac (20-20-20 eye breaks, posture, water and stretch nudges that stay quiet in meetings)

Nudgie is a free break reminder app for macOS that lives in your menu bar and nudges you to rest your eyes with the 20-20-20 rule, sit up straight, drink water, stand up and stretch. It only counts time you are actually at the Mac, so it never nags you after lunch, and it automatically goes quiet when your camera or mic is on or when a browser or meeting app is in front. Native Swift, no Electron, nothing leaves your machine.

Nudgie is a free alternative to paid Mac break apps such as LookAway (from $19) and Time Out's paid upgrades, and a lighter native alternative to Stretchly.

**Website:** https://gouravkakkar.github.io/nudgie/ · **Download:** [Nudgie.app.zip](https://github.com/gouravkakkar/nudgie/releases/latest/download/Nudgie.app.zip) (macOS 14+, universal)

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

Works on macOS 14 Sonoma or newer, Apple Silicon and Intel (the download is a universal build).

Nudgie is not yet notarised (that needs a paid Apple Developer account), so macOS blocks a downloaded copy the first time. This is a one-time step:

1. Download `Nudgie.app.zip` from the latest [release](../../releases), unzip it, and move `Nudgie.app` to `/Applications`.
2. **macOS 15 Sequoia or newer:** double-click it, click **Done** on the "cannot verify" dialog, then open **System Settings → Privacy & Security**, scroll down, click **Open Anyway** next to the Nudgie message, then **Open**.
3. **macOS 14 Sonoma:** right-click `Nudgie.app` → **Open** → **Open**.

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
make notarize # sign, send to Apple, staple: build/Nudgie.app.zip
```

`make app` signs with a Developer ID Application certificate if this Mac has one, and falls back to an ad-hoc signature if it does not, so you never need one just to build. Cutting a public release does need one: [docs/releasing.md](docs/releasing.md) has the whole path, including the GitHub secrets the tag build uses.

`swift run Nudgie --probe` prints the live detector values (idle time, lock, camera, mic, front app) so you can check meeting detection on your Mac. `swift run Nudgie --demo eyes` shows a card at once.

## Licence

Nudgie is **free and source-available** under the [PolyForm Shield License 1.0.0](LICENSE). You may use it, at home or at work, change it and share it. You may not sell it or offer a product that competes with it. Only the author, Gourav Kakkar, may sell Nudgie. This is not an OSI open-source licence, on purpose.

## Contributing

Bug reports and pull requests are welcome. By contributing you agree to the terms in [CONTRIBUTING.md](CONTRIBUTING.md).

---

*Keywords: break reminder mac, 20-20-20 rule app, eye strain app for Mac, posture reminder mac, drink water reminder mac, stand up reminder, RSI prevention, menu bar app, free LookAway alternative, free Time Out alternative, Stretchly alternative, meeting-aware break timer.*
