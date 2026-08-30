#!/usr/bin/env bash
# Generuje ikony w rozmiarach wymaganych przez Flatpaka i AppImage'a z mastera
# packaging/icons/mikro-icon-1024.png. Wyniki sa zacommitowane w repo, wiec ten
# skrypt odpalamy tylko po podmianie mastera.
#
# Wymaga: ImageMagick (magick).
set -euo pipefail

ICON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MASTER="$ICON_DIR/mikro-icon-1024.png"
APP_ID="pl.jmc.mikro"
SIZES=(64 128 256 512)

command -v magick >/dev/null || { echo "brak ImageMagick (magick)" >&2; exit 1; }

for size in "${SIZES[@]}"; do
  out="$ICON_DIR/hicolor/${size}x${size}/apps/${APP_ID}.png"
  mkdir -p "$(dirname "$out")"
  magick "$MASTER" -resize "${size}x${size}" -strip "$out"
  echo "  $out"
done
