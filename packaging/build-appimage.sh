#!/usr/bin/env bash
# Buduje AppImage'a aplikacji Mikro.
#
# Co robi:
#   1. buduje bundla Fluttera (packaging/build-bundle.sh), chyba ze --skip-bundle,
#   2. sklada od zera AppDira w build/appimage/Mikro.AppDir (bundle -> usr/bin,
#      AppRun, plik .desktop, metainfo, ikony hicolor + ikona i .DirIcon w korzeniu),
#   3. pakuje AppDira appimagetoolem do build/appimage/Mikro-<arch>.AppImage.
#
# Uzycie (z katalogu glownego repo):
#   ./packaging/build-appimage.sh [--skip-bundle] [--clean]
#
# appimagetool jest szukany w tej kolejnosci: $APPIMAGETOOL, PATH, a na koncu
# pobierany z GitHuba do build/appimage/tools (katalog jest ignorowany przez gita).
# Gdy FUSE nie dziala, appimagetool jest uruchamiany z --appimage-extract-and-run.
# Walidacje AppStreama robimy sami (host ma nowsze appstreamcli niz appimagetool),
# dlatego appimagetool dostaje --no-appstream.
# Idempotentny: AppDir i plik wyjsciowy sa kasowane na starcie.
#
# Zaleznosci systemu docelowego (NIE sa pakowane do AppImage'a):
#   glibc >= 2.38, gtk3, libsecret-1, gstreamer1 z wtyczkami base/good,
#   pulseaudio-utils (parecord, pactl) oraz ffmpeg - dwa ostatnie sa uruchamiane
#   jako procesy potomne przez record_linux podczas nagrywania.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGING_DIR="$REPO_ROOT/packaging"
APP_ID="pl.jmc.mikro"
ARCH="${ARCH:-$(uname -m)}"
OUT_DIR="$REPO_ROOT/build/appimage"
APP_DIR="$OUT_DIR/Mikro.AppDir"
TOOLS_DIR="$OUT_DIR/tools"
OUT_FILE="$OUT_DIR/Mikro-$ARCH.AppImage"
BUNDLE_DIR="$REPO_ROOT/build/linux/x64/release/bundle"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"

SKIP_BUNDLE=0
BUNDLE_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --skip-bundle) SKIP_BUNDLE=1 ;;
    --clean) BUNDLE_ARGS+=(--clean) ;;
    *) echo "nieznana opcja: $arg" >&2; exit 2 ;;
  esac
done

if [ "$SKIP_BUNDLE" -eq 0 ]; then
  "$PACKAGING_DIR/build-bundle.sh" "${BUNDLE_ARGS[@]+"${BUNDLE_ARGS[@]}"}"
else
  [ -x "$BUNDLE_DIR/mikro" ] || { echo "brak zbudowanego bundla - odpal bez --skip-bundle" >&2; exit 1; }
fi

if command -v appstreamcli >/dev/null; then
  echo "==> walidacja metainfo"
  appstreamcli validate --no-net "$PACKAGING_DIR/shared/$APP_ID.metainfo.xml"
fi
if command -v desktop-file-validate >/dev/null; then
  echo "==> walidacja pliku .desktop"
  desktop-file-validate "$PACKAGING_DIR/shared/$APP_ID.desktop"
fi

echo "==> skladanie AppDira"
rm -rf "$APP_DIR" "$OUT_FILE"
mkdir -p "$APP_DIR/usr/bin"
cp -a "$BUNDLE_DIR/." "$APP_DIR/usr/bin/"

install -Dm755 "$PACKAGING_DIR/appimage/AppRun" "$APP_DIR/AppRun"
install -Dm644 "$PACKAGING_DIR/shared/$APP_ID.desktop" "$APP_DIR/usr/share/applications/$APP_ID.desktop"
install -Dm644 "$PACKAGING_DIR/shared/$APP_ID.metainfo.xml" "$APP_DIR/usr/share/metainfo/$APP_ID.metainfo.xml"
for size in 64 128 256 512; do
  install -Dm644 "$PACKAGING_DIR/icons/hicolor/${size}x${size}/apps/$APP_ID.png" \
    "$APP_DIR/usr/share/icons/hicolor/${size}x${size}/apps/$APP_ID.png"
done

# appimagetool wymaga pliku .desktop i ikony w korzeniu AppDira; .DirIcon jest
# ikona pokazywana przez menedzery plikow.
cp "$APP_DIR/usr/share/applications/$APP_ID.desktop" "$APP_DIR/$APP_ID.desktop"
cp "$APP_DIR/usr/share/icons/hicolor/256x256/apps/$APP_ID.png" "$APP_DIR/$APP_ID.png"
cp "$APP_DIR/$APP_ID.png" "$APP_DIR/.DirIcon"

appimagetool_path() {
  if [ -n "${APPIMAGETOOL:-}" ]; then echo "$APPIMAGETOOL"; return; fi
  if command -v appimagetool >/dev/null; then command -v appimagetool; return; fi
  local local_tool="$TOOLS_DIR/appimagetool-$ARCH.AppImage"
  if [ ! -x "$local_tool" ]; then
    echo "==> pobieram appimagetool do $TOOLS_DIR" >&2
    mkdir -p "$TOOLS_DIR"
    curl -fsSL -o "$local_tool" "$APPIMAGETOOL_URL"
    chmod +x "$local_tool"
  fi
  echo "$local_tool"
}

TOOL="$(appimagetool_path)"
# Sonda: gdy FUSE nie dziala, appimagetool nie wystartuje bez rozpakowania.
TOOL_ARGS=()
if ! "$TOOL" --appimage-version >/dev/null 2>&1; then
  TOOL_ARGS+=(--appimage-extract-and-run)
fi

echo "==> appimagetool"
ARCH="$ARCH" "$TOOL" "${TOOL_ARGS[@]+"${TOOL_ARGS[@]}"}" --no-appstream "$APP_DIR" "$OUT_FILE"

echo "==> gotowe: $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
