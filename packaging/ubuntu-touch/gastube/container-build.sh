#!/usr/bin/env bash
# Build the Ubuntu Touch release bundle inside an Ubuntu 20.04 arm64 container.
# The host must be arm64 so that container is not emulated. GitHub Actions
# runs this on ubuntu-24.04-arm. Do not use the x64 Flutter cross-compile.
set -euo pipefail

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "container-build.sh needs an arm64 host. The Focal container has to match the phone." >&2
  exit 1
fi

root=$(cd "$(dirname "$0")/../../.." && pwd)
engine="$root/packaging/ubuntu-touch/engine-partial/libflutter_linux_gtk.so"
if [[ ! -f "$engine" ]]; then
  echo "The release engine library is missing: $engine" >&2
  exit 1
fi

docker build -t gastube-flutter-focal:20.04 \
  -f "$root/packaging/ubuntu-touch/hello/Dockerfile" \
  "$root/packaging/ubuntu-touch/hello"
docker build -t gastube-flutter-focal-ut:20.04 \
  -f "$root/packaging/ubuntu-touch/gastube/Dockerfile" \
  "$root/packaging/ubuntu-touch/gastube"

docker run --rm \
  -e GASTUBE_UBUNTU_TOUCH=1 \
  -v "$root":/src \
  -v gastube-flutter-sdk:/opt/flutter \
  -v gastube-flutter-pub:/opt/pub-cache \
  -v gastube-playback-prefix:/opt/gastube-playback \
  -w /src \
  gastube-flutter-focal-ut:20.04 \
  bash -lc 'git config --global --add safe.directory "*" && bash /src/packaging/ubuntu-touch/gastube/build-arm64.sh'

dest="$root/packaging/ubuntu-touch/gastube"
rm -rf "$dest/bundle"
mkdir -p "$dest/bundle"
cp -a "$dest/dist/bundle/." "$dest/bundle/"
docker run --rm \
  -v "$root":/src \
  -w /src \
  gastube-flutter-focal-ut:20.04 \
  bash /src/packaging/ubuntu-touch/gastube/check-bundle.sh
