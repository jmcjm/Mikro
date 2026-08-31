#!/usr/bin/env bash
# Builds the Flutter release bundle for Linux to build/linux/x64/release/bundle.
#
# Shared step for build-flatpak.sh and build-appimage.sh; can also be run standalone.
# By default (MIKRO_BUILD_MODE=auto) builds in the repo's devcontainer where the
# complete toolchain is configured; falls back to host `flutter` if devcontainer CLI is absent.
#
# Usage (from repository root):
#   ./packaging/build-bundle.sh [--clean]
#
# Options:
#   --clean   Runs `flutter clean` prior to build (mandatory for bundle size benchmarks).
#
# Environment variables:
#   MIKRO_BUILD_MODE                 auto (default) | devcontainer | host
#   MIKRO_DEVCONTAINER_DOCKER_PATH   container engine binary (default: podman)
#
# Requires: devcontainer CLI + podman OR flutter in PATH.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_DIR="$REPO_ROOT/build/linux/x64/release/bundle"
BUILD_MODE="${MIKRO_BUILD_MODE:-auto}"
DOCKER_PATH="${MIKRO_DEVCONTAINER_DOCKER_PATH:-podman}"
CLEAN=0

for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

container_workdir() {
  local main_root rel
  main_root="$(cd "$(git -C "$REPO_ROOT" rev-parse --git-common-dir)/.." && pwd)"
  rel="${REPO_ROOT#"$main_root"}"
  echo "/workspaces/$(basename "$main_root")${rel}"
}

main_repo_root() {
  (cd "$(git -C "$REPO_ROOT" rev-parse --git-common-dir)/.." && pwd)
}

if [ "$BUILD_MODE" = auto ]; then
  if command -v devcontainer >/dev/null && [ -f "$(main_repo_root)/.devcontainer/devcontainer.json" ]; then
    BUILD_MODE=devcontainer
  elif command -v flutter >/dev/null; then
    BUILD_MODE=host
  else
    echo "no toolchain found: neither devcontainer CLI nor flutter in PATH" >&2
    exit 1
  fi
fi

flutter_cmd="flutter build linux --release"
[ "$CLEAN" -eq 1 ] && flutter_cmd="flutter clean && flutter pub get && $flutter_cmd"

case "$BUILD_MODE" in
  devcontainer)
    echo "==> Building Linux bundle inside devcontainer (${DOCKER_PATH})"
    devcontainer up --workspace-folder "$(main_repo_root)" --docker-path "$DOCKER_PATH" >/dev/null
    devcontainer exec --workspace-folder "$(main_repo_root)" --docker-path "$DOCKER_PATH" -- \
      bash -lc "cd '$(container_workdir)' && $flutter_cmd"
    ;;
  host)
    echo "==> Building Linux bundle with local Flutter toolchain"
    (cd "$REPO_ROOT" && eval "$flutter_cmd")
    ;;
  *)
    echo "unknown MIKRO_BUILD_MODE: $BUILD_MODE" >&2
    exit 2
    ;;
esac

[ -x "$BUNDLE_DIR/mikro" ] || { echo "build succeeded, but $BUNDLE_DIR/mikro not found" >&2; exit 1; }
echo "==> bundle ready: $BUNDLE_DIR ($(du -sh "$BUNDLE_DIR" | cut -f1))"
