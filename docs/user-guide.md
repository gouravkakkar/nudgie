# Nudgie user guide

## The menu bar face

Click it to see:

- **Status line:** Counting, Quiet (with the reason), Paused until a time, Off the clock, or Away.
- **Next up:** each reminder and when it is due. Only active screen time counts.
- **Today:** breaks taken and snoozed.
- **Take a break now:** shows the reminder that is due soonest, even during a meeting.
- **Pause:** for 1 hour or until tomorrow. Pausing resets the timers, so nothing fires the moment you resume.
- **Settings…** and **Quit**.

The face blinks now and then, presses its lips into a straight line while quiet, and closes its eyes with a "z" while paused or off the clock.

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
