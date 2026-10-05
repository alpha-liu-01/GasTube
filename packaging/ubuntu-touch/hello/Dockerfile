FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    binutils \
    build-essential \
    ca-certificates \
    clang \
    cmake \
    curl \
    git \
    libglu1-mesa \
    libgtk-3-dev \
    liblzma-dev \
    ninja-build \
    pkg-config \
    unzip \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*
