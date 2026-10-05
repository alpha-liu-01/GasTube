#!/usr/bin/env bash
# Build a small static GPL ffmpeg that only remuxes into MP4.
# VP9 from WebM has no vpcC. The MP4 muxer builds that box from the
# pixel format, and probing only learns yuv420p when the VP9 decoder
# is present. Copy still does not re-encode.
# The desktop app runs: ffmpeg -i video -i audio -c copy -shortest -y out.mp4
# libmpv is a separate library and is not built here.
# usage: build-mux-ffmpeg.sh OUTPUT
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: build-mux-ffmpeg.sh OUTPUT" >&2
  exit 1
fi

output="$1"
version="6.1.1"
sha256="8684f4b00f94b85461884c3719382f1261f0d9eb3d59640a1f4ac0873616f968"
cache="${GASTUBE_FFMPEG_CACHE:-${XDG_CACHE_HOME:-${HOME}/.cache}/gastube/ffmpeg-mux}"
mkdir -p "${cache}"

wanted="x86_64"
case "${GASTUBE_FFMPEG_ARCH:-$(uname -m)}" in
  aarch64 | arm64) wanted="aarch64" ;;
  x86_64 | amd64) wanted="x86_64" ;;
  *)
    echo "Unsupported CPU ${GASTUBE_FFMPEG_ARCH:-$(uname -m)}." >&2
    exit 1
    ;;
esac

cc_matches() {
  local bin="$1"
  command -v "${bin}" >/dev/null 2>&1 || return 1
  "${bin}" -dumpmachine 2>/dev/null | grep -q "${wanted}"
}

if cc_matches "${CC:-}"; then
  :
elif cc_matches gcc; then
  CC=gcc
elif cc_matches clang; then
  CC=clang
else
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) ;;
    *)
      echo "No ${wanted} C compiler. Install gcc or clang." >&2
      exit 1
      ;;
  esac
  case "${wanted}" in
    aarch64) mingw_asset="llvm-mingw-20260922-ucrt-aarch64.zip" ;;
    *) mingw_asset="llvm-mingw-20260922-ucrt-x86_64.zip" ;;
  esac
  mingw_root="${cache}/${mingw_asset%.zip}"
  if [[ ! -x "${mingw_root}/bin/gcc" && ! -x "${mingw_root}/bin/gcc.exe" ]]; then
    echo "Downloading ${mingw_asset}"
    curl -fL --retry 3 -o "${cache}/${mingw_asset}" \
      "https://github.com/mstorsjo/llvm-mingw/releases/download/20260922/${mingw_asset}"
    rm -rf "${mingw_root}"
    if command -v unzip >/dev/null 2>&1; then
      unzip -q "${cache}/${mingw_asset}" -d "${cache}"
    else
      tar -xf "${cache}/${mingw_asset}" -C "${cache}"
    fi
  fi
  export PATH="${mingw_root}/bin:${PATH}"
  if cc_matches gcc; then
    CC=gcc
  else
    echo "llvm-mingw gcc does not target ${wanted}." >&2
    exit 1
  fi
fi
export CC

tarball="${cache}/ffmpeg-${version}.tar.xz"
if [[ ! -f "${tarball}" ]]; then
  curl -fL --retry 3 -o "${tarball}.partial" \
    "https://ffmpeg.org/releases/ffmpeg-${version}.tar.xz"
  echo "${sha256}  ${tarball}.partial" | sha256sum -c -
  mv "${tarball}.partial" "${tarball}"
else
  echo "${sha256}  ${tarball}" | sha256sum -c -
fi

src="${cache}/ffmpeg-${version}"
if [[ ! -x "${src}/configure" ]]; then
  rm -rf "${src}"
  tar -xJf "${tarball}" -C "${cache}"
fi

build="${cache}/build-${wanted}"
rm -rf "${build}"
mkdir -p "${build}"

configure_args=(
  --disable-all
  --disable-autodetect
  --disable-doc
  --disable-debug
  --disable-network
  --disable-iconv
  --enable-small
  --enable-gpl
  --enable-static
  --disable-shared
  --enable-ffmpeg
  --enable-avcodec
  --enable-avformat
  --enable-avutil
  --enable-avfilter
  --enable-protocol=file
  --enable-demuxer=mov,matroska
  --enable-muxer=mp4
  --enable-parser=h264,aac,aac_latm,opus,vp9,av1
  --enable-decoder=vp9
  --enable-bsf=aac_adtstoasc,extract_extradata,vp9_superframe
  --extra-cflags=-Os
)
if [[ "${wanted}" == x86_64 ]]; then
  configure_args+=(--disable-x86asm)
fi
machine="$("${CC}" -dumpmachine)"
case "${machine}" in
  *mingw* | *windows*) configure_args+=(--extra-ldflags=-static) ;;
esac

(
  cd "${build}"
  "${src}/configure" "${configure_args[@]}"
  jobs="$(nproc 2>/dev/null || echo "${NUMBER_OF_PROCESSORS:-2}")"
  make -j"${jobs}"
)

built="${build}/ffmpeg"
if [[ -f "${build}/ffmpeg.exe" ]]; then
  built="${build}/ffmpeg.exe"
fi
install -m 755 "${built}" "${output}"
echo "Installed ${output}"
