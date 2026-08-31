#!/usr/bin/env bash
# Builds the AppImage for Mikro.
#
# Process:
#   1. Builds Flutter bundle (packaging/build-bundle.sh) unless --skip-bundle is passed.
#   2. Assembles AppDir in build/appimage/Mikro.AppDir (bundle -> usr/bin,
#      AppRun, .desktop, metainfo, hicolor icons + root icon and .DirIcon).
#   3. Packages AppDir using appimagetool into build/appimage/Mikro-<arch>.AppImage.
#
# Usage (from repository root):
#   ./packaging/build-appimage.sh [--skip-bundle] [--clean]
#
# appimagetool search order: $APPIMAGETOOL, PATH, or downloaded from GitHub
# to build/appimage/tools (git-ignored).
# Uses --appimage-extract-and-run if FUSE is unavailable.
# AppStream validation is executed beforehand with host appstreamcli, so appimagetool
# is invoked with --no-appstream.
#
# Target system dependencies (not bundled into the AppImage):
#   glibc >= 2.38, gtk3, libsecret-1, gstreamer1 with base/good plugins,
#   pulseaudio-utils (parecord, pactl), and ffmpeg.
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
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

if [ "$SKIP_BUNDLE" -eq 0 ]; then
  "$PACKAGING_DIR/build-bundle.sh" "${BUNDLE_ARGS[@]+"${BUNDLE_ARGS[@]}"}"
else
  [ -x "$BUNDLE_DIR/mikro" ] || { echo "no built bundle found - run without --skip-bundle" >&2; exit 1; }
fi

if command -v appstreamcli >/dev/null; then
  echo "==> Validating metainfo"
  appstreamcli validate --no-net "$PACKAGING_DIR/shared/$APP_ID.metainfo.xml"
fi
if command -v desktop-file-validate >/dev/null; then
  echo "==> Validating .desktop file"
  desktop-file-validate "$PACKAGING_DIR/shared/$APP_ID.desktop"
fi

echo "==> Assembling AppDir"
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

# appimagetool requires .desktop and icon in root of AppDir; .DirIcon is for file managers.
cp "$APP_DIR/usr/share/applications/$APP_ID.desktop" "$APP_DIR/$APP_ID.desktop"
cp "$APP_DIR/usr/share/icons/hicolor/256x256/apps/$APP_ID.png" "$APP_DIR/$APP_ID.png"
cp "$APP_DIR/$APP_ID.png" "$APP_DIR/.DirIcon"

appimagetool_path() {
  if [ -n "${APPIMAGETOOL:-}" ]; then echo "$APPIMAGETOOL"; return; fi
  if command -v appimagetool >/dev/null; then command -v appimagetool; return; fi
  local local_tool="$TOOLS_DIR/appimagetool-$ARCH.AppImage"
  if [ ! -x "$local_tool" ]; then
    echo "==> Downloading appimagetool to $TOOLS_DIR" >&2
    mkdir -p "$TOOLS_DIR"
    curl -fsSL -o "$local_tool" "$APPIMAGETOOL_URL"
    chmod +x "$local_tool"
  fi
  echo "$local_tool"
}

TOOL="$(appimagetool_path)"
TOOL_ARGS=()
if ! "$TOOL" --appimage-version >/dev/null 2>&1; then
  TOOL_ARGS+=(--appimage-extract-and-run)
fi

echo "==> Running appimagetool"
ARCH="$ARCH" "$TOOL" "${TOOL_ARGS[@]+"${TOOL_ARGS[@]}"}" --no-appstream "$APP_DIR" "$OUT_FILE"

echo "==> Ready: $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
