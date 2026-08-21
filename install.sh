#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Huayi"
SOURCE_APP="$SCRIPT_DIR/dist/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"
INSTALL_APP="$INSTALL_DIR/$APP_NAME.app"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/huayi-install.XXXXXX")"
BACKUP_APP=""
INSTALL_ATTEMPTED=false
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"$SCRIPT_DIR/script/build_and_run.sh" --verify
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
mkdir -p "$INSTALL_DIR"
touch "$SCRIPT_DIR/dist/.metadata_never_index"

restore_on_error() {
  local exit_code=$?
  set +e
  if [[ -n "$BACKUP_APP" && -e "$BACKUP_APP" ]]; then
    if [[ -e "$INSTALL_APP" ]]; then
      mv "$INSTALL_APP" "$STAGING_DIR/failed-$APP_NAME.app"
    fi
    mv "$BACKUP_APP" "$INSTALL_APP"
  elif [[ "$INSTALL_ATTEMPTED" == true && -e "$INSTALL_APP" ]]; then
    mv "$INSTALL_APP" "$STAGING_DIR/failed-$APP_NAME.app"
  fi
  return "$exit_code"
}
cleanup_staging() {
  rm -rf "$STAGING_DIR"
}
trap restore_on_error ERR
trap cleanup_staging EXIT

if [[ -e "$INSTALL_APP" ]]; then
  pending_backup="$STAGING_DIR/$APP_NAME.app"
  mv "$INSTALL_APP" "$pending_backup"
  BACKUP_APP="$pending_backup"
fi

INSTALL_ATTEMPTED=true
/usr/bin/ditto "$SOURCE_APP" "$INSTALL_APP"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$INSTALL_APP"
/usr/bin/open -n "$INSTALL_APP"
"$LSREGISTER" -u "$SOURCE_APP" >/dev/null 2>&1 || true

echo "Installed $INSTALL_APP"
