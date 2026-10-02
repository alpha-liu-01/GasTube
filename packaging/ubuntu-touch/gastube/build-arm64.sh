#!/bin/bash
# Runs inside the Ubuntu 20.04 arm64 container. Do not run this on macOS
# or on a newer Linux distribution.
set -euo pipefail

expected_engine=5d531788691ec3404cac0cee66ead4007b177363
machine=$(uname -m)
if [[ "$machine" != "aarch64" ]]; then
  echo "expected aarch64, got $machine" >&2
  exit 1
fi

if [[ ! -x /opt/flutter/bin/flutter ]]; then
  find /opt/flutter -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  git clone --depth 1 --branch 3.47.1 https://github.com/flutter/flutter.git /opt/flutter
fi

git config --global --add safe.directory /opt/flutter
actual_engine=$(tr -d '[:space:]' < /opt/flutter/bin/internal/engine.version)
if [[ "$actual_engine" != "$expected_engine" ]]; then
  echo "engine revision $actual_engine != $expected_engine" >&2
  exit 1
fi

export PATH="/opt/flutter/bin:${PATH}"
export PUB_CACHE=/opt/pub-cache
export FLUTTER_SUPPRESS_ANALYTICS=true
export GASTUBE_UBUNTU_TOUCH=1
flutter config --no-analytics --enable-linux-desktop
flutter --version
cd /src
flutter pub get
flutter build linux --release --dart-define=GASTUBE_UBUNTU_TOUCH=true

bundle=$(find build/linux -type f -path '*/release/bundle/gastube' -print -quit)
if [[ -z "$bundle" ]]; then
  echo "release bundle executable was not produced" >&2
  exit 1
fi

# GTK on this image has im-wayland.so, and Mir does not offer a text-input
# global for it. Ship Maliit's GTK module inside the bundle instead of
# installing it into the rootfs.
gcc -shared -fPIC -O2 -Wall \
  $(pkg-config --cflags gtk+-3.0) \
  -o "$(dirname "$bundle")/lib/im-maliit.so" \
  /src/third_party/im-maliit/im-maliit.c \
  $(pkg-config --libs gtk+-3.0 gio-2.0) \
  -Wl,--no-undefined

out=/src/packaging/ubuntu-touch/gastube/dist
rm -rf "$out"
mkdir -p "$out"
cp -a "$(dirname "$bundle")" "$out/bundle"
{
  echo "engine=$expected_engine"
  echo "machine=$machine"
  echo "define=GASTUBE_UBUNTU_TOUCH"
  readelf -d "$bundle"
  readelf -V "$bundle"
} > "$out/build-info.txt"
echo "copied bundle to $out/bundle"
