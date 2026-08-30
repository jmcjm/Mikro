# Roboto Mono (podzbior latin + latin-ext)

Krojem monospace skladamy wartosci techniczne: adresy, nazwy modeli, znaczniki czasu i parametry
nagrania. W kodzie rodzina wystepuje tylko jako stala `monoFontFamily`
(`lib/core/theme/app_theme.dart`), deklaracja siedzi w `pubspec.yaml`.

## Licencja

SIL Open Font License 1.1 — pelny tekst w `OFL.txt`, ktory musi isc razem z fontami w kazdej
dystrybucji. Licencja nie zastrzega nazwy (brak Reserved Font Name), wiec podzbior zachowuje
oryginalna nazwe rodziny.

## Skad sie wzielo

Zrodlo: [google/fonts](https://github.com/google/fonts), katalog `ofl/robotomono`, plik zmienny
`RobotoMono[wght].ttf` (sha256 `66a80e79d17e4c7cabd162e2916578a4cc08fd19eef6e2a643305eae9c567b2b`).
Repo nie wydaje plikow statycznych, wiec font jest instancja osi `wght`, a potem podzbiorem
znakow — pelny font ma cyrylice, greke i wietnamski, ktorych aplikacja nie uzywa.

Odtworzenie (wymaga `fonttools`):

```sh
python3 -m fontTools.varLib.instancer 'RobotoMono[wght].ttf' wght=400 --update-name-table -o inst.ttf

LATIN='U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD'
LATIN_EXT='U+0100-02BA,U+02BD-02C5,U+02C7-02CC,U+02CE-02D7,U+02DD-02FF,U+1D00-1DBF,U+1E00-1E9F,U+1EF2-1EFF,U+2020,U+20A0-20AB,U+20AD-20C0,U+2113,U+2C60-2C7F,U+A720-A7FF'

python3 -m fontTools.subset inst.ttf --unicodes="$LATIN,$LATIN_EXT" \
  --name-IDs='*' --name-legacy --notdef-outline --layout-features='*' \
  --output-file=RobotoMono-Regular.ttf
```

Zakresy znakow to te same, ktorych Google Fonts uzywa dla podzbiorow `latin` i `latin-ext` —
polskie znaki diakrytyczne sa w `latin-ext`. Po podzbiorze zostaje 410 znakow zamiast pelnego
zestawu, okolo 38 KB. `--name-IDs='*'` zostawia w pliku noty o prawach autorskich i licencji.

Aplikacja bundluje wylacznie wage 400: zaden styl nie ustawia `fontWeight` na tekscie mono,
wiec waga 500 byla nieosiagalna. Gdyby kiedys byla potrzebna, powstaje ta sama recepta
z `wght=500`.
