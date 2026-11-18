#!/bin/bash
# Unofficial Warframe wrapper for macOS: builds Warframe.app from Sikarugir's
# template and a CrossOver-based Wine engine, then installs the official game
# launcher inside it. Not affiliated with Digital Extremes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ROOT/lib/common.sh"

usage() {
  cat <<EOF
Unofficial Warframe wrapper for macOS — installer (v$WFW_VERSION)

Usage: ./install.sh [options]

  --name NAME        App name (default: $APP_NAME → $APP_NAME.app)
  --dir DIR          Folder for the app (default: $APP_DIR)
  --msi FILE         Use a Warframe.msi you already downloaded from warframe.com
  --renderer R       Graphics backend: dxmt (default) or d3dmetal
  --skip-installer   Only build the wrapper; don't install Warframe (for testing)
  --launch           Open the app when the install finishes
  -y, --yes          Don't ask for confirmation
  -h, --help         Show this help
EOF
}

MSI_FILE=""
RENDERER="dxmt"
SKIP_INSTALLER=0
LAUNCH=0
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    --name)           APP_NAME="${2:?--name needs a value}"; shift 2 ;;
    --dir)            APP_DIR="${2:?--dir needs a value}"; shift 2 ;;
    --msi)            MSI_FILE="${2:?--msi needs a file}"; shift 2 ;;
    --renderer)       RENDERER="${2:?--renderer needs a value}"; shift 2 ;;
    --skip-installer) SKIP_INSTALLER=1; shift ;;
    --launch)         LAUNCH=1; shift ;;
    -y|--yes)         ASSUME_YES=1; shift ;;
    -h|--help)        usage; exit 0 ;;
    *)                die "Unknown option: $1 (see --help)" ;;
  esac
done

set_app_paths
case "$RENDERER" in dxmt|d3dmetal) ;; *) die "Unknown renderer '$RENDERER' (use dxmt or d3dmetal)." ;; esac
if [ -n "$MSI_FILE" ]; then
  [ -f "$MSI_FILE" ] || die "No such file: $MSI_FILE"
  MSI_FILE="$(cd "$(dirname "$MSI_FILE")" && pwd)/$(basename "$MSI_FILE")"
fi

TEMPLATE_TARBALL="$SIKARUGIR_SUPPORT/Template/$TEMPLATE_NAME.tar.xz"
ENGINE_TARBALL="$SIKARUGIR_SUPPORT/Engines/$ENGINE_NAME.tar.xz"
STEP_TOTAL=6
[ "$SKIP_INSTALLER" = 1 ] && STEP_TOTAL=5

printf '%sUnofficial Warframe wrapper for macOS%s v%s\n' "$C_BOLD" "$C_OFF" "$WFW_VERSION"
note "Not affiliated with or endorsed by Digital Extremes. Running Warframe through Wine is unsupported."

# 1 ---------------------------------------------------------------------------
step "Checking this Mac"
[ "$(uname -s)" = "Darwin" ] || die "This only runs on macOS."
OS_VERSION="$(sw_vers -productVersion)"
version_ge "$OS_VERSION" "$MIN_MACOS" || die "macOS $MIN_MACOS or later is required (this Mac has $OS_VERSION)."
ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then
  if ! /usr/bin/arch -x86_64 /usr/bin/true 2>/dev/null; then
    die "Rosetta 2 is not installed. Install it, then run this script again:
      softwareupdate --install-rosetta --agree-to-license"
  fi
else
  warn "Intel Mac: not tested yet. DXMT may work; D3DMetal does not."
  [ "$RENDERER" = "d3dmetal" ] && die "D3DMetal needs Apple Silicon."
fi
FREE="$(free_gb)"
if [ "$FREE" -lt "$MIN_FREE_GB" ]; then
  warn "Only $FREE GB free. A full Warframe download needs about $MIN_FREE_GB GB."
fi
[ ! -e "$APP_PATH" ] || die "$APP_PATH already exists. Pick another --name, or remove it first with ./uninstall.sh"
ok "macOS $OS_VERSION ($ARCH), $FREE GB free"

cat <<EOF

This will:
  • download Sikarugir's wrapper template ($TEMPLATE_NAME, ~96 MB) and the
    CrossOver-based Wine engine ($ENGINE_NAME, ~172 MB) from github.com/Sikarugir-App
  • build $APP_PATH
EOF
if [ "$SKIP_INSTALLER" = 0 ]; then
  if [ -n "$MSI_FILE" ]; then
    echo "  • install Warframe inside it from $MSI_FILE"
  else
    echo "  • download the official installer from content.warframe.com (~105 MB) and install it"
  fi
  echo "The game itself (tens of GB) is downloaded later by the official launcher."
