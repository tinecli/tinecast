#!/usr/bin/env bash
set -euo pipefail

notarize() {
  local path="$1" zip
  if [ -z "${NOTARY_APPLE_ID:-}" ] || [ -z "${NOTARY_TEAM_ID:-}" ] || [ -z "${NOTARY_PASSWORD:-}" ]; then
    echo "  (notary creds unset, skipping notarization of $(basename "$path"))"
    return 0
  fi
  echo "› notarize $(basename "$path"), this can take a minute"
  if [[ "$path" == *.app ]]; then
    zip="$(mktemp -d)/$(basename "$path").zip"
    ditto -c -k --keepParent "$path" "$zip"
    xcrun notarytool submit "$zip" --apple-id "$NOTARY_APPLE_ID" \
      --team-id "$NOTARY_TEAM_ID" --password "$NOTARY_PASSWORD" --wait
    rm -rf "$(dirname "$zip")"
  else
    xcrun notarytool submit "$path" --apple-id "$NOTARY_APPLE_ID" \
      --team-id "$NOTARY_TEAM_ID" --password "$NOTARY_PASSWORD" --wait
  fi
  xcrun stapler staple "$path"
}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/tinecast.app"
DERIVED="$ROOT/.build/release"
VERSION="${TINECAST_VERSION:-0.1.0}"
BUILD="${TINECAST_BUILD:-1}"
SIGN_ID="${TINECAST_SIGN_ID:-Developer ID Application: Gustaf Eriksson (82K3YC8HVF)}"

echo "› release build (Apple Silicon)"
(cd "$ROOT" && xcodegen generate --quiet)
xcodebuild -project "$ROOT/Tinecast.xcodeproj" -scheme tinecast -configuration Release \
  -derivedDataPath "$DERIVED" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" CODE_SIGNING_ALLOWED=NO \
  -quiet build

echo "› assemble $APP"
rm -rf "$APP"
mkdir -p "$DIST"
ditto "$DERIVED/Build/Products/Release/tinecast.app" "$APP"

if [ "$SIGN_ID" = "-" ]; then
  echo "› ad-hoc sign + hardened runtime (unsigned distribution)"
  codesign --force --options runtime --entitlements "$ROOT/tinecast.entitlements" --sign - "$APP"
else
  echo "› sign ($SIGN_ID) + hardened runtime"
  codesign --force --options runtime --timestamp \
    --entitlements "$ROOT/tinecast.entitlements" --sign "$SIGN_ID" "$APP"
fi
codesign --verify --strict --verbose=1 "$APP" 2>&1 | tail -2

notarize "$APP"

echo "› dmg"
DMG="$DIST/tinecast-${VERSION}.dmg"
rm -f "$DMG"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/tinecast.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "tinecast ${VERSION}" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

notarize "$DMG"

echo ""
echo "✅ $APP"
echo "✅ $DMG ($(du -h "$DMG" | cut -f1))"
