# Linux Packaging for Mikro

The application is distributed in two Linux formats: **Flatpak** and **AppImage**.
Both consume the exact same Flutter bundle (`build/linux/x64/release/bundle`) and identical desktop metadata from `packaging/shared/`.

## One Command Per Format

```sh
./packaging/build-flatpak.sh --install   # builds and installs to flatpak --user
./packaging/build-appimage.sh            # builds build/appimage/Mikro-x86_64.AppImage
```

Append `--clean` for a clean build (`flutter clean`). Append `--skip-bundle` when the Flutter bundle is already built and you only want to re-package.

## Directory Structure

| Path | Description |
| --- | --- |
| `packaging/build-bundle.sh` | Shared build step: `flutter build linux --release` (runs in devcontainer by default) |
| `packaging/build-flatpak.sh` | `flatpak-builder` + single-file `.flatpak` bundle |
| `packaging/build-appimage.sh` | AppDir assembly + `appimagetool` packaging |
| `packaging/shared/` | `.desktop` and AppStream metainfo shared by both formats |
| `packaging/icons/` | Master 1024x1024 icon + pre-generated 64/128/256/512 sizes |
| `packaging/flatpak/` | Flatpak manifest (`pl.jmc.mikro.yml`) |
| `packaging/appimage/` | AppImage entrypoint script (`AppRun`) |

Built artifacts are output to `build/flatpak/` and `build/appimage/` (both git-ignored).

## Application ID

Consistent `pl.jmc.mikro` identifier across all platforms: `APPLICATION_ID` in `linux/CMakeLists.txt`, `applicationId` in Android, `.desktop` file names, metainfo, icon names, and the Flatpak `app-id`. This guarantees proper Wayland window `app_id` mapping and system icon presentation.

## System Dependencies

- `gtk3`, `libsecret-1`, `json-glib`
- `gstreamer1` with base/good plugins (audio playback via audioplayers)
- `parecord` and `pactl` (`pulseaudio-utils`), plus `ffmpeg` (spawned during microphone recording)
- `glibc >= 2.38` (determined by the devcontainer toolchain)

Flatpak bundles all of these from `org.freedesktop.Platform//25.08`. AppImage relies on the host system dependencies.

## Icon Regeneration

```sh
./packaging/icons/generate-sizes.sh
```

Run only after modifying the master icon `packaging/icons/mikro-icon-1024.png`. Pre-generated sizes are committed to the repository so standard builds do not require ImageMagick.

