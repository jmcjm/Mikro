<h1>
  <img src="packaging/icons/mikro-icon-1024.png" width="64" height="64" alt="Mikro Logo"
       align="absmiddle">
  Mikro
</h1>

<p>
  <b>Modern voice recorder & AI-powered transcription app for Android and Linux desktop.</b>
</p>

<p>
  Voice recorder for Android and Linux that turns audio recordings into text using OpenAI-compatible transcription and completion APIs. Recordings and data stay local on your device.
</p>

## Download

[<img src="docs/badges/badge_obtainium.png" alt="Get it on Obtainium" height="80px" align="center">](https://apps.obtainium.imranr.dev/redirect?r=obtainium://app/%7B%22id%22%3A%22pl.jmc.mikro%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Fjmcjm%2Fmikro%22%2C%22author%22%3A%22jmcjm%22%2C%22name%22%3A%22Mikro%22%7D)
[<img src="docs/badges/get-it-on-github.png" alt="Get it on GitHub" height="80px" align="center">](https://github.com/jmcjm/mikro/releases/latest)

## Screenshots

### Mobile (Android)

<p align="center">
  <img src="docs/screenshots/mobile_home_recording.png" width="22%" alt="Recording in Progress">
  <img src="docs/screenshots/mobile_library.png" width="22%" alt="Library">
  <img src="docs/screenshots/mobile_recording_page.png" width="22%" alt="Recording Detail">
  <img src="docs/screenshots/mobile_setting.png" width="22%" alt="Settings">
</p>

### Desktop (Linux)

<p align="center">
  <img src="docs/screenshots/pc_home.png" width="48%" alt="Desktop Recorder">
  <img src="docs/screenshots/pc_library.png" width="48%" alt="Desktop Library and Detail Panel">
</p>

## Features

### 🎙️ Recording & transcription

- Recording with a live level meter
- Automatic transcription in the background, with an AI-generated title and tags
- Speaker diarization — multi-speaker transcripts come out as `A: …` / `B: …`
- Editable transcripts; regenerate or share a recording anytime
- Offline queue that resumes once the network is back

### 📝 Notes & translation

- Markdown notes from a transcript: detailed, concise, meeting minutes, casual or custom
- Notes get their own tab, search, and tags
- Translation of transcripts and notes into 22 languages

### 📚 Library

- Playback, fuzzy search and tag filtering
- Colours for tags and notes

### 🤖 AI providers

- Transcription: Groq, OpenAI, ElevenLabs Scribe, Gemini or any OpenAI-compatible server
- Titles, tags, notes and translation: Groq, OpenAI, Gemini or any OpenAI-compatible server
- A separate provider, key and model for each task
- Optional temperature and top_p, off by default
- API keys kept in Android Keystore / Linux Secret Service

### 🎨 Look & feel

- Material 3 Expressive, English and Polish
- Themes: Material 3, Dracula, Nord, Gruvbox, Catppuccin and Solarized

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

