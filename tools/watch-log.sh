#!/bin/bash
# Follow Warframe's EE.log live while playing, showing only lines useful for
# tuning the wrapper: graphics, settings changes, warnings, errors and stalls.
# Known high-volume noise from the game itself is hidden unless --all is given.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT/lib/common.sh"

ALL=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) APP_NAME="${2:?}"; shift 2 ;;
    --dir)  APP_DIR="${2:?}"; shift 2 ;;
    --all)  ALL=1; shift ;;
    -h|--help) echo "Usage: tools/watch-log.sh [--name NAME] [--dir DIR] [--all]"; exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
done

set_app_paths
require_app

LOG="$PFX/drive_c/users/Sikarugir/AppData/Local/Warframe/EE.log"
[ -f "$LOG" ] || die "No game log yet: $LOG (start the game first)"

# What to show: graphics lines, settings dumps, warnings/errors, timing/IO stats.
KEEP=' Gfx \[|\[(Warning|Error)\]|VSync=|Resolution=|Quality=|UpscalingMethod|took [0-9.]+s|Seeked:|Wasted:|Idle IO|hitch|stall|timeout'
# Game-side noise that says nothing about the wrapper.
NOISE='no local player avatar|Unknown property:|Could not find (object|particle|recipe)|Required by |Invalid item ID for loadout|No items in inventory list|Creating render target|SetCallbacks on unknown clip|Ignoring duplicate property|add_frame_name'

echo "${C_BOLD}Following $LOG${C_OFF} (Ctrl-C to stop)"
if [ "$ALL" = 1 ]; then
  exec tail -n 0 -F "$LOG"
fi
tail -n 0 -F "$LOG" | grep --line-buffered -E "$KEEP" | grep --line-buffered -vE "$NOISE"
