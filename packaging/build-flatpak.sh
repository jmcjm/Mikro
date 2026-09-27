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
# Publishing (optional, used by CI for releases):
#   FLATPAK_REPO_URL     public URL the OSTree repo build/flatpak/repo is served from.
#                        The bundle then points at it, so an app installed from the
#                        .flatpak file gets updates via `flatpak update` / app stores,
#                        and pl.jmc.mikro.flatpakref / .flatpakrepo are written next to it.
#   FLATPAK_GPG_KEY_ID   key the repo and bundle are signed with (needs no passphrase).
#   FLATPAK_GPG_HOMEDIR  GnuPG home holding that key (default: gpg's own default).
#   Setting FLATPAK_REPO_URL requires FLATPAK_GPG_KEY_ID - flatpak refuses unsigned
#   remotes by default.
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
FLATHUB_REPO="https://dl.flathub.org/repo/flathub.flatpakrepo"

REPO_URL="${FLATPAK_REPO_URL:-}"
GPG_KEY_ID="${FLATPAK_GPG_KEY_ID:-}"
GPG_ARGS=()
if [ -n "$GPG_KEY_ID" ]; then
  GPG_ARGS+=(--gpg-sign="$GPG_KEY_ID")
  if [ -n "${FLATPAK_GPG_HOMEDIR:-}" ]; then
    GPG_ARGS+=(--gpg-homedir="$FLATPAK_GPG_HOMEDIR")
  fi
fi
if [ -n "$REPO_URL" ] && [ -z "$GPG_KEY_ID" ]; then
  echo "FLATPAK_REPO_URL needs FLATPAK_GPG_KEY_ID (flatpak rejects unsigned remotes)" >&2
  exit 1
fi

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
  "${GPG_ARGS[@]+"${GPG_ARGS[@]}"}" \
  --repo="$OSTREE_REPO" "$BUILD_DIR" "$MANIFEST"

echo "==> Updating repo summary and appstream"
flatpak build-update-repo --title="Mikro" --default-branch=master \
  --generate-static-deltas --prune \
  "${GPG_ARGS[@]+"${GPG_ARGS[@]}"}" "$OSTREE_REPO"

FLATPAK_BUNDLE_ARGS=(--runtime-repo="$FLATHUB_REPO")
if [ -n "$REPO_URL" ]; then
  REPO_URL="${REPO_URL%/}/"
  PUBKEY_FILE="$OUT_DIR/$APP_ID.gpg"
  gpg ${FLATPAK_GPG_HOMEDIR:+--homedir "$FLATPAK_GPG_HOMEDIR"} \
    --export "$GPG_KEY_ID" > "$PUBKEY_FILE"
  [ -s "$PUBKEY_FILE" ] || { echo "cannot export GPG key $GPG_KEY_ID" >&2; exit 1; }
  PUBKEY_B64="$(base64 -w0 "$PUBKEY_FILE")"
  FLATPAK_BUNDLE_ARGS+=(--repo-url="$REPO_URL" --gpg-keys="$PUBKEY_FILE")

  echo "==> Writing $APP_ID.flatpakref and $APP_ID.flatpakrepo"
  cat > "$OUT_DIR/$APP_ID.flatpakref" <<EOF
[Flatpak Ref]
Name=$APP_ID
Branch=master
Title=Mikro
Url=$REPO_URL
SuggestRemoteName=mikro
RuntimeRepo=$FLATHUB_REPO
IsRuntime=false
Homepage=https://github.com/jmcjm/mikro
GPGKey=$PUBKEY_B64
EOF
  cat > "$OUT_DIR/$APP_ID.flatpakrepo" <<EOF
[Flatpak Repo]
Title=Mikro
Url=$REPO_URL
Homepage=https://github.com/jmcjm/mikro
GPGKey=$PUBKEY_B64
EOF
fi

echo "==> Building single-file bundle"
rm -f "$BUNDLE_FILE"
flatpak build-bundle "${FLATPAK_BUNDLE_ARGS[@]}" \
  "$OSTREE_REPO" "$BUNDLE_FILE" "$APP_ID" master

if [ "$INSTALL" -eq 1 ]; then
  echo "==> Installing bundle (--user)"
  flatpak install --user --noninteractive --reinstall "$BUNDLE_FILE"
  echo "Run with: flatpak run $APP_ID"
fi

echo "==> Ready: $BUNDLE_FILE ($(du -h "$BUNDLE_FILE" | cut -f1))"
