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
- [ ] Settings → snooze 30 min, then --demo eyes: "30 more min" pill and the 0:20 label both fit.
- [ ] Leave the Mac idle 6+ minutes, then run --demo water: the card still appears (forced).

## Meetings
- [ ] Open Photo Booth: status "Quiet: Camera is on", icon shows the quiet face (straight-line mouth); a *scheduled* card waits; `--demo eyes` still shows (forced) but plays no sound.
- [ ] Quit Photo Booth: status back to Counting within 2 s; a pending card appears after about 30 s.
- [ ] Click into Safari: status "Quiet: Meeting app in front". Click into Terminal: Counting.
- [ ] Settings → toggle the camera rule off → Photo Booth no longer makes it quiet.
- [ ] Voice Memos → record: status "Quiet: Mic is on"; stop: Counting. Music through AirPods alone must NOT make it quiet (needs macOS 14.2 or newer; 14.0 and 14.1 fall back to a device-wide flag that does count playback).
- [ ] No sound plays for any card while quiet.

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
- [ ] With default settings, take an eyes card at 20 min, then confirm nothing appears again until 30 min after it, and that the next card lists every reminder that fell due in between.
- [ ] Settings → Reminders → Pacing: set the gap above a reminder's interval and check the orange line names that reminder.
- [ ] Set the gap to 0 and confirm cards return to the old 30-second spacing.
- [ ] Open Photo Booth while a card is up: the card hides, and when the meeting ends it comes back after the settle gap rather than waiting out the full 30 minutes.
- [ ] Menu bar face blinks about every 30 s; shows open eyes and a straight-line mouth while Photo Booth is open; shows closed eyes with a z while paused.
- [ ] Settings window: every tab renders, toggles and steppers change the menu's next-up rows, work-hours "To" follows "From" past it, changes survive a relaunch.
