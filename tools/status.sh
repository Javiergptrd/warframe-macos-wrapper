#!/bin/bash
# Show the state of the wrapper: engine, graphics, processes, download size and logs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT/lib/common.sh"

LINES=8
while [ $# -gt 0 ]; do
  case "$1" in
    --name)  APP_NAME="${2:?}"; shift 2 ;;
    --dir)   APP_DIR="${2:?}"; shift 2 ;;
    --lines) LINES="${2:?}"; shift 2 ;;
    -h|--help) echo "Usage: tools/status.sh [--name NAME] [--dir DIR] [--lines N]"; exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
done

set_app_paths
require_app

row() { printf '  %-14s %s\n' "$1" "$2"; }

echo "${C_BOLD}$APP_PATH${C_OFF}"
row "Wrapper" "$(plist_get WFWVersion || echo 'not created by install.sh')"
row "Engine" "$(cat "$APP_CONTENTS/SharedSupport/wine/version" 2>/dev/null || echo unknown)"
row "Graphics" "$(renderer_label "$(get_renderer)")"
row "Program" "$(plist_get 'Program Name and Path' || echo '?')"

if app_is_running; then
  row "Running" "yes"
else
  row "Running" "no"
fi

DATA="$(find_game_data)"
if [ -n "$DATA" ]; then
  row "Game data" "$(du -sh "$DATA" 2>/dev/null | cut -f1)  (${DATA#"$PFX/"})"
else
  row "Game data" "not downloaded yet"
fi
row "App size" "$(du -sh "$APP_PATH" 2>/dev/null | cut -f1)"
row "Free disk" "$(free_gb) GB"

LOG="$(launcher_log)"
if [ -n "$LOG" ]; then
  echo
  echo "${C_BOLD}Launcher.log${C_OFF} (last $LINES lines)"
  tail -n "$LINES" "$LOG" | cut -c1-160 | sed 's/^/  /'
fi
