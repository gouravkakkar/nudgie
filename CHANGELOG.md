# Changelog

## 0.1.1 — 2026-09-08

### Added

- **Why the break helps:** each card now carries a third line under the instruction saying what you get out of it — "Eases the strain of staring at one distance." Three phrasings per reminder, rotated like the headlines. Merged cards leave it off, because a benefit covering one of the three things being asked for reads as if it covered all of them.
- **Pacing:** cards are now at least 30 minutes apart by default (Settings → Reminders → Pacing, 0 to turn it off). Reminders that fall due inside the gap wait and arrive together on one card instead of firing one after another. A card taken off the screen by a meeting, a locked screen or a pause does not start the gap, because it never reached you. Note that a gap wider than a reminder's own interval overrides it: at the default, the 20-minute eye break arrives every 30 minutes, and Settings says so.

### Fixed

- The Pause submenu flickered and could not be clicked. The menu bar rebuilds its menu whenever its contents change, which closes any open submenu, and the contents were tracking the one-second heartbeat. The menu now changes only when a countdown crosses a minute, and Pause is three flat items rather than a submenu.
- The quiet face now presses its lips into a straight line instead of making an "o" shape.
- The website's mascot was lying on its side: it was picking up the countdown ring's -90° rotation. The rotation now applies to the ring alone.

### Changed

- Releases are signed with a Developer ID certificate and notarised by Apple, so a downloaded copy opens on a double-click instead of sending people into System Settings. See `docs/releasing.md`.
- The website leads with desk health — eyes, back, shoulders, hydration, movement — rather than with meeting detection, which is one feature among five reminders.

## 0.1.0 — 2026-09-06

- First version: eyes (20-20-20), walk, water, posture and stretch reminders.
- Active-time timers with away reset, work hours and manual pause.
- Meeting-aware quiet mode: camera or mic in use, browser or meeting app in front.
- Sticker-style floating card with mascot, countdown ring, confetti and sound.
- Menu bar face icon, settings window, launch at login.
