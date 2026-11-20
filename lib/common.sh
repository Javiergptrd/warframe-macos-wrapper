# shellcheck shell=bash
# Shared settings and helpers, sourced by install.sh, uninstall.sh and tools/*.sh.
# Written for the bash 3.2 that ships with macOS (no associative arrays, no mapfile).

WFW_VERSION="0.1.0-dev"

# --- Pinned upstream components ------------------------------------------------
# Downloaded from Sikarugir's official GitHub releases at install time. They are
# never redistributed by this project. Hashes match GitHub's published digests.
TEMPLATE_NAME="Template-1.0.27"
TEMPLATE_URL="https://github.com/Sikarugir-App/Template/releases/download/v1.0/${TEMPLATE_NAME}.tar.xz"
TEMPLATE_SHA256="dd0778f7b553d63df9b0f4e2cda3f3c6c005aabb75588c84d604afe80cdedbb9"

# Wine engine built from CodeWeavers' open-source CrossOver 24.0.7 tree.
ENGINE_NAME="WS12WineCX24.0.7_7"
ENGINE_URL="https://github.com/Sikarugir-App/Engines/releases/download/v1.0/${ENGINE_NAME}.tar.xz"
ENGINE_SHA256="203f9e9fd6c2cc77e6525d798a434ced326145db34a356355e05659d3445fd1c"

# Official installer from Digital Extremes. Not pinned: DE replaces it on updates,
# so it is checked by file type and author instead (see verify_msi).
MSI_URL="https://content.warframe.com/dl/Warframe.msi"

# --- Locations -----------------------------------------------------------------
# Same cache folders Sikarugir Creator uses, so both tools share downloads.
SIKARUGIR_SUPPORT="$HOME/Library/Application Support/Sikarugir"
APP_DIR="${WFW_APP_DIR:-$HOME/Applications/Sikarugir}"
APP_NAME="${WFW_APP_NAME:-Warframe}"

MIN_MACOS="14.6"   # Sikarugir template minimum
MIN_FREE_GB=60     # rough size of a full Warframe install plus headroom

# --- Output --------------------------------------------------------------------
if [ -t 1 ]; then
  C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RED=$'\033[31m'
  C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_OFF=$'\033[0m'
else
  C_BOLD=""; C_DIM=""; C_RED=""; C_GRN=""; C_YEL=""; C_OFF=""
fi

info() { printf '%s==>%s %s\n' "$C_BOLD" "$C_OFF" "$*"; }
ok()   { printf '%s ✓%s %s\n' "$C_GRN" "$C_OFF" "$*"; }
note() { printf '%s   %s%s\n' "$C_DIM" "$*" "$C_OFF"; }
warn() { printf '%s ! %s%s\n' "$C_YEL" "$*" "$C_OFF" >&2; }
die()  { printf '%s ✗ %s%s\n' "$C_RED" "$*" "$C_OFF" >&2; exit 1; }

STEP_TOTAL=0
STEP_NUM=0
step() { STEP_NUM=$((STEP_NUM + 1)); printf '\n%s[%d/%d] %s%s\n' "$C_BOLD" "$STEP_NUM" "$STEP_TOTAL" "$*" "$C_OFF"; }

# confirm "Question?" -> 0 for yes. Honors ASSUME_YES=1.
confirm() {
  [ "${ASSUME_YES:-0}" = 1 ] && return 0
  [ -t 0 ] || die "Not running in an interactive terminal; re-run with --yes to continue."
  local reply
  printf '%s [y/N] ' "$1"
  read -r reply || reply=""
  case "$reply" in y|Y|yes|YES|Yes|s|S|si|SI|Si|sí|Sí) return 0 ;; *) return 1 ;; esac
}

