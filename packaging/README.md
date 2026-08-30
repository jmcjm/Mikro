# Pakowanie Mikro na Linuksa

Aplikacja jest dystrybuowana w dwoch formatach: **Flatpak** i **AppImage**.
Oba biora ten sam bundle Fluttera (`build/linux/x64/release/bundle`) oraz te same
metadane desktopowe z `packaging/shared/`, wiec nie da sie ich rozjechac.

## Jedna komenda na format

```sh
./packaging/build-flatpak.sh --install   # buduje i instaluje w flatpaku --user
./packaging/build-appimage.sh            # buduje build/appimage/Mikro-x86_64.AppImage
```

Dopisz `--clean`, gdy chcesz build od zera (`flutter clean`) - obowiazkowo przy
pomiarach rozmiaru bundla. Dopisz `--skip-bundle`, gdy bundle jest juz zbudowany
i chcesz tylko przepakowac.

## Uklad katalogow

| Sciezka | Co to |
| --- | --- |
| `packaging/build-bundle.sh` | wspolny krok: `flutter build linux --release` (domyslnie w devcontainerze) |
| `packaging/build-flatpak.sh` | flatpak-builder + jednoplikowy `.flatpak` |
| `packaging/build-appimage.sh` | AppDir + appimagetool |
| `packaging/shared/` | `.desktop` i AppStream metainfo - wspolne dla obu formatow |
| `packaging/icons/` | master 1024x1024 + wygenerowane 64/128/256/512 |
| `packaging/flatpak/` | manifest Flatpaka |
| `packaging/appimage/` | `AppRun` |

Artefakty lezy w `build/flatpak/` i `build/appimage/` - oba katalogi sa ignorowane
przez gita.

## Identyfikator aplikacji

Wszedzie `pl.jmc.mikro`: `APPLICATION_ID` w `linux/CMakeLists.txt`, `applicationId`
Androida, nazwy plikow `.desktop`, metainfo i ikon oraz `app-id` w manifescie
Flatpaka. Dzieki temu `app_id` okna pod Waylandem trafia w plik `.desktop`
i srodowisko pokazuje wlasciwa ikone.

## Czego aplikacja potrzebuje od systemu

- `gtk3`, `libsecret-1`, `json-glib`
- `gstreamer1` z wtyczkami base/good (odtwarzanie przez audioplayers)
- `parecord` i `pactl` (pulseaudio-utils) oraz `ffmpeg` - `record_linux` uruchamia
  je jako procesy potomne podczas nagrywania
- glibc >= 2.38 (wynika z toolchainu w devcontainerze)

Flatpak dostaje to wszystko z `org.freedesktop.Platform//25.08`. AppImage polega na
systemie uzytkownika - stad wymagania wypisane wyzej.

## Regeneracja ikon

```sh
./packaging/icons/generate-sizes.sh
```

Odpalamy tylko po podmianie mastera `packaging/icons/mikro-icon-1024.png`;
wygenerowane rozmiary sa zacommitowane, zeby build nie wymagal ImageMagicka.
