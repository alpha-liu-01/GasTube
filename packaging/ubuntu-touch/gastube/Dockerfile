FROM gastube-flutter-focal:20.04

ENV DEBIAN_FRONTEND=noninteractive

# volume_controller links ALSA. The phone already has libasound.so.2.
# libmpv stays out of this image so the Ubuntu Touch build cannot link it.
# openjdk-17 builds the sidecar jar. curl fetches the Temurin 17 JRE.
# libmpv stays out of this image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libasound2-dev \
        openjdk-17-jdk-headless \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*
