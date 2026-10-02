#!/bin/bash
# Checks out Flutter engine 5d53178869 (Flutter 3.47.1) and its dependencies.
# The tree is outside the GasTube repo. It is only used to build the Ubuntu
# Touch libflutter_linux_gtk.so.
set -euo pipefail

root=/home/alpha/sdk/gastube-engine
# Flutter 3.47.1 framework. engine.version is 5d53178869; that commit is in
# this repo, and the three files the partial-repaint patch edits are unchanged
# between it and this framework revision. The archived engine git repo does
# not contain 5d53178869.
revision=6655482ec06e547f90abf8ae7590466f4415978d
tools=/home/alpha/sdk/depot_tools

if [[ ! -x "$tools/gclient" ]]; then
  git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$tools"
fi
export PATH="$tools:$PATH"

mkdir -p "$root"
cd "$root"
if [[ -d src/flutter && ! -d src/engine ]]; then
  rm -rf src
fi
if [[ ! -d src/.git ]]; then
  git clone --reference /home/alpha/sdk/flutter --dissociate \
    https://github.com/flutter/flutter.git src
fi
git -C src checkout "$revision"

cat > src/.gclient << EOF
solutions = [
  {
    "managed": False,
    "name": ".",
    "url": "https://github.com/flutter/flutter.git@$revision",
    "custom_deps": {},
    "deps_file": "DEPS",
    "safesync_url": "",
  },
]
EOF

cd src
gclient sync -D --no-history --with_branch_heads
echo "engine sync finished at $revision"
