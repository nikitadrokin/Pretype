#!/usr/bin/env bash
set -euo pipefail

CONF=${1:-release}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

APP_NAME=Pretype
BUNDLE_ID=app.pretype.Pretype
MACOS_MIN_VERSION=26.0
source "$ROOT/version.env"
MARKETING_VERSION=${PRETYPE_VERSION:-$MARKETING_VERSION}
BUILD_NUMBER=${PRETYPE_BUILD:-$BUILD_NUMBER}
ARCH=${ARCHES:-$(uname -m)}

swift build -c "$CONF" --arch "$ARCH"

product_path() {
  local candidates=(
    ".build/${ARCH}-apple-macosx/$CONF/$APP_NAME"
    ".build/$CONF/$APP_NAME"
  )
  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]] && lipo -archs "$candidate" 2>/dev/null | grep -qw "$ARCH"; then
      printf '%s\n' "$candidate"
      return
    fi
  done
  printf 'ERROR: missing %s binary for %s\n' "$APP_NAME" "$ARCH" >&2
  exit 1
}

APP="$ROOT/build/$APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$(product_path)" "$APP/Contents/MacOS/$APP_NAME"
chmod +x "$APP/Contents/MacOS/$APP_NAME"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>${APP_NAME}</string>
<key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
<key>CFBundleName</key><string>${APP_NAME}</string>
<key>CFBundleIconFile</key><string>Pretype</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
<key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
<key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSMicrophoneUsageDescription</key>
<string>Pretype transcribes what you say into the text field you are typing in, on this Mac. Audio is never recorded to disk and never leaves your computer.</string>
</dict></plist>
PLIST

[[ -f Assets/Pretype.icns ]] && cp Assets/Pretype.icns "$APP/Contents/Resources/Pretype.icns"
xattr -cr "$APP"
find "$APP" -name '._*' -delete

IDENTITY=${APP_IDENTITY:-}
if [[ -z "$IDENTITY" && "${SIGNING_MODE:-}" != adhoc ]]; then
  IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null | awk '/Apple Development/ {print $2; exit}')
fi
if [[ -n "$IDENTITY" ]]; then
  codesign --force --sign "$IDENTITY" --entitlements Scripts/Pretype.entitlements "$APP"
  echo "Signed with: $IDENTITY"
else
  codesign --force --sign - --entitlements Scripts/Pretype.entitlements "$APP"
  echo "Signed ad hoc"
fi

codesign --verify --deep --strict "$APP"
echo "Created $APP"
