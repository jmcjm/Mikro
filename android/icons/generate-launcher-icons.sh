#!/usr/bin/env bash
# Generuje ikony launchera Androida z masterow 1024x1024. Wyniki sa zacommitowane w repo,
# wiec ten skrypt odpalamy tylko po podmianie mastera.
#
# Master kwadratowy jest wspolny z pakowaniem na Linuksa (packaging/icons/mikro-icon-1024.png),
# master okragly lezy obok tego skryptu, bo poza Androidem nikt go nie uzywa.
#
# Powstaja trzy rzeczy:
#   1. mipmap-{mdpi..xxxhdpi}/ic_launcher.png       — ikona legacy (Android < 8), z mastera kwadratowego
#   2. mipmap-{mdpi..xxxhdpi}/ic_launcher_round.png — wariant okragly dla launcherow, ktore o niego prosza
#   3. mipmap-xxxhdpi/ic_launcher_{background,foreground,monochrome}.png — warstwy adaptive icon (108dp
#      przy gestosci xxxhdpi to 432 px; nizsze gestosci system przeskaluje sam)
#
# Warstwa foreground powstaje z mastera odwrotnym alpha blendingiem: znak jest bialy nad jednolitym
# tlem #65558F, wiec z kanalu zielonego (tlo 85, znak 255) wyliczamy krycie i nakladamy je jako alfe
# na bialy obraz. Poziomy szarosci slupkow z makiety zostaja zachowane jako czesciowa alfa.
#
# Wymaga: ImageMagick (magick).
set -euo pipefail

ICON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RES_DIR="$ICON_DIR/../app/src/main/res"
SQUARE="$ICON_DIR/../../packaging/icons/mikro-icon-1024.png"
ROUND="$ICON_DIR/mikro-icon-round-1024.png"

# Tlo znaku w masterze i zarazem tlo adaptive icon.
BG='#65558F'
# Kanal zielony tla: 85/255 = 33.3333%. Ten prog zamienia jasnosc na alfe.
BG_GREEN_PCT='33.3333%'
# Adaptive icon: plotno 432 px, strefa bezpieczna to centralne 66%, czyli 264 px.
CANVAS=432
SAFE=264

# Gestosc -> bok ikony legacy w px.
DENSITIES=(mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192)

command -v magick >/dev/null || { echo "brak ImageMagick (magick)" >&2; exit 1; }
for master in "$SQUARE" "$ROUND"; do
  [ -f "$master" ] || { echo "brak mastera: $master" >&2; exit 1; }
done

for entry in "${DENSITIES[@]}"; do
  density="${entry%%:*}"
  size="${entry##*:}"
  mkdir -p "$RES_DIR/mipmap-$density"
  magick "$SQUARE" -resize "${size}x${size}" -strip "$RES_DIR/mipmap-$density/ic_launcher.png"
  magick "$ROUND" -resize "${size}x${size}" -strip "$RES_DIR/mipmap-$density/ic_launcher_round.png"
  echo "  mipmap-$density: ic_launcher.png + ic_launcher_round.png (${size}px)"
done

adaptive="$RES_DIR/mipmap-xxxhdpi"
magick -size "${CANVAS}x${CANVAS}" "canvas:$BG" -strip "$adaptive/ic_launcher_background.png"
echo "  mipmap-xxxhdpi/ic_launcher_background.png (${CANVAS}px, $BG)"

# Cala geometria (przyciecie do znaku, skalowanie do strefy bezpiecznej, wysrodkowanie na plotnie)
# dzieje sie na masce w skali szarosci, a alfa doklejana jest dopiero na koncu. Odwrotna kolejnosc
# ImageMagick psuje: obraz "bialy + alfa" klasyfikuje jako bilevel i przy -extent gubi biel.
mask="$(mktemp --suffix=.png)"
trap 'rm -f "$mask"' EXIT
# -fuzz przy przycinaniu, bo ImageMagick liczy -level w zmiennoprzecinkowym Q16-HDRI i tlo wychodzi
# wlos powyzej zera; bez tolerancji -trim nie znajduje jednolitej ramki i nie przycina nic.
magick "$SQUARE" -background "$BG" -alpha remove -alpha off \
  -channel G -separate +channel -level "$BG_GREEN_PCT,100%" \
  -fuzz 1% -trim +repage -resize "${SAFE}x${SAFE}" \
  -background black -gravity center -extent "${CANVAS}x${CANVAS}" -depth 8 "$mask"
magick -size "${CANVAS}x${CANVAS}" xc:white "$mask" -alpha off -compose CopyOpacity -composite \
  -define png:color-type=6 -strip "$adaptive/ic_launcher_foreground.png"
echo "  mipmap-xxxhdpi/ic_launcher_foreground.png (${CANVAS}px, znak <= ${SAFE}px)"

# Themed icon (Android 13+) dostaje ten sam ksztalt — system i tak barwi go po alfie.
cp "$adaptive/ic_launcher_foreground.png" "$adaptive/ic_launcher_monochrome.png"
echo "  mipmap-xxxhdpi/ic_launcher_monochrome.png (kopia foreground)"
