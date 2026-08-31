#!/usr/bin/env bash
# Builds the Flatpak package for Mikro.
#
# Process:
#   1. Builds Flutter bundle (packaging/build-bundle.sh) unless --skip-bundle is passed.
#   2. Validates metainfo and .desktop file if validation tools are available.
#   3. Runs flatpak-builder using packaging/flatpak/pl.jmc.mikro.yml
#      (workdir and OSTree repo located under build/flatpak/).
#   4. Assembles single-file build/flatpak/pl.jmc.mikro.flatpak bundle.
#   5. With --install, installs the bundle into the current user's flatpak environment.
#
# Usage (from repository root):
#   ./packaging/build-flatpak.sh [--skip-bundle] [--clean] [--install]
#
# Requires: flatpak, flatpak-builder, and runtimes org.freedesktop.Platform//25.08
# and org.freedesktop.Sdk//25.08.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGING_DIR="$REPO_ROOT/packaging"
MANIFEST="$PACKAGING_DIR/flatpak/pl.jmc.mikro.yml"
APP_ID="pl.jmc.mikro"
RUNTIME_VERSION="25.08"
OUT_DIR="$REPO_ROOT/build/flatpak"
BUILD_DIR="$OUT_DIR/build"
OSTREE_REPO="$OUT_DIR/repo"
STATE_DIR="$OUT_DIR/state"
BUNDLE_FILE="$OUT_DIR/$APP_ID.flatpak"

SKIP_BUNDLE=0
INSTALL=0
BUNDLE_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --skip-bundle) SKIP_BUNDLE=1 ;;
    --clean) BUNDLE_ARGS+=(--clean) ;;
    --install) INSTALL=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

command -v flatpak >/dev/null || { echo "flatpak not found" >&2; exit 1; }
command -v flatpak-builder >/dev/null || { echo "flatpak-builder not found" >&2; exit 1; }

for rt in "org.freedesktop.Platform//$RUNTIME_VERSION" "org.freedesktop.Sdk//$RUNTIME_VERSION"; do
  if ! flatpak info "$rt" >/dev/null 2>&1; then
    echo "missing runtime: $rt" >&2
    echo "install with: flatpak install --user flathub $rt" >&2
    exit 1
  fi
done

if [ "$SKIP_BUNDLE" -eq 0 ]; then
  "$PACKAGING_DIR/build-bundle.sh" "${BUNDLE_ARGS[@]+"${BUNDLE_ARGS[@]}"}"
else
  [ -x "$REPO_ROOT/build/linux/x64/release/bundle/mikro" ] || {
    echo "no built bundle found - run without --skip-bundle" >&2; exit 1; }
fi

if command -v appstreamcli >/dev/null; then
  echo "==> Validating metainfo"
  appstreamcli validate --no-net "$PACKAGING_DIR/shared/$APP_ID.metainfo.xml"
fi
if command -v desktop-file-validate >/dev/null; then
  echo "==> Validating .desktop file"
  desktop-file-validate "$PACKAGING_DIR/shared/$APP_ID.desktop"
fi

echo "==> Running flatpak-builder"
mkdir -p "$OUT_DIR"
flatpak-builder --user --force-clean --state-dir="$STATE_DIR" \
  --repo="$OSTREE_REPO" "$BUILD_DIR" "$MANIFEST"

echo "==> Building single-file bundle"
rm -f "$BUNDLE_FILE"
flatpak build-bundle "$OSTREE_REPO" "$BUNDLE_FILE" "$APP_ID" master

if [ "$INSTALL" -eq 1 ]; then
  echo "==> Installing bundle (--user)"
  flatpak install --user --noninteractive --reinstall "$BUNDLE_FILE"
  echo "Run with: flatpak run $APP_ID"
fi

echo "==> Ready: $BUNDLE_FILE ($(du -h "$BUNDLE_FILE" | cut -f1))"