# --- Paths inside a wrapper ----------------------------------------------------
set_app_paths() {
  case "$APP_NAME" in ""|*/*) die "Invalid app name: '$APP_NAME'" ;; esac
  APP_PATH="$APP_DIR/$APP_NAME.app"
  APP_CONTENTS="$APP_PATH/Contents"
  APP_PLIST="$APP_CONTENTS/Info.plist"
  PFX="$APP_CONTENTS/SharedSupport/prefix"
  WINE_BIN="$APP_CONTENTS/SharedSupport/wine/bin"
  APP_LOGS="$APP_CONTENTS/SharedSupport/Logs"
}

require_app() {
  [ -f "$APP_PLIST" ] || die "No wrapper found at $APP_PATH (use --name/--dir if you installed it elsewhere)."
}

# --- Info.plist ----------------------------------------------------------------
PLISTBUDDY=/usr/libexec/PlistBuddy

plist_get() { "$PLISTBUDDY" -c "Print ':$1'" "$APP_PLIST" 2>/dev/null; }

plist_set_string() {
  "$PLISTBUDDY" -c "Set ':$1' '$2'" "$APP_PLIST" 2>/dev/null ||
    "$PLISTBUDDY" -c "Add ':$1' string '$2'" "$APP_PLIST"
}

plist_set_int() {
  "$PLISTBUDDY" -c "Set ':$1' $2" "$APP_PLIST" 2>/dev/null ||
    "$PLISTBUDDY" -c "Add ':$1' integer $2" "$APP_PLIST"
}

# --- Graphics backend ----------------------------------------------------------
# Sikarugir picks D3DMetal when D3DMETAL=1, DXVK when DXVK=1, and DXMT otherwise.
get_renderer() {
  if [ "$(plist_get D3DMETAL)" = "1" ]; then echo "d3dmetal"
  elif [ "$(plist_get DXVK)" = "1" ]; then echo "dxvk"
  else echo "dxmt"
  fi
}

set_renderer() {
  case "$1" in
    dxmt)
      plist_set_int D3DMETAL 0; plist_set_int DXVK 0 ;;
    d3dmetal)
      [ "$(uname -m)" = "arm64" ] || die "D3DMetal only works on Apple Silicon Macs."
      plist_set_int D3DMETAL 1; plist_set_int DXVK 0 ;;
    *) die "Unknown renderer '$1' (use dxmt or d3dmetal)." ;;
  esac
}

renderer_label() {
  case "$1" in
    dxmt)     echo "DXMT (open source, DirectX 11 → Metal)" ;;
    d3dmetal) echo "D3DMetal (Apple, DirectX 11/12 → Metal)" ;;
    dxvk)     echo "DXVK (DirectX 11 → Vulkan → MoltenVK)" ;;
    *)        echo "$1" ;;
  esac
}

# --- Wine ----------------------------------------------------------------------
# Running the engine directly needs the template's bundled libraries on the path.
wine_env() {
  env WINEPREFIX="$PFX" WINEDEBUG="${WINEDEBUG:--all}" \
    DYLD_FALLBACK_LIBRARY_PATH="$APP_CONTENTS/Frameworks:/usr/lib" "$@"
}
run_wine()        { wine_env "$WINE_BIN/wine" "$@"; }
wineserver_wait() { wine_env "$WINE_BIN/wineserver" -w; }

# --- Game and launcher settings --------------------------------------------------
# The launcher keeps its DirectX choice in the registry: GraphicsAPI 0 = DirectX 11,
# 1 = DirectX 12. DXMT only supports DirectX 11. D3DMetal does both; DirectX 12 was
# faster on an M4 once its shader cache was built (see docs/TESTING.md).
launcher_dx_for() {
  case "$1" in d3dmetal) echo 1 ;; *) echo 0 ;; esac
}
set_launcher_dx() {
  run_wine reg add 'HKCU\Software\Digital Extremes\Warframe\Launcher' \
    /v GraphicsAPI /t REG_DWORD /d "$1" /f >/dev/null 2>&1 || return 1
  wineserver_wait >/dev/null 2>&1 || true
}

# Exclusive fullscreen loops on DXMT and minimizes on every Cmd+Tab on D3DMetal,
# so start in borderless fullscreen. The game creates EE.cfg on its first run and
# fills in every setting not given, so only write a starter file if none exists.
preset_borderless() {
  local dir="$PFX/drive_c/users/Sikarugir/AppData/Local/Warframe"
  [ -f "$dir/EE.cfg" ] && return 0
  mkdir -p "$dir"
  printf '+nowarning\r\n+version=5\r\n\r\n[Windows_Config,/EE/Types/Base/Config]\r\nGraphics.WindowMode=MODE_BORDERLESS\r\n' >"$dir/EE.cfg"
}
wineserver_kill() { wine_env "$WINE_BIN/wineserver" -k >/dev/null 2>&1 || true; }

# Match the app's own Wine processes (wineserver runs whenever the app does), not
# any process with a path inside the app, such as tools/watch-log.sh's tail.
app_is_running() { pgrep -f "$APP_CONTENTS/SharedSupport/wine/" >/dev/null 2>&1; }

# Launcher.exe lives in the Windows user's profile; the user folder name depends
# on the engine ("crossover", renamed to "Sikarugir" by the template).
find_launcher() {
  find "$PFX/drive_c/users" -type f \
    -path '*/AppData/Local/Warframe/Downloaded/Public/Tools/Launcher.exe' 2>/dev/null | head -n 1
}

