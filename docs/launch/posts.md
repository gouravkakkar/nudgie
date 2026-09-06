# Launch posts for Nudgie 0.1.0

Ready-to-paste copy for each community, written to that community's rules. Post them yourself from your own accounts, one community at a time, a day or two apart. Automated or cross-posted promotion gets accounts banned on Hacker News, Reddit and Product Hunt, and those bans stick.

Links to use everywhere:

- Site: https://gouravkakkar.github.io/nudgie/
- Download: https://github.com/gouravkakkar/nudgie/releases/latest/download/Nudgie.app.zip
- Code: https://github.com/gouravkakkar/nudgie

Before posting anywhere: run through `docs/qa-checklist.md` once more on a clean user account if you can, and have the Gatekeeper steps ready to paste as a reply, because the first comment will be "it says it can't verify the developer".

---

## 1. Hacker News (Show HN)

Rules: title starts with "Show HN:", no marketing adjectives, link to the site, first comment from you explains why you built it and what is interesting technically. Never ask for upvotes anywhere. Post on a weekday around 8–10 am US Eastern.

**Title (78 chars max):**

Show HN: Nudgie – a free Mac break reminder that stays quiet during meetings

**URL:** https://gouravkakkar.github.io/nudgie/

**First comment (post it immediately after submitting):**

