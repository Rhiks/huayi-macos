#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-${HUAYI_VERSION:-1.4.2}}"
APP_NAME="Huayi"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
RELEASE_DIR="$ROOT_DIR/dist/release"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/huayi-release.XXXXXX")"
DMG_ROOT="$STAGING_DIR/dmg"

if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

HUAYI_VERSION="$VERSION" HUAYI_UNIVERSAL=1 "$ROOT_DIR/script/build_and_run.sh" --verify

ARCHS="$(/usr/bin/lipo -archs "$APP_BUNDLE/Contents/MacOS/$APP_NAME")"
[[ "$ARCHS" == *"arm64"* && "$ARCHS" == *"x86_64"* ]] || {
  echo "Expected a universal binary, got: $ARCHS" >&2
  exit 1
}

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR" "$DMG_ROOT"
/usr/bin/ditto "$APP_BUNDLE" "$DMG_ROOT/$APP_NAME.app"
ln -s /Applications "$DMG_ROOT/Applications"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
  "$APP_BUNDLE" "$RELEASE_DIR/Huayi-$VERSION-universal.zip"
/usr/bin/hdiutil create -quiet -ov -format UDZO \
  -volname "Huayi $VERSION" \
  -srcfolder "$DMG_ROOT" \
  "$RELEASE_DIR/Huayi-$VERSION-universal.dmg"

(
  cd "$RELEASE_DIR"
  /usr/bin/shasum -a 256 Huayi-* > SHA256SUMS.txt
  /usr/bin/shasum -a 256 -c SHA256SUMS.txt
)

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
echo "Release artifacts created in $RELEASE_DIR"