# Game content folder (whatever install folder was chosen in the launcher).
find_game_data() {
  find "$PFX/drive_c" -maxdepth 7 -type d -name 'Cache.Windows' \
    -path '*/Downloaded/Public/*' 2>/dev/null | head -n 1
}

launcher_log() {
  find "$PFX/drive_c/users" -type f -path '*/AppData/Local/Warframe/Launcher.log' 2>/dev/null | head -n 1
}

# --- Misc ----------------------------------------------------------------------
sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }

free_gb() { df -k "$HOME" | awk 'NR==2 { print int($4 / 1024 / 1024) }'; }

# version_ge A B -> 0 when A >= B (numeric, dot separated, up to 3 parts)
version_ge() {
  local IFS=.
  # shellcheck disable=SC2206
  local -a a=($1) b=($2)
  local i x y
  for i in 0 1 2; do
    x=${a[$i]:-0}; y=${b[$i]:-0}
    if ((10#$x > 10#$y)); then return 0; fi
    if ((10#$x < 10#$y)); then return 1; fi
  done
  return 0
}

# download_verified URL DEST SHA256 (reuses DEST when it already matches)
download_verified() {
  local url=$1 dest=$2 sha=$3 name
  name=$(basename "$dest")
  if [ -f "$dest" ] && [ "$(sha256_of "$dest")" = "$sha" ]; then
    ok "$name (already downloaded)"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  info "Downloading $name"
  curl -fL --retry 3 --progress-bar -o "$dest.part" "$url" || { rm -f "$dest.part"; die "Download failed: $url"; }
  if [ "$(sha256_of "$dest.part")" != "$sha" ]; then
    rm -f "$dest.part"
    die "Checksum mismatch for $name. Upstream may have changed; please open an issue."
  fi
  mv "$dest.part" "$dest"
  ok "$name"
}

# The official MSI is checked by type and author because its hash changes.
verify_msi() {
  local desc
  desc=$(file -b "$1")
  case "$desc" in *"MSI Installer"*) ;; *) die "$1 is not a Windows Installer (.msi) file." ;; esac
  case "$desc" in *"Author: Digital Extremes"*) ;; *) die "$1 does not look like the official Warframe installer." ;; esac
}

# Paths Mole (https://mole.fit) must never clean while the wrapper is in use.
mole_patterns() {
  printf '%s\n' \
    "$APP_PATH" \
    "$APP_PATH/*" \
    "$SIKARUGIR_SUPPORT*" \
    "/private/var/folders/*/*/T/winetemp-*" \
    "/var/folders/*/*/T/winetemp-*" \
    "/private/var/folders/*/*/T/.wine-*" \
    "/var/folders/*/*/T/.wine-*" \
    "/private/tmp/.wine-*" \
    "/tmp/.wine-*"
}

# Adds the patterns to an existing Mole whitelist. Creating the file from scratch
# would replace Mole's built-in protections, so in that case we only explain.
mole_protect() {
  local wl="$HOME/.config/mole/whitelist" line added=0
  if [ -f "$wl" ]; then
    while IFS= read -r line; do
      if ! grep -qxF "$line" "$wl"; then
        [ "$added" = 0 ] && printf '\n# Unofficial Warframe wrapper (%s)\n' "$APP_NAME" >>"$wl"
        printf '%s\n' "$line" >>"$wl"
        added=$((added + 1))
      fi
    done < <(mole_patterns)
    if [ "$added" -gt 0 ]; then ok "Mole: protected the wrapper in $wl"; else ok "Mole: wrapper already protected"; fi
  elif command -v mo >/dev/null 2>&1; then
    warn "Mole is installed but has no custom whitelist. Run 'mo clean --whitelist' and add:"
    mole_patterns | sed 's/^/      /' >&2
  fi
}
