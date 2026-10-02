FROM gastube-flutter-focal:20.04

ENV DEBIAN_FRONTEND=noninteractive

# volume_controller links ALSA. The phone already has libasound.so.2.
# libmpv stays out of this image so the Ubuntu Touch build cannot link it.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libasound2-dev \
    && rm -rf /var/lib/apt/lists/*
