#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Huayi"
PRODUCT_NAME="Huayi"
BUNDLE_ID="io.github.rhiks.huayi"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/huayi-build.XXXXXX")"
STAGED_APP_BUNDLE="$STAGING_DIR/$APP_NAME.app"
APP_CONTENTS="$STAGED_APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
FINAL_APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_FILE="$ROOT_DIR/Assets/Huayi.icns"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

cleanup_staging() {
  rm -rf "$STAGING_DIR"
}
trap cleanup_staging EXIT

cd "$ROOT_DIR"
swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$PRODUCT_NAME"

mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$ICON_FILE" "$APP_RESOURCES/Huayi.icns"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>Huayi</string>
  <key>CFBundleDisplayName</key>
  <string>划译</string>
  <key>CFBundleIconFile</key>
  <string>Huayi.icns</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.3.6</string>
  <key>CFBundleVersion</key>
  <string>14</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - \
  --requirements "=designated => identifier \"$BUNDLE_ID\"" \
  "$STAGED_APP_BUNDLE"

mkdir -p "$DIST_DIR"
touch "$DIST_DIR/.metadata_never_index"
PREVIOUS_APP="$STAGING_DIR/previous-$APP_NAME.app"
if [[ -e "$APP_BUNDLE" ]]; then
  mv "$APP_BUNDLE" "$PREVIOUS_APP"
fi
if ! mv "$STAGED_APP_BUNDLE" "$APP_BUNDLE"; then
  if [[ -e "$PREVIOUS_APP" ]]; then
    mv "$PREVIOUS_APP" "$APP_BUNDLE"
  fi
  exit 1
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$FINAL_APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    /usr/bin/plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null
    test -x "$FINAL_APP_BINARY"
    test -r "$APP_BUNDLE/Contents/Resources/Huayi.icns"
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
    "$FINAL_APP_BINARY" --filter-self-test
    "$FINAL_APP_BINARY" --routing-self-test
    "$FINAL_APP_BINARY" --clipboard-self-test
    "$LSREGISTER" -u "$APP_BUNDLE" >/dev/null 2>&1 || true
    echo "$APP_NAME package verified without launching the app: $APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
