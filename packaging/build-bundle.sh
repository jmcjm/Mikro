#!/usr/bin/env bash
# Buduje bundla Fluttera dla Linuksa (release) do build/linux/x64/release/bundle.
#
# Wspolny krok dla build-flatpak.sh i build-appimage.sh; mozna go tez uruchomic
# osobno. Domyslnie (MIKRO_BUILD_MODE=auto) buduje w devcontainerze repozytorium,
# bo tylko tam jest przewidziany toolchain Fluttera; gdy CLI devcontainerow nie
# ma, korzysta z `flutter` z PATH.
#
# Uzycie (z katalogu glownego repo):
#   ./packaging/build-bundle.sh [--clean]
#
# Opcje:
#   --clean   wykonuje `flutter clean` przed buildem (konieczne, gdy mierzysz
#             rozmiar bundla - inaczej zostaja w nim stale pliki)
#
# Zmienne srodowiskowe:
#   MIKRO_BUILD_MODE                 auto (domyslnie) | devcontainer | host
#   MIKRO_DEVCONTAINER_DOCKER_PATH   binarka silnika kontenerow (domyslnie podman)
#
# Wymaga: devcontainer CLI + podman ALBO flutter w PATH.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLE_DIR="$REPO_ROOT/build/linux/x64/release/bundle"
BUILD_MODE="${MIKRO_BUILD_MODE:-auto}"
DOCKER_PATH="${MIKRO_DEVCONTAINER_DOCKER_PATH:-podman}"
CLEAN=0

for arg in "$@"; do
  case "$arg" in
    --clean) CLEAN=1 ;;
    *) echo "nieznana opcja: $arg" >&2; exit 2 ;;
  esac
done

# Devcontainer jest podpiety do glownego katalogu repozytorium, a nie do
# worktree, wiec sciezke w kontenerze skladamy z /workspaces/<nazwa repo>
# i pozycji tego katalogu wzgledem glownego katalogu repozytorium.
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
    echo "brak toolchainu: ani devcontainer CLI, ani flutter w PATH" >&2
    exit 1
  fi
fi

flutter_cmd="flutter build linux --release"
[ "$CLEAN" -eq 1 ] && flutter_cmd="flutter clean && flutter pub get && $flutter_cmd"

case "$BUILD_MODE" in
  devcontainer)
    echo "==> build bundla w devcontainerze (${DOCKER_PATH})"
    devcontainer up --workspace-folder "$(main_repo_root)" --docker-path "$DOCKER_PATH" >/dev/null
    devcontainer exec --workspace-folder "$(main_repo_root)" --docker-path "$DOCKER_PATH" -- \
      bash -lc "cd '$(container_workdir)' && $flutter_cmd"
    ;;
  host)
    echo "==> build bundla lokalnym flutterem"
    (cd "$REPO_ROOT" && eval "$flutter_cmd")
    ;;
  *)
    echo "nieznany MIKRO_BUILD_MODE: $BUILD_MODE" >&2
    exit 2
    ;;
esac

[ -x "$BUNDLE_DIR/mikro" ] || { echo "build sie udal, ale brak $BUNDLE_DIR/mikro" >&2; exit 1; }
echo "==> bundle gotowy: $BUNDLE_DIR ($(du -sh "$BUNDLE_DIR" | cut -f1))"
