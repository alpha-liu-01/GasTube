#!/usr/bin/env bash
# Build the mux-only GPL ffmpeg into DEST, next to gastube or gastube.exe.
# Playback uses libmpv, not this binary.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: bundle-ffmpeg.sh DEST" >&2
  exit 1
fi

dest="$(cd "$1" && pwd)"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${dest}" in
  */windows/arm64 | */windows/arm64/*) export GASTUBE_FFMPEG_ARCH=aarch64 ;;
  */windows/x64 | */windows/x64/*) export GASTUBE_FFMPEG_ARCH=x86_64 ;;
esac

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) binary_name="ffmpeg.exe" ;;
  Linux) binary_name="ffmpeg" ;;
  *)
    echo "Unsupported OS $(uname -s). This script builds the Linux and Windows mux ffmpeg." >&2
    exit 1
    ;;
esac

echo "Building mux ffmpeg into ${dest}/${binary_name}"
bash "${here}/build-mux-ffmpeg.sh" "${dest}/${binary_name}"
"${dest}/${binary_name}" -version
