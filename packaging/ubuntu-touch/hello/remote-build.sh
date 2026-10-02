#!/bin/bash
# Copies this project to the Mac and builds it in an Ubuntu 20.04 arm64
# container. The Click is packaged later on the x64 development machine.
set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
host=alpha@10.0.0.118
remote=gastube-ut/hello

ssh "$host" "mkdir -p \$HOME/$remote; nohup caffeinate -dimsu -t 10800 >/dev/null 2>&1 </dev/null &"
rsync -a --delete \
  --exclude build/ \
  --exclude .dart_tool/ \
  --exclude bundle/ \
  --exclude dist/ \
  --exclude linux/flutter/ephemeral/ \
  -e ssh \
  "$root/" "$host:$remote/"

ssh "$host" "set -euo pipefail
  export PATH=\"/Applications/Docker.app/Contents/Resources/bin:\$PATH\"
  cd \$HOME/$remote
  bash ./fetch-base-image.sh
  DOCKER_BUILDKIT=0 docker build --pull=false -t gastube-flutter-focal:20.04 -f Dockerfile .
  docker run --platform linux/arm64 --rm \
    -v \$HOME/$remote:/src \
    -v gastube-flutter-sdk:/opt/flutter \
    -v gastube-flutter-pub:/opt/pub-cache \
    -w /src \
    gastube-flutter-focal:20.04 \
    bash /src/build-arm64.sh"

mkdir -p "$root/bundle" "$root/dist"
rsync -a --delete -e ssh "$host:$remote/dist/" "$root/dist/"
rsync -a --delete -e ssh "$host:$remote/dist/bundle/" "$root/bundle/"
"$root/check-bundle.sh"
