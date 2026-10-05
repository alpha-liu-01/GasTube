#!/bin/bash
# Copies the GasTube tree to the Mac and builds the arm64 release bundle in
# the Ubuntu 20.04 container. Click packaging stays on the x64 machine.
set -euo pipefail

root=$(cd "$(dirname "$0")/../../.." && pwd)
host=alpha@10.0.0.118
remote=gastube-ut/app

ssh "$host" "mkdir -p \$HOME/$remote; nohup caffeinate -dimsu -t 10800 >/dev/null 2>&1 </dev/null &"
rsync -a --delete \
  --exclude .git/ \
  --exclude .cursor/ \
  --exclude doc/private/ \
  --exclude build/ \
  --exclude .dart_tool/ \
  --exclude '**/ephemeral/' \
  --exclude packaging/ubuntu-touch/hello/bundle/ \
  --exclude packaging/ubuntu-touch/hello/dist/ \
  --exclude packaging/ubuntu-touch/probe/build/ \
  --exclude packaging/ubuntu-touch/gastube/bundle/ \
  --exclude packaging/ubuntu-touch/gastube/build/ \
  --exclude packaging/ubuntu-touch/gastube/dist/ \
  -e ssh \
  "$root/" "$host:$remote/"

ssh "$host" "set -euo pipefail
  export PATH=\"/Applications/Docker.app/Contents/Resources/bin:\$PATH\"
  cd \$HOME/$remote/packaging/ubuntu-touch/gastube
  DOCKER_BUILDKIT=0 docker build --pull=false -t gastube-flutter-focal-ut:20.04 .
  docker run --platform linux/arm64 --rm \
    -e GASTUBE_UBUNTU_TOUCH=1 \
    -v \$HOME/$remote:/src \
    -v gastube-flutter-sdk:/opt/flutter \
    -v gastube-flutter-pub:/opt/pub-cache \
    -v gastube-playback-prefix:/opt/gastube-playback \
    -w /src \
    gastube-flutter-focal-ut:20.04 \
    bash /src/packaging/ubuntu-touch/gastube/build-arm64.sh"

dest="$root/packaging/ubuntu-touch/gastube"
mkdir -p "$dest/bundle" "$dest/dist"
rsync -a --delete -e ssh "$host:$remote/packaging/ubuntu-touch/gastube/dist/" "$dest/dist/"
rsync -a --delete -e ssh "$host:$remote/packaging/ubuntu-touch/gastube/dist/bundle/" "$dest/bundle/"
"$dest/check-bundle.sh"
