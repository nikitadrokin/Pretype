#!/bin/bash
# Package Hunch.app for distribution.
#
# Two modes, picked by what's in the keychain:
#   - "Developer ID Application" certificate present -> hardened-runtime sign,
#     notarize, staple. Recipients just open the app. Notary credentials come
#     from the keychain profile "hunch" (one-time local setup:
#       xcrun notarytool store-credentials hunch
#     ) or, in CI, from an App Store Connect API key via
#     APPLE_API_KEY_PATH / APPLE_API_KEY_ID / APPLE_API_ISSUER.
#   - no such certificate -> ad-hoc signature; recipients clear Gatekeeper
#     once (see the printed steps).
#
# Intel Macs are not supported because Apple Intelligence requires Apple Silicon.
set -euo pipefail
cd "$(dirname "$0")/.."

test -d build/Hunch.app || { echo "build/Hunch.app not found — run ./Scripts/package_app.sh first."; exit 1; }

DIST=build/dist
rm -rf "$DIST"; mkdir -p "$DIST"
cp -R build/Hunch.app "$DIST/Hunch.app"
rm -f build/Hunch.app.zip

IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')
if [ -n "$IDENTITY" ]; then
    # Hardened runtime + secure timestamp are notarization requirements.
    # Single binary + resource-only bundles, so there is no nested code to sign.
    # The entitlements are what let the hardened runtime open the microphone
    # (dictation) — it denies it by default regardless of the TCC grant.
    codesign --force --options runtime --timestamp \
        --entitlements Scripts/Hunch.entitlements --sign "$IDENTITY" "$DIST/Hunch.app"
    codesign --verify --strict "$DIST/Hunch.app"

    ditto -c -k --keepParent "$DIST/Hunch.app" build/Hunch.app.zip
    # On a rejected submission --wait exits non-zero; the printed id feeds
    # `xcrun notarytool log <id>` for the reason.
    if [ -n "${APPLE_API_KEY_PATH:-}" ]; then
        xcrun notarytool submit build/Hunch.app.zip --wait \
            --key "$APPLE_API_KEY_PATH" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER"
    else
        xcrun notarytool submit build/Hunch.app.zip --wait --keychain-profile hunch
    fi

    # Staple the ticket so Gatekeeper passes offline, then re-zip the stapled app.
    xcrun stapler staple "$DIST/Hunch.app"
    rm build/Hunch.app.zip
    ditto -c -k --keepParent "$DIST/Hunch.app" build/Hunch.app.zip
    spctl -a -t exec -vv "$DIST/Hunch.app"
    echo "Built build/Hunch.app.zip ($(du -h build/Hunch.app.zip | cut -f1), notarized + stapled)."
    exit 0
fi

# No Developer ID certificate: strip the device-locked dev signature, re-sign
# ad-hoc (runs on any Apple Silicon Mac).
codesign --force --deep --sign - "$DIST/Hunch.app"
codesign --verify --deep --strict "$DIST/Hunch.app"

ditto -c -k --keepParent "$DIST/Hunch.app" build/Hunch.app.zip
echo "Built build/Hunch.app.zip ($(du -h build/Hunch.app.zip | cut -f1), ad-hoc signed)."

cat <<'EOF'

Send build/Hunch.app.zip to testers (Apple Silicon, macOS 26+). To open it once:

  xattr -dr com.apple.quarantine /path/to/Hunch.app && open /path/to/Hunch.app

  ...or without Terminal: double-click -> "blocked" -> System Settings ->
  Privacy & Security -> scroll down -> "Open Anyway".

Then grant Accessibility (and optionally Screen Recording) when prompted. The app
is not notarized (that needs a paid Apple Developer account); with a
"Developer ID Application" certificate in the keychain this script notarizes
automatically instead.
EOF
