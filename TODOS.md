# TODOS

Deferred work with enough context to pick up cold. Added during the plan engineering review on 2026-09-06.

## Focus / Do Not Disturb awareness via a Focus Filter extension
- **What:** Let a Focus mode (Do Not Disturb, Work, Personal) silence Nudgie.
- **Why:** The spec wanted it; macOS blocks reading `~/Library/DoNotDisturb/DB/` without Full Disk Access (verified 2026-09-06: "Operation not permitted"), so v1 dropped it.
- **Pros:** Apple-sanctioned, no scary permission, works with scheduled Focus modes.
- **Cons:** Needs an App Intents `SetFocusFilterIntent` extension, a real Xcode project or extra SwiftPM plumbing, and the user must add the filter to each Focus mode by hand.
- **Context:** Start from `QuietPolicy` (add a `focusOn` rule) and `QuietState`; the extension writes a flag the app reads.
- **Depends on:** v1 shipped; decide whether to move to an Xcode project.

## Notarisation and a Developer ID signature
- **What:** Sign with a Developer ID and notarise release builds so downloads open without the Gatekeeper warning.
- **Why:** First-run friction is the biggest install drop-off for indie Mac apps.
- **Pros:** One-click install; needed for Homebrew cask acceptance and for Sparkle updates.
- **Cons:** Apple Developer Program, $99 per year; secrets in CI.
- **Context:** `tools/make-app.sh` does ad-hoc signing today; replace `--sign -` with the identity and add `xcrun notarytool submit` in `.github/workflows/ci.yml` on tags.
- **Depends on:** the owner deciding to pay for the program (declined for now, 2026-09-06).

## Homebrew tap
- **What:** `brew install --cask gouravkakkar/tap/nudgie`.
- **Why:** Developers, the likeliest early users, install from the terminal.
- **Pros:** Easy updates; discoverable.
- **Cons:** Needs a `homebrew-tap` repo and a cask file updated on each release; the licence keeps it out of homebrew-cask core.
- **Context:** Cask points at the GitHub Release zip; automate the sha256 bump in CI.
- **Depends on:** first tagged release.

## CI runner must have Xcode 26
- **What:** Confirm `macos-latest` on GitHub Actions ships Xcode 26+ (Swift 6.2); otherwise pin `runs-on: macos-26`.
- **Why:** `swift-tools-version: 6.2` and `.defaultIsolation(MainActor.self)` need Swift 6.2; an older runner fails the very first CI run.
- **Context:** `.github/workflows/ci.yml` selects the newest Xcode on the image; if `swift --version` prints < 6.2 the job fails on `swift test`.
- **Depends on:** first push to GitHub.

## Screen-sharing and full-screen presentation detection
- **What:** Stay quiet while the screen is being shared or Keynote/PowerPoint is presenting.
- **Why:** A break card popping up on a shared screen is embarrassing.
- **Pros:** Completes the "never interrupt a meeting" promise.
- **Cons:** No public API says "someone is capturing my screen"; heuristics (frontmost presentation app in full screen via `CGWindowListCopyWindowInfo`) are approximate.
- **Context:** Add as a third rule in `QuietPolicy` with its own toggle.
- **Depends on:** nothing.
