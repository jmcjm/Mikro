#!/usr/bin/env bash
# Buduje pakiet Flatpak aplikacji Mikro.
#
# Co robi:
#   1. buduje bundla Fluttera (packaging/build-bundle.sh), chyba ze --skip-bundle,
#   2. waliduje metainfo i plik .desktop, jesli narzedzia sa dostepne,
#   3. uruchamia flatpak-builder na packaging/flatpak/pl.jmc.mikro.yml
#      (katalog roboczy i repozytorium OSTree laduja w build/flatpak/),
#   4. sklada jednoplikowy build/flatpak/pl.jmc.mikro.flatpak,
#   5. z opcja --install instaluje pakiet w instalacji uzytkownika (--user).
#
# Uzycie (z katalogu glownego repo):
#   ./packaging/build-flatpak.sh [--skip-bundle] [--clean] [--install]
#
# Wymaga: flatpak, flatpak-builder oraz runtime'u org.freedesktop.Platform//25.08
# i org.freedesktop.Sdk//25.08 (skrypt sprawdza obecnosc i podpowiada komende).
# Idempotentny: flatpak-builder dostaje --force-clean, a repozytorium OSTree
# przyjmuje kolejne commity bez konfliktow.
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
    *) echo "nieznana opcja: $arg" >&2; exit 2 ;;
  esac
done

command -v flatpak >/dev/null || { echo "brak flatpaka" >&2; exit 1; }
command -v flatpak-builder >/dev/null || { echo "brak flatpak-buildera" >&2; exit 1; }

for rt in "org.freedesktop.Platform//$RUNTIME_VERSION" "org.freedesktop.Sdk//$RUNTIME_VERSION"; do
  if ! flatpak info "$rt" >/dev/null 2>&1; then
    echo "brak runtime'u $rt" >&2
    echo "zainstaluj: flatpak install --user flathub $rt" >&2
    exit 1
  fi
done

if [ "$SKIP_BUNDLE" -eq 0 ]; then
  "$PACKAGING_DIR/build-bundle.sh" "${BUNDLE_ARGS[@]+"${BUNDLE_ARGS[@]}"}"
else
  [ -x "$REPO_ROOT/build/linux/x64/release/bundle/mikro" ] || {
    echo "brak zbudowanego bundla - odpal bez --skip-bundle" >&2; exit 1; }
fi

# Walidacja metadanych jest opcjonalna: appstreamcli chodzi po sieci, wiec
# --no-net trzyma wynik deterministycznym niezaleznie od stanu lacza.
if command -v appstreamcli >/dev/null; then
  echo "==> walidacja metainfo"
  appstreamcli validate --no-net "$PACKAGING_DIR/shared/$APP_ID.metainfo.xml"
fi
if command -v desktop-file-validate >/dev/null; then
  echo "==> walidacja pliku .desktop"
  desktop-file-validate "$PACKAGING_DIR/shared/$APP_ID.desktop"
fi

echo "==> flatpak-builder"
mkdir -p "$OUT_DIR"
# --state-dir trzyma cache buildera pod build/, zamiast smiecic .flatpak-builder
# w katalogu glownym repozytorium.
flatpak-builder --user --force-clean --state-dir="$STATE_DIR" \
  --repo="$OSTREE_REPO" "$BUILD_DIR" "$MANIFEST"

echo "==> sklejanie pakietu jednoplikowego"
rm -f "$BUNDLE_FILE"
flatpak build-bundle "$OSTREE_REPO" "$BUNDLE_FILE" "$APP_ID" master

if [ "$INSTALL" -eq 1 ]; then
  echo "==> instalacja --user"
  flatpak install --user --noninteractive --reinstall "$BUNDLE_FILE"
  echo "uruchom: flatpak run $APP_ID"
fi

echo "==> gotowe: $BUNDLE_FILE ($(du -h "$BUNDLE_FILE" | cut -f1))"
