FROM gastube-flutter-focal:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Build tools compile libmpv inside this image. The phone rootfs does not
# receive them. libasound is for volume_controller, not for mpv's audio output.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libasound2-dev \
        openjdk-17-jdk-headless \
        ca-certificates \
        curl \
        build-essential \
        nasm \
        pkg-config \
        ninja-build \
        patchelf \
        python3 \
        python3-pip \
        zlib1g-dev \
        libgnutls28-dev \
        libfreetype6-dev \
        libfribidi-dev \
        libfontconfig1-dev \
        libharfbuzz-dev \
        libpng-dev \
        libpulse-dev \
        libegl1-mesa-dev \
        libgles2-mesa-dev \
        libwayland-dev \
        libepoxy-dev \
        libglib2.0-dev \
    && pip3 install 'meson==1.2.3' \
    && rm -rf /var/lib/apt/lists/*
