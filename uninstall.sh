#!/bin/zsh
set -euo pipefail

APP_NAME="Huayi"
INSTALL_APP="$HOME/Applications/$APP_NAME.app"
TRASH_APP="$HOME/.Trash/$APP_NAME-uninstalled-$(date +%Y%m%d-%H%M%S).app"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
if [[ -e "$INSTALL_APP" ]]; then
  mv "$INSTALL_APP" "$TRASH_APP"
  echo "Moved Huayi to $TRASH_APP"
else
  echo "Huayi is not installed at $INSTALL_APP"
fi