fi
echo
confirm "Continue?" || { echo "Cancelled."; exit 0; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/wfw.XXXXXX")"
APP_CREATED=0
cleanup() {
  local rc=$?
  rm -rf "$WORK"
  if [ "$rc" -ne 0 ] && [ "$APP_CREATED" = 1 ]; then
    warn "Install did not finish. Logs: $APP_LOGS"
    warn "To remove the partial app: ./uninstall.sh --name \"$APP_NAME\" --dir \"$APP_DIR\""
  fi
}
trap cleanup EXIT

# 2 ---------------------------------------------------------------------------
step "Downloading the wrapper template and Wine engine"
download_verified "$TEMPLATE_URL" "$TEMPLATE_TARBALL" "$TEMPLATE_SHA256"
download_verified "$ENGINE_URL" "$ENGINE_TARBALL" "$ENGINE_SHA256"

# 3 ---------------------------------------------------------------------------
step "Building $APP_NAME.app"
tar -xJf "$TEMPLATE_TARBALL" -C "$WORK"
tar -xJf "$ENGINE_TARBALL" -C "$WORK"
[ -d "$WORK/$TEMPLATE_NAME.app/Contents" ] || die "Unexpected template layout in $TEMPLATE_NAME."
[ -x "$WORK/wswine.bundle/bin/wine" ] || die "Unexpected engine layout in $ENGINE_NAME."
mv "$WORK/wswine.bundle" "$WORK/$TEMPLATE_NAME.app/Contents/SharedSupport/wine"
mkdir -p "$APP_DIR"
mv "$WORK/$TEMPLATE_NAME.app" "$APP_PATH"
APP_CREATED=1
mkdir -p "$APP_LOGS"
INSTALL_LOG="$APP_LOGS/wfw-install.log"
{ echo "wfw $WFW_VERSION install on $(date)"; echo "macOS $OS_VERSION $ARCH"; } >"$INSTALL_LOG"

# CFBundleIdentifier is left alone: Sikarugir's launcher assigns its own on first run.
plist_set_string CFBundleName "$APP_NAME"
plist_set_string WFWVersion "$WFW_VERSION"
plist_set_string WFWEngine "$ENGINE_NAME"
ok "Engine: $(cat "$APP_CONTENTS/SharedSupport/wine/version" 2>/dev/null || echo "$ENGINE_NAME")"

# 4 ---------------------------------------------------------------------------
step "Creating the Windows environment (about 1–2 minutes)"
"$APP_CONTENTS/MacOS/wineskinlauncher" WSS-wineprefixcreate >>"$INSTALL_LOG" 2>&1 || true
[ -d "$PFX/drive_c/windows/system32" ] || die "Wine prefix was not created (see $INSTALL_LOG)."
ok "Prefix ready"

# 5 ---------------------------------------------------------------------------
if [ "$SKIP_INSTALLER" = 0 ]; then
  step "Installing Warframe (the launcher updates itself; a few minutes)"
  if [ -z "$MSI_FILE" ]; then
    MSI_FILE="$WORK/Warframe.msi"
    info "Downloading the official installer"
    curl -fL --retry 3 --progress-bar -o "$MSI_FILE" "$MSI_URL" || die "Could not download $MSI_URL"
  fi
  verify_msi "$MSI_FILE"
  cp "$MSI_FILE" "$PFX/drive_c/Warframe.msi"
  run_wine msiexec /i 'C:\Warframe.msi' /qn '/l*v' 'C:\warframe-msi.log' >>"$INSTALL_LOG" 2>&1 || true
  wineserver_wait >>"$INSTALL_LOG" 2>&1 || true
  rm -f "$PFX/drive_c/Warframe.msi"
  MSI_LOG="$APP_LOGS/warframe-msi.log"
  mv "$PFX/drive_c/warframe-msi.log" "$MSI_LOG" 2>/dev/null || true
  grep -aq 'INSTALL. Return value 1' "$MSI_LOG" 2>/dev/null || die "The Warframe installer did not finish (see $MSI_LOG)."
  LAUNCHER="$(find_launcher)"
  [ -n "$LAUNCHER" ] || die "Launcher.exe was not found after the install (see $MSI_LOG)."
  plist_set_string "Program Name and Path" "${LAUNCHER#"$PFX/drive_c"}"
  ok "Warframe launcher installed"
fi

# 6 ---------------------------------------------------------------------------
step "Applying settings"
set_renderer "$RENDERER"
ok "Graphics: $(renderer_label "$RENDERER")"
mole_protect

echo
printf '%sDone.%s %s\n' "$C_GRN" "$C_OFF" "$APP_PATH"
if [ "$SKIP_INSTALLER" = 0 ]; then
  cat <<EOF

Next:
  1. Open $APP_NAME.app (Finder → your home folder → Applications → Sikarugir).
  2. In the launcher, accept the default install folder and let it download the game.
  3. In the launcher settings, choose DirectX 11 when using DXMT.

Switch graphics backend:  tools/renderer.sh d3dmetal   (or dxmt)
Check progress and logs:  tools/status.sh
EOF
  [ "$LAUNCH" = 1 ] && open "$APP_PATH"
fi
exit 0
