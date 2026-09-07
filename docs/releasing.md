# Releasing Nudgie

How a build gets from this repo onto someone else's Mac without a scary dialog.

## What notarising actually does

Apple runs an automated malware check on the app and, if it passes, issues a **ticket** that
says so. Stapling attaches that ticket to the app bundle. When someone downloads Nudgie and
double-clicks it, macOS finds the ticket and opens the app straight away.

Without a ticket, macOS shows "Apple could not verify Nudgie is free of malware" and the
person has to go into System Settings to allow it. That is the three-step dance the website
used to describe. Most people give up instead.

Two things are needed, and they are different things:

| Thing | What it is | Where it comes from |
|---|---|---|
| **Developer ID Application certificate** | Proves the app came from you | developer.apple.com, free with the paid account |
| **App-specific password** | Lets `notarytool` talk to Apple as you | appleid.apple.com |

An *Apple Distribution* certificate is not the same thing. That one is for the Mac App Store
and Apple will not notarise a build signed with it.

## One-time setup

### 1. Create the Developer ID Application certificate

1. Open <https://developer.apple.com/account/resources/certificates/list>.
2. Click **+**, choose **Developer ID Application**, then **Continue**.
3. When asked for a certificate signing request, follow Apple's instructions: open
   **Keychain Access → Certificate Assistant → Request a Certificate From a Certificate
   Authority**, save the request to disk, and upload it.
4. Download the certificate it gives you and double-click it. It lands in your login keychain.

Check it worked:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

One line should come back. `tools/make-app.sh` looks for exactly that and switches from an
ad-hoc signature to the real one on its own.

### 2. Store notarisation credentials

Create an app-specific password at <https://appleid.apple.com> → **Sign-In and Security →
App-Specific Passwords**. Then run this yourself — it prompts for the password and stores it
in your keychain, so it never has to be typed again or written into a file:

```bash
xcrun notarytool store-credentials nudgie --apple-id <you@example.com> --team-id <TEAMID>
```

Your Team ID is the code in brackets after your name in `security find-identity`, and is also
on the Apple Developer membership page. The profile name `nudgie` is what `tools/notarize.sh`
looks for by default.

## Cutting a release from your Mac

```bash
make notarize
```

That builds a universal release binary, signs it with the Developer ID certificate under the
hardened runtime, sends it to Apple, waits for the answer, staples the ticket, and writes
`build/Nudgie.app.zip`.

The first submission usually takes a few minutes. Later ones are often under a minute.

The last line of output is what Gatekeeper will say on a stranger's Mac. You want:

```
build/Nudgie.app: accepted
source=Notarized Developer ID
```

Then tag it, and attach the zip to the GitHub release.

## Cutting a release from CI

Pushing a `v*` tag runs the `release` job in `.github/workflows/ci.yml`, which rebuilds,
signs, notarises, staples and attaches the zip to the GitHub release. It needs five repository
secrets (**Settings → Secrets and variables → Actions**):

| Secret | What to put in it |
|---|---|
| `MACOS_CERT_P12` | The certificate and its private key, exported from Keychain Access as a `.p12`, then base64 encoded |
| `MACOS_CERT_PASSWORD` | The password you set when exporting that `.p12` |
| `NOTARY_APPLE_ID` | The Apple ID email on the developer account |
| `NOTARY_TEAM_ID` | Your ten-character Team ID |
| `NOTARY_PASSWORD` | The app-specific password from step 2 |

To produce `MACOS_CERT_P12`: in Keychain Access, find **Developer ID Application: your name**,
right-click → **Export**, save as `.p12` with a password, then

```bash
base64 -i Certificates.p12 | pbcopy
```

and paste that into the secret. Delete the `.p12` afterwards — it holds your private key.

## Release checklist

1. `swift test` is green and `docs/qa-checklist.md` has been walked through.
2. Bump `CFBundleShortVersionString` in `Resources/Info.plist`.
3. Bump the version in `CHANGELOG.md` and move the entries under a dated heading.
4. Update the three version strings on the site: the hero fine print, the JSON-LD
   `softwareVersion`, and anything in the install section that names a version.
5. Commit, then `git tag vX.Y.Z && git push origin main --tags`.
6. Watch the `release` job. When it is green, check the download opens cleanly on a Mac that
   has never run Nudgie before.

## When something goes wrong

**`notarize.sh` stops with "not signed with a Developer ID Application certificate".**
The certificate is missing from this Mac's keychain, so `make-app.sh` fell back to an ad-hoc
signature. Run the `security find-identity` check above.

**Apple rejects the submission.** Ask it why:

```bash
xcrun notarytool log <submission-id> --keychain-profile nudgie
```

The usual causes are a missing hardened runtime (`--options runtime`) or a missing secure
timestamp (`--timestamp`). `tools/make-app.sh` passes both, so a failure here normally means
something signed the bundle afterwards.

**The app still warns after notarising.** The ticket is stapled into `Nudgie.app`, so the zip
has to be rebuilt after stapling. `tools/notarize.sh` does that; a hand-made zip taken before
stapling will not carry the ticket.

**Certificates expire after five years.** Signatures made before expiry stay valid because of
the secure timestamp, but you cannot make new ones. Renew by repeating step 1.