> I built Nudgie because every break reminder I tried had the same two problems: it nagged me right after lunch (it counted wall-clock time, not time at the keyboard), and it popped up in the middle of video calls.
>
> Nudgie is a native Swift menu-bar app. Five nudges: eyes (20-20-20), stand and walk, water, posture, stretch. Timers only count while you are actually using the Mac; lock the screen or close the lid for five minutes and they reset. It goes quiet when the camera or mic is in use, or a browser or meeting app is in front, and shows the waiting reminder 30 seconds after you're free.
>
> Technical bits that might interest people here:
> - Camera/mic detection reads CoreMediaIO's "device is running somewhere" flag and CoreAudio's per-process "is running input" property (macOS 14.2+), so there is no permission prompt and no capture. The per-process check matters because the device-wide flag reports AirPods playback as mic use.
> - The card is a non-activating NSPanel, so it never steals keyboard focus; it shows over full-screen apps.
> - Pure-logic core (timers, quiet policy, card planning) is a separate library driven by plain values, so it is unit-tested with a fake clock; the app layer injects fake probes for its own tests.
> - Swift 6 language mode, default MainActor isolation on the app target, no dependencies.
>
> It is free, and source-available (PolyForm Shield, not OSI open source: use it anywhere, change it, share it, just don't sell it). Not notarised yet, so there is a one-time "Open Anyway" step, documented on the site.
>
> Happy to answer questions about the detection approach or the timing rules.

---

## 2. Reddit

Rules differ per subreddit; read each sidebar first. Reddit's spam filter dislikes the same link posted to several subs within hours. Use a text post with the link inside, reply to every comment, and do not post to more than one sub per day.

### r/macapps (the best fit)

**Title:** Nudgie: a free, native menu-bar break reminder that goes quiet when you're on a call (20-20-20, posture, water, walk, stretch)

**Body:**

> I made a small free Mac app for break reminders and thought this sub might like it.
>
> What's different from the usual timers:
> - It counts only the time you're actually at the Mac. Lock the screen or walk away for 5 minutes and the timers reset, so no pile of stale reminders after lunch.
> - It stays quiet when your camera or mic is on, or when a browser or a meeting app (Zoom, Teams, Slack, FaceTime, Webex, Discord) is in front. The list is editable.
> - Small sticker-style card in the corner with a countdown, "Did it!" (confetti), snooze and close. It never steals keyboard focus.
> - Native Swift, about 800 KB, no Electron, no account, no network.
>
> Free and source-available. Not notarised yet (no paid developer account), so the first launch needs System Settings → Privacy & Security → Open Anyway; that's on the site.
>
> Site: https://gouravkakkar.github.io/nudgie/ · Code: https://github.com/gouravkakkar/nudgie
>
> Would love feedback on the default intervals and the quiet-app list.

### r/productivity

Check the sidebar: self-promotion is often limited to a weekly thread. Same body as above, shorter, and lead with the problem (nagging after lunch, popups on calls) rather than the app.

### r/swift or r/iOSProgramming (technical angle)

**Title:** Built a Swift 6 menu-bar app with per-process mic detection and a fully unit-tested timer core, source available

**Body:** the "technical bits" paragraph from the HN comment, plus a link to `Sources/NudgieCore/TimerEngine.swift` and `Sources/Nudgie/Probes/QuietProbe.swift`. Ask a real question ("anyone found a public way to read Focus state without Full Disk Access?"): it invites replies and is a genuine open problem for the app.

---

## 3. Product Hunt

Rules: you need a maker account; launches go live at 00:01 PT; the first hours matter, so post the launch when you can reply all day. Do not ask for upvotes in other communities.

**Name:** Nudgie
**Tagline (60 chars):** The Mac break reminder that knows you're in a meeting
**Description:**

> Nudgie lives in your menu bar and nudges you to rest your eyes (20-20-20), stand up, drink water, sit straight and stretch. It counts only real screen time, resets when you step away, and goes quiet when your camera or mic is on or a meeting app is in front. Native Swift, no account, no network, free.

**Topics:** Mac, Productivity, Health & Fitness, Open Source (note: Product Hunt's "open source" topic is loose; the licence is source-available)
**Gallery:** `site/og.png` as the thumbnail; screenshots of the card in each colour and the Settings window (take them on your Mac: Cmd-Shift-4, Space, click the card).
**First comment:** the HN first comment, minus the technical list, plus one line on why it is free.

---

## 4. X / Twitter

One thread, images attached (the card, the menu). Keep each post under 280 characters.

1. I built a free break reminder for Mac that knows when you're in a meeting. Meet Nudgie. 👀💧🚶🪑🙆 https://gouravkakkar.github.io/nudgie/
2. It counts only the time you're actually at the keyboard. Lock the screen or close the lid for 5 minutes and the timers reset. No nagging after lunch.
3. Camera or mic on? Zoom, Teams, Slack or a browser in front? It waits, then shows the reminder 30 seconds after you're free. No permission prompts, nothing recorded.
4. Native Swift, ~800 KB, no Electron, no account, no network. Free, source available. Code: https://github.com/gouravkakkar/nudgie
5. Not notarised yet (no $99 developer account), so there's a one-time "Open Anyway" step. If it helps you, a star on GitHub helps me.

---

## 5. Mastodon (mastodon.social, hachyderm.io, or wherever you are)

Same as the first X post, with hashtags: #macOS #Swift #indiedev #productivity #ergonomics. Mastodon likes a screenshot with alt text: "A small cream-coloured card with a green blob mascot, a countdown ring, and the text 'Your eyeballs called. They want a vacation.'"

---

## 6. AlternativeTo

Submit Nudgie as an app (Mac, Free, "source-available" in the licence field) and add it as an alternative to LookAway, Time Out, Stretchly, BreakTimer and Eye Care 20 20 20. Use the README opening paragraph as the description. Listings there rank well for "LookAway alternative" searches.

---

## 7. MacRumors forums (Mac Apps) and Lobsters

MacRumors: a short post in "Mac Apps", same as the r/macapps body; forum members prefer a direct download link and a screenshot.
Lobsters: invite-only; if you have an account, submit the GitHub repo with tags `macos`, `swift`, `release`, and a comment like the HN one. Do not submit to Lobsters and HN on the same day.

---

## 8. Later, when there is traction

- Homebrew tap (`brew install --cask gouravkakkar/tap/nudgie`), see TODOS.md.
- A short demo video (15 seconds: card appears, "Did it!", confetti) for the site and posts.
- Notarisation, which removes the biggest objection in every comment thread.
