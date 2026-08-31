<p align="center">
  <img src="packaging/icons/mikro-icon-1024.png" width="128" height="128" alt="Mikro Logo">
</p>

<h1 align="center">Mikro</h1>

<p align="center">
  <b>Modern voice recorder & AI-powered transcription app for Android and Linux desktop.</b>
</p>

<p align="center">
  Voice recorder for Android and Linux that turns audio recordings into text using OpenAI-compatible transcription and completion APIs. Recordings and data stay local on your device.
</p>

## Screenshots

### Mobile (Android)

<p align="center">
  <img src="docs/screenshots/mobile_home.png" width="22%" alt="Recorder Idle">
  <img src="docs/screenshots/mobile_home_recording.png" width="22%" alt="Recording in Progress">
  <img src="docs/screenshots/mobile_library.png" width="22%" alt="Library">
  <img src="docs/screenshots/mobile_recording_page.png" width="22%" alt="Recording Detail">
</p>

<p align="center">
  <img src="docs/screenshots/mobile_setting.png" width="30%" alt="Settings">
</p>

### Desktop (Linux)

<p align="center">
  <img src="docs/screenshots/pc_home.png" width="48%" alt="Desktop Recorder">
  <img src="docs/screenshots/pc_library.png" width="48%" alt="Desktop Library and Detail Panel">
</p>

## Features

- Microphone recording with live audio level visualization and amplitude waveform capture
- Automatic background transcription immediately after recording completes
- AI-generated title and tags extracted from the transcript using LLM completion
- Recordings library with playback, fuzzy search, and tag filtering
- Manual tag editing and management in recording details
- Offline queue: recordings paused on network errors automatically resume when connectivity returns; auth and rate-limit errors are not retried endlessly
- Multilingual interface (English and Polish), light/dark themes, and Material 3 Expressive design
- Secure API key storage (Android Keystore / Linux Secret Service / libsecret)

## Building

The full toolchain is set up in the devcontainer (`.devcontainer/`) — Flutter, Android SDK, and Linux native libraries are preconfigured. Open the container in any devcontainer-compatible editor or via CLI:

```sh
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . flutter test
devcontainer exec --workspace-folder . flutter build linux --release
devcontainer exec --workspace-folder . flutter build apk --release
```

Desktop Linux packages are built using the scripts in `packaging/` — both use the same Flutter bundle and shared metadata:

```sh
./packaging/build-flatpak.sh --install
./packaging/build-appimage.sh
```

For packaging details, dependencies, and layout, see [`packaging/README.md`](packaging/README.md).

## CI / CD

Automated builds and GitHub Releases are configured via [GitHub Actions](.github/workflows/build.yml). Pushing a version tag (e.g. `1.0` or `v1.0`) automatically builds and publishes the Android APK, Linux AppImage, and Linux Flatpak packages.

## License

This project is licensed under the [BSD Zero Clause License (0BSD)](LICENSE).

The bundled Roboto Mono typeface (`assets/fonts/`) is licensed under the SIL Open Font License 1.1 — full text is in `assets/fonts/OFL.txt`.

