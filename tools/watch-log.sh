#!/bin/bash
# Follow Warframe's EE.log live while playing, showing only lines useful for
# tuning the wrapper: graphics, settings changes, warnings, errors and stalls.
# Known high-volume noise from the game itself is hidden unless --all is given.
#
# The game overwrites EE.log every time it starts, so the full, unfiltered log
# is also saved to Contents/SharedSupport/Logs/EE-<date>-<time>.log for as long
# as this runs (one file per run, game restarts included). The newest
# KEEP_SAVED files are kept.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT/lib/common.sh"

ALL=0
SAVE=1
KEEP_SAVED=10
usage() {
  cat <<EOF
Usage: tools/watch-log.sh [--name NAME] [--dir DIR] [--all] [--no-save]

  --all      show every line instead of the filtered view
  --no-save  do not save a copy of the full log
EOF
}
while [ $# -gt 0 ]; do
  case "$1" in
    --name)    APP_NAME="${2:?}"; shift 2 ;;
    --dir)     APP_DIR="${2:?}"; shift 2 ;;
    --all)     ALL=1; shift ;;
    --no-save) SAVE=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
done

set_app_paths
require_app

LOG="$PFX/drive_c/users/Sikarugir/AppData/Local/Warframe/EE.log"
[ -f "$LOG" ] || die "No game log yet: $LOG (start the game first)"

# What to show: graphics lines, settings dumps, warnings/errors, timing/IO stats,
# and the marker tail prints when the game restarts and truncates the log.
KEEP=' Gfx \[|\[(Warning|Error)\]|VSync=|Resolution=|Quality=|UpscalingMethod|took [0-9.]+s|Seeked:|Wasted:|Idle IO|hitch|stall|timeout|file truncated'
# Game-side noise that says nothing about the wrapper: missing or broken game
# assets, data-format messages and routine resource creation.
NOISE='no local player avatar|Unknown property:|Could not (find|use|choose)|Required by |Failed to create run-time type|had problems with its property text|Error parsing|Broken resources detected|Check the Instance\(\) argument|expected to run on .* but no instance found|Artifact with no item compat|does not map to a valid category|is missing a MMMT_|Invalid item ID for loadout|No items in inventory list|Creating (render target|a structured buffer|dynamic)|skin ramp|Invalid blend mask|Connectivity trim|SetCallbacks on unknown clip|Ignoring duplicate property|add_frame_name|Ignoring dep to transient type|Animation channel .* does not map|had a NULL reward entry'

save_to() {
  if [ "$SAVE" = 1 ]; then tee -a "$1"; else cat; fi
}

OUT=/dev/null
if [ "$SAVE" = 1 ]; then
  mkdir -p "$APP_LOGS"
  OUT="$APP_LOGS/EE-$(date +%Y%m%d-%H%M%S).log"
  # Keep only the newest saved logs; this run's file is created below.
  # shellcheck disable=SC2012
  { ls -t "$APP_LOGS"/EE-*.log 2>/dev/null || true; } | tail -n +"$KEEP_SAVED" |
    while IFS= read -r old; do rm -f "$old"; done
  : >"$OUT"
fi

echo "${C_BOLD}Following $LOG${C_OFF} (Ctrl-C to stop)"
[ "$SAVE" = 1 ] && echo "Saving the full log to $OUT"

# Start from the beginning of the current log so the saved copy is complete,
# but only show new lines on screen.
SKIP=$(wc -l <"$LOG" | tr -d ' ')
tail -n +1 -F "$LOG" 2>&1 | save_to "$OUT" |
  awk -v skip="$SKIP" 'NR > skip { print; fflush() }' |
  if [ "$ALL" = 1 ]; then cat; else
  grep --line-buffered -E "$KEEP" | grep --line-buffered -vE "$NOISE"
fi
