#!/bin/bash
# Show or switch the graphics backend of the wrapper.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
. "$ROOT/lib/common.sh"

usage() {
  cat <<EOF
Usage: tools/renderer.sh [status|dxmt|d3dmetal] [--name NAME] [--dir DIR]

  status     Show the current backend (default)
  dxmt       Open-source DirectX 11 → Metal. Use DirectX 11 in the launcher.
  d3dmetal   Apple's D3DMetal, DirectX 11 and 12 → Metal (Apple Silicon only).
             DirectX 12 keeps a shader cache, so less stutter after the first runs.

Changes apply the next time the app is opened.
EOF
}

ACTION="status"
while [ $# -gt 0 ]; do
  case "$1" in
    status|dxmt|d3dmetal) ACTION="$1"; shift ;;
    --name) APP_NAME="${2:?}"; shift 2 ;;
    --dir)  APP_DIR="${2:?}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (see --help)" ;;
  esac
done

set_app_paths
require_app

if [ "$ACTION" = "status" ]; then
  echo "$APP_PATH"
  echo "Graphics: $(renderer_label "$(get_renderer)")"
  exit 0
fi

set_renderer "$ACTION"
ok "Graphics set to $(renderer_label "$ACTION")"
if app_is_running; then
  warn "$APP_NAME is running. Quit it and open it again for the change to apply."
fi
if [ "$ACTION" = "dxmt" ]; then
  note "In the launcher settings, make sure DirectX 11 is selected."
fi
