#!/bin/bash
# Runs on every container start.
#
# The Wayland/PulseAudio/PipeWire sockets are bind-mounted under /run/user/1000, which podman
# auto-creates as a root-owned directory. GTK and the PulseAudio client both expect
# XDG_RUNTIME_DIR to be owned by the current user and mode 0700, so fix it up here.
# The sockets themselves already carry the host uid thanks to --userns=keep-id, and are left alone.
set -u

RUNTIME_DIR="/run/user/$(id -u)"

if [ -d "$RUNTIME_DIR" ]; then
    sudo chown "$(id -u):$(id -g)" "$RUNTIME_DIR" 2>/dev/null || true
    sudo chmod 700 "$RUNTIME_DIR" 2>/dev/null || true
    if [ -d "$RUNTIME_DIR/pulse" ]; then
        sudo chown "$(id -u):$(id -g)" "$RUNTIME_DIR/pulse" 2>/dev/null || true
    fi
fi

exit 0
