FROM ubuntu:26.04

# Toolchain image for packaging/linux/build-release.sh.
# The repo is mounted at /src by packaging/linux/docker-build.sh.

ARG FLUTTER_VERSION=3.47.1

ENV DEBIAN_FRONTEND=noninteractive \
    CI=true \
    FLUTTER_ROOT=/opt/flutter \
    PATH=/opt/flutter/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        clang \
        cmake \
        curl \
        git \
        libgtk-3-dev \
        liblzma-dev \
        libmpv-dev \
        ninja-build \
        pkg-config \
        unzip \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL -o /tmp/flutter.tar.xz \
        "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar -C /opt -xf /tmp/flutter.tar.xz \
    && rm /tmp/flutter.tar.xz \
    && git config --system --add safe.directory /opt/flutter \
    && flutter config --no-analytics --enable-linux-desktop \
    && flutter precache --linux \
    && chmod -R a+rwX /opt/flutter

# sqlite3_flutter_libs configures mimalloc with Unix Makefiles, which needs make
# even though the Flutter app itself builds with Ninja.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        make \
        gcc \
        openjdk-17-jdk-headless \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
ENTRYPOINT ["bash"]
CMD ["/src/packaging/linux/build-release.sh"]
