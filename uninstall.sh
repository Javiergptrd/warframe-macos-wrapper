#!/bin/bash
# Remove the wrapper (and the game data inside it). Moves it to the Trash by default.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ROOT/lib/common.sh"

usage() {
  cat <<EOF
Usage: ./uninstall.sh [options]

  --name NAME      App name (default: $APP_NAME)
  --dir DIR        Folder of the app (default: $APP_DIR)
  --delete         Delete permanently instead of moving to the Trash
  --purge-cache    Also delete the downloaded template and engine archives
  --force          Remove an app that was not created by install.sh
  -y, --yes        Don't ask for confirmation
  -h, --help       Show this help
EOF
}

DELETE=0
PURGE=0
FORCE=0
ASSUME_YES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name)        APP_NAME="${2:?}"; shift 2 ;;
    --dir)         APP_DIR="${2:?}"; shift 2 ;;
    --delete)      DELETE=1; shift ;;
    --purge-cache) PURGE=1; shift ;;
    --force)       FORCE=1; shift ;;
    -y|--yes)      ASSUME_YES=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             die "Unknown option: $1 (see --help)" ;;
  esac
done

set_app_paths

if [ -d "$APP_PATH" ]; then
  if [ -z "$(plist_get WFWVersion)" ] && [ "$FORCE" = 0 ]; then
    die "$APP_PATH was not created by install.sh. Re-run with --force if you really want to remove it."
  fi
  SIZE="$(du -sh "$APP_PATH" 2>/dev/null | cut -f1)"
  if [ "$DELETE" = 1 ]; then
    confirm "Permanently delete $APP_PATH ($SIZE, including all downloaded game data)? This cannot be undone." ||
      { echo "Cancelled."; exit 0; }
  else
    confirm "Move $APP_PATH ($SIZE, including all downloaded game data) to the Trash?" ||
      { echo "Cancelled."; exit 0; }
  fi

  if app_is_running; then
    info "Stopping $APP_NAME"
    wineserver_kill
    pkill -f "$APP_CONTENTS/MacOS/" 2>/dev/null || true
  fi

  if [ "$DELETE" = 1 ]; then
    rm -rf "$APP_PATH"
    ok "Deleted $APP_PATH"
  else
    TRASHED="$HOME/.Trash/$APP_NAME.app"
    [ -e "$TRASHED" ] && TRASHED="$HOME/.Trash/$APP_NAME $(date +%Y%m%d-%H%M%S).app"
    if mv "$APP_PATH" "$TRASHED" 2>/dev/null; then
      ok "Moved to the Trash. Empty the Trash to free the space."
    elif osascript -e "tell application \"Finder\" to delete (POSIX file \"$APP_PATH\" as alias)" >/dev/null 2>&1; then
      ok "Moved to the Trash. Empty the Trash to free the space."
    else
      die "Could not move it to the Trash. Drag $APP_PATH to the Trash in Finder, or re-run with --delete."
    fi
  fi
else
  warn "No app at $APP_PATH"
fi

if [ "$PURGE" = 1 ]; then
  rm -f "$SIKARUGIR_SUPPORT/Template/$TEMPLATE_NAME.tar.xz" "$SIKARUGIR_SUPPORT/Engines/$ENGINE_NAME.tar.xz"
  ok "Removed the cached template and engine archives"
fi

if [ -f "$HOME/.config/mole/whitelist" ] && grep -qF "$APP_PATH" "$HOME/.config/mole/whitelist"; then
  note "Mole still lists this app in ~/.config/mole/whitelist; you can remove those lines."
fi
