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
flutter config --no-analytics --enable-linux-desktop
flutter --version
cd /src
flutter pub get
flutter build linux --release \
  --dart-define=GASTUBE_FLUTTER_VERSION=3.47.1 \
  --dart-define=GASTUBE_FLUTTER_ENGINE="$expected_engine"

bundle=$(find build/linux -type f -path '*/release/bundle/hello' -print -quit)
if [[ -z "$bundle" ]]; then
  echo "release bundle executable was not produced" >&2
  exit 1
fi
bundle_dir=$(dirname "$bundle")
test -f "$bundle_dir/lib/libflutter_linux_gtk.so"
test -f "$bundle_dir/data/icudtl.dat"

rm -rf /src/dist
mkdir -p /src/dist
cp -a "$bundle_dir" /src/dist/bundle
{
  echo "machine=$machine"
  getconf GNU_LIBC_VERSION
  dpkg-query -W libc6 libstdc++6 libgtk-3-0
  echo "engine=$actual_engine"
} | tee /src/dist/build-info.txt
flutter --version | tee /src/dist/flutter-version.txt
readelf -d "$bundle" | tee /src/dist/hello-dynamic.txt
readelf -V "$bundle" | tee /src/dist/hello-versions.txt
readelf -V "$bundle_dir/lib/libflutter_linux_gtk.so" | tee /src/dist/engine-versions.txt
echo "bundle=$bundle_dir"
