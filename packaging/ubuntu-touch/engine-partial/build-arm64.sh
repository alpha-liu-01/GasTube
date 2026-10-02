#!/bin/bash
# Builds the Ubuntu Touch libflutter_linux_gtk.so from the synced 3.47.1
# engine tree. Run sync-engine.sh first. Desktop builds keep the official
# engine; only the Click bundle should pick up this library.
set -euo pipefail

root=/home/alpha/sdk/gastube-engine
tools=/home/alpha/sdk/depot_tools
here=$(cd "$(dirname "$0")" && pwd)

export PATH="$tools:$PATH"
cd "$root/src/engine/src"
# Partial repaint is not applied. The Click uses the official engine.
./flutter/tools/gn \
  --target-os linux \
  --linux-cpu arm64 \
  --runtime-mode release \
  --no-lto \
  --no-goma \
  --no-enable-unittests
ninja -C out/linux_release_arm64 -j 16 flutter/shell/platform/linux:flutter_linux_gtk
built=$root/src/engine/src/out/linux_release_arm64/libflutter_linux_gtk.so
cp "$built" "$here/libflutter_linux_gtk.so"
echo "built $built"
