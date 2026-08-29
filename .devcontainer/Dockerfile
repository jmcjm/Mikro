# --- Builder Stage ---
# trixie (Debian 13) ships mesa 25, which knows the host's RDNA4 GPU; bookworm's does not.
FROM debian:trixie-slim AS builder

ARG DEBIAN_FRONTEND=noninteractive

ENV ANDROID_SDK_ROOT=/android-sdk
ENV FLUTTER_SDK_ROOT=/flutter

# trixie has no openjdk-17-jdk; 21 is the current default JDK and is fine for AGP.
RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    wget \
    curl \
    unzip \
    xz-utils \
    ca-certificates \
    git \
    openjdk-21-jdk \
    gpg \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Download and install Android Command Line Tools.
# Deliberately NOT the newest build (16111833): that one deprecates sdkmanager in favour of the
# new `android` CLI and turns `--licenses` into a no-op, so no license hash files are written and
# `flutter doctor` can only report "Android license status unknown". Build 13114758 still ships the
# classic sdkmanager, and it resolves every package pinned below.
RUN mkdir -p ${ANDROID_SDK_ROOT}/cmdline-tools \
    && wget -q -O commandlinetools.zip "https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip" \
    && unzip -q commandlinetools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools \
    && mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest \
    && rm commandlinetools.zip

# Accept Android SDK licenses and install the components current stable Flutter expects.
# Flutter 3.47 defaults: compileSdk/targetSdk 36, ndkVersion 28.2.13676358.
RUN yes | ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null \
    && ${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager \
    "platform-tools" \
    "platforms;android-36" \
    "build-tools;36.0.0" \
    "ndk;28.2.13676358" \
    "cmake;3.22.1"

# Flutter's precache shells out to tar, which as root tries to restore the archived uid/gid.
# Under a rootless podman build those ids are unmappable and tar aborts, so opt out of it.
# Ownership is set explicitly by the COPY --chown into the final stage anyway.
ENV TAR_OPTIONS=--no-same-owner

# Install Flutter from the stable channel rather than a pinned tarball.
RUN git clone --depth 1 -b stable https://github.com/flutter/flutter.git ${FLUTTER_SDK_ROOT} \
    && git config --global --add safe.directory ${FLUTTER_SDK_ROOT} \
    && ${FLUTTER_SDK_ROOT}/bin/flutter --version \
    && ${FLUTTER_SDK_ROOT}/bin/flutter precache --linux --android

# --- Final Stage ---
FROM debian:trixie-slim AS final

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID
ARG HOME=/home/${USERNAME}
ARG DEBIAN_FRONTEND=noninteractive

ENV ANDROID_SDK_ROOT=${HOME}/android-sdk
ENV ANDROID_HOME=${HOME}/android-sdk
ENV FLUTTER_SDK_ROOT=${HOME}/flutter
ENV PATH=$PATH:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin
ENV PATH=$PATH:${ANDROID_SDK_ROOT}/platform-tools
ENV PATH=$PATH:${FLUTTER_SDK_ROOT}/bin
ENV SHELL=/bin/zsh

RUN apt-get update \
    && apt-get -y install --no-install-recommends \
    # base tooling
    curl \
    wget \
    git \
    unzip \
    xz-utils \
    zip \
    gpg \
    sudo \
    zsh \
    nano \
    ca-certificates \
    fonts-dejavu-core \
    openjdk-21-jdk \
    # Flutter Linux desktop toolchain
    clang \
    cmake \
    ninja-build \
    pkg-config \
    build-essential \
    libgtk-3-dev \
    liblzma-dev \
    # GPU / GL runtime so a Linux desktop build can actually render
    libgl1 \
    libglu1-mesa \
    libglx-mesa0 \
    libgl1-mesa-dri \
    libegl1 \
    mesa-vulkan-drivers \
    libwayland-client0 \
    # audio runtime (PulseAudio/PipeWire socket passthrough + ALSA)
    libpulse0 \
    libasound2t64 \
    # audioplayers on Linux is built on GStreamer
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-pulseaudio \
    # flutter_secure_storage on Linux is built on libsecret
    libsecret-1-dev \
    libjsoncpp-dev \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user matching the host uid/gid (paired with --userns=keep-id).
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/zsh ${USERNAME} \
    && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR ${HOME}

# Copy SDKs from the builder stage to the user's home directory
COPY --from=builder --chown=${USERNAME}:${USERNAME} /android-sdk ${ANDROID_SDK_ROOT}
COPY --from=builder --chown=${USERNAME}:${USERNAME} /flutter ${FLUTTER_SDK_ROOT}

RUN git config --global --add safe.directory ${FLUTTER_SDK_ROOT}
