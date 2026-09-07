#!/bin/bash
# Sends build/Nudgie.app to Apple for notarisation, staples the ticket into the bundle, and
# writes build/Nudgie.app.zip ready to attach to a release. Run ./tools/make-app.sh first.
#
# Credentials, once, on your own machine (this stores them in your login keychain):
#   xcrun notarytool store-credentials nudgie --apple-id <you@example.com> --team-id <TEAMID>
# It asks for an app-specific password, which you create at appleid.apple.com -> Sign-In and
# Security -> App-Specific Passwords. Your real Apple ID password is never used here.
#
# In CI, set NOTARY_APPLE_ID, NOTARY_TEAM_ID and NOTARY_PASSWORD instead of the profile.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Nudgie.app"
ZIP="build/Nudgie.app.zip"
PROFILE="${NOTARY_KEYCHAIN_PROFILE:-nudgie}"

[ -d "$APP" ] || { echo "$APP is missing. Run ./tools/make-app.sh first." >&2; exit 1; }

# Apple rejects ad-hoc signatures, but only after a slow round trip. Catch it here instead.
if ! codesign -dvv "$APP" 2>&1 | grep -q "^Authority=Developer ID Application"; then
    echo "$APP is not signed with a Developer ID Application certificate, so Apple will" >&2
    echo "reject it. Create one at developer.apple.com -> Certificates, download and" >&2
    echo "double-click it, then run ./tools/make-app.sh again. See docs/releasing.md." >&2
    exit 1
fi

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Submitting to Apple. First runs usually take a few minutes."
if [ -n "${NOTARY_APPLE_ID:-}" ]; then
    xcrun notarytool submit "$ZIP" --wait \
        --apple-id "$NOTARY_APPLE_ID" --team-id "$NOTARY_TEAM_ID" --password "$NOTARY_PASSWORD"
else
    xcrun notarytool submit "$ZIP" --wait --keychain-profile "$PROFILE"
fi

# The ticket goes into the .app, so the zip has to be rebuilt afterwards or the download
# carries the pre-notarisation copy and users still see a warning.
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

# What Gatekeeper will say on someone else's Mac. Expect "source=Notarized Developer ID".
spctl --assess --type execute -vv "$APP"
echo "Notarised and stapled: $ZIP"
