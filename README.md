# Mikro

Voice recorder for Android and Linux that turns audio recordings into text using an external OpenAI-compatible transcription API. Recordings are saved locally on the device; nothing other than audio and transcript leaves your machine.

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

Application code is owned by the author. The bundled Roboto Mono typeface (`assets/fonts/`) is licensed under the SIL Open Font License 1.1 — full text is in `assets/fonts/OFL.txt`.

