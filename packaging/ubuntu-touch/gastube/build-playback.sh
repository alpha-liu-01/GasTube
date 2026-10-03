#!/bin/bash
# Builds FFmpeg, libass, and libmpv inside the Ubuntu 20.04 arm64 container.
# The phone does not receive these packages through apt.
set -euo pipefail

prefix=/opt/gastube-playback
stamp="ffmpeg-6.1.1-h264-hybris-csd libass-0.17.3 mpv-0.35.1"
mkdir -p "$prefix"
export LD_LIBRARY_PATH="$prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
if [[ -e "$prefix/lib/libmpv.so.2" && -x "$prefix/bin/ffmpeg" && -f "$prefix/stamp" ]] &&
   [[ "$(tr -d '\n' < "$prefix/stamp")" == "$stamp" ]]; then
  decoders=$("$prefix/bin/ffmpeg" -hide_banner -decoders)
  if grep -q h264_hybris <<<"$decoders"; then
    mkdir -p "$prefix/share"
    if [[ ! -s "$prefix/share/playback-probe.mp4" ]]; then
      "$prefix/bin/ffmpeg" -y \
        -f lavfi -i "testsrc=size=320x180:rate=15:duration=3" \
        -f lavfi -i "sine=frequency=440:sample_rate=44100:duration=3" \
        -c:v mpeg4 -q:v 5 \
        -c:a aac -b:a 64k \
        -shortest \
        "$prefix/share/playback-probe.mp4"
    fi
    printf '%s\n' "$stamp" > "$prefix/stamp"
    echo "playback libraries already built ($stamp)"
    exit 0
  fi
fi

find "$prefix" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

fetch() {
  local url="$1" sha="$2" dest="$3"
  curl -fL --retry 3 -o "$dest" "$url"
  echo "$sha  $dest" | sha256sum -c -
}

fetch "https://ffmpeg.org/releases/ffmpeg-6.1.1.tar.xz" \
  "8684f4b00f94b85461884c3719382f1261f0d9eb3d59640a1f4ac0873616f968" \
  "$work/ffmpeg.tar.xz"
fetch "https://github.com/libass/libass/releases/download/0.17.3/libass-0.17.3.tar.xz" \
  "eae425da50f0015c21f7b3a9c7262a910f0218af469e22e2931462fed3c50959" \
  "$work/libass.tar.xz"
fetch "https://github.com/mpv-player/mpv/archive/refs/tags/v0.35.1.tar.gz" \
  "41df981b7b84e33a2ef4478aaf81d6f4f5c8b9cd2c0d337ac142fc20b387d1a9" \
  "$work/mpv.tar.gz"

tar -xJf "$work/ffmpeg.tar.xz" -C "$work"
tar -xJf "$work/libass.tar.xz" -C "$work"
tar -xzf "$work/mpv.tar.gz" -C "$work"

here=$(cd "$(dirname "$0")" && pwd)
cp "$here/h264_hybris.c" "$work/ffmpeg-6.1.1/libavcodec/h264_hybris.c"
sed -i '/^extern const FFCodec ff_h264_decoder;$/a extern const FFCodec ff_h264_hybris_decoder;' \
  "$work/ffmpeg-6.1.1/libavcodec/allcodecs.c"
sed -i 's/^OBJS-$(CONFIG_H264_DECODER)/OBJS-$(CONFIG_H264_HYBRIS_DECODER)     += h264_hybris.o\n&/' \
  "$work/ffmpeg-6.1.1/libavcodec/Makefile"
grep -q ff_h264_hybris_decoder "$work/ffmpeg-6.1.1/libavcodec/allcodecs.c"
grep -q CONFIG_H264_HYBRIS_DECODER "$work/ffmpeg-6.1.1/libavcodec/Makefile"

export PKG_CONFIG_PATH="$prefix/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export LD_LIBRARY_PATH="$prefix/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

(
  cd "$work/ffmpeg-6.1.1"
  ./configure \
    --prefix="$prefix" \
    --enable-shared \
    --disable-static \
    --disable-doc \
    --disable-ffplay \
    --disable-debug \
    --enable-gpl \
    --enable-version3 \
    --enable-pic \
    --enable-gnutls \
    --disable-nvenc \
    --disable-nvdec \
    --disable-cuda \
    --disable-cuvid \
    --disable-ffnvcodec \
    --disable-vulkan \
    --disable-vaapi \
    --disable-vdpau \
    --enable-v4l2-m2m \
    --disable-xlib \
    --disable-libxcb
  make -j"$(nproc)"
  make install
)

(
  cd "$work/libass-0.17.3"
  ./configure --prefix="$prefix" --disable-static --enable-shared
  make -j"$(nproc)"
  make install
)

(
  cd "$work/mpv-0.35.1"
  meson setup build \
    --prefix="$prefix" \
    --libdir=lib \
    -Dbuildtype=release \
    -Db_ndebug=true \
    -Dlibmpv=true \
    -Dcplayer=false \
    -Dlibplacebo=disabled \
    -Dlua=disabled \
    -Djavascript=disabled \
    -Dlibarchive=disabled \
    -Ddvdnav=disabled \
    -Dcdda=disabled \
    -Dsdl2=disabled \
    -Dsdl2-audio=disabled \
    -Dsdl2-video=disabled \
    -Dopenal=disabled \
    -Djack=disabled \
    -Dalsa=disabled \
    -Doss-audio=disabled \
    -Dsndio=disabled \
    -Dpipewire=disabled \
    -Dpulse=enabled \
    -Dvulkan=disabled \
    -Dshaderc=disabled \
    -Dx11=disabled \
    -Degl-x11=disabled \
    -Degl-drm=disabled \
    -Duchardet=disabled \
    -Dvapoursynth=disabled \
    -Drubberband=disabled \
    -Dlibbluray=disabled \
    -Dmanpage-build=disabled \
    -Dbuild-date=false
  meson compile -C build
  meson install -C build
)

mkdir -p "$prefix/share"
"$prefix/bin/ffmpeg" -hide_banner -decoders >"$prefix/decoders.txt"
grep -q h264_hybris "$prefix/decoders.txt"
"$prefix/bin/ffmpeg" -y \
  -f lavfi -i "testsrc=size=320x180:rate=15:duration=3" \
  -f lavfi -i "sine=frequency=440:sample_rate=44100:duration=3" \
  -c:v mpeg4 -q:v 5 \
  -c:a aac -b:a 64k \
  -shortest \
  "$prefix/share/playback-probe.mp4"

python3 - "$prefix/lib/libmpv.so.2" <<'PY'
import re, subprocess, sys
path = sys.argv[1]
text = subprocess.check_output(["readelf", "-V", path], text=True)
limits = {"GLIBC_": (2, 31), "GLIBCXX_": (3, 4, 28), "CXXABI_": (1, 3, 12)}
for prefix, limit in limits.items():
    for match in set(re.findall(re.escape(prefix) + r"[0-9.]+", text)):
        parts = tuple(int(piece) for piece in match[len(prefix):].split(".") if piece)
        if parts > limit:
            raise SystemExit(f"{path} needs {match}")
print(f"{path} glibc is within 2.31")
PY
printf '%s\n' "$stamp" > "$prefix/stamp"
echo "playback libraries installed to $prefix"
