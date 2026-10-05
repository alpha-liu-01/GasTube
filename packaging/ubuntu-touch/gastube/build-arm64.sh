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
bash /src/packaging/ubuntu-touch/gastube/build-playback.sh
export PKG_CONFIG_PATH="/opt/gastube-playback/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export LD_LIBRARY_PATH="/opt/gastube-playback/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
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

# Route B: Impeller presents to a Wayland subsurface. Desktop builds keep
# the official engine; only this Click replaces the library.
custom_engine=/src/packaging/ubuntu-touch/engine-partial/libflutter_linux_gtk.so
if [[ ! -f "$custom_engine" ]]; then
  echo "onscreen engine library is missing: $custom_engine" >&2
  exit 1
fi
cp "$custom_engine" "$(dirname "$bundle")/lib/libflutter_linux_gtk.so"
echo "replaced libflutter_linux_gtk.so with the onscreen present build"

bundle_dir=$(dirname "$bundle")
shopt -s nullglob
copied=0
for so in /opt/gastube-playback/lib/libmpv.so* \
          /opt/gastube-playback/lib/libav*.so* \
          /opt/gastube-playback/lib/libsw*.so* \
          /opt/gastube-playback/lib/libpostproc.so* \
          /opt/gastube-playback/lib/libass.so*; do
  cp -a "$so" "$bundle_dir/lib/"
  copied=1
done
shopt -u nullglob
if [[ "$copied" != 1 || ! -e "$bundle_dir/lib/libmpv.so.2" ]]; then
  echo "libmpv.so.2 was not copied into the bundle" >&2
  exit 1
fi
cp /opt/gastube-playback/share/playback-probe.mp4 "$bundle_dir/playback-probe.mp4"
# The mux step runs this binary. It is already built in the playback prefix.
# Do not rebuild FFmpeg for the copy. Libraries stay in lib/, so the run path
# is the directory next to this executable.
if [[ ! -x /opt/gastube-playback/bin/ffmpeg ]]; then
  echo "playback ffmpeg is missing" >&2
  exit 1
fi
cp -a /opt/gastube-playback/bin/ffmpeg "$bundle_dir/ffmpeg"
patchelf --set-rpath '$ORIGIN/lib' "$bundle_dir/ffmpeg"
chmod 755 "$bundle_dir/ffmpeg"
for so in "$bundle_dir"/lib/libmpv.so* \
          "$bundle_dir"/lib/libav*.so* \
          "$bundle_dir"/lib/libsw*.so* \
          "$bundle_dir"/lib/libpostproc.so* \
          "$bundle_dir"/lib/libass.so* \
          "$bundle_dir"/lib/libmedia_kit_video_plugin.so; do
  if [[ -f "$so" && ! -L "$so" ]]; then
    patchelf --set-rpath '$ORIGIN' "$so"
  fi
done
echo "copied libmpv and playback-probe.mp4 into the bundle"

# Jar and JRE sit next to the executable. The sidecar does not use the
# process working directory or the system java.
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
if [[ ! -x "${JAVA_HOME}/bin/java" ]]; then
  echo "JDK 17 is missing at ${JAVA_HOME}" >&2
  exit 1
fi
(
  cd /src/packaging/newpipe-spike
  bash ./gradlew --no-daemon jar
)
jar_src=/src/packaging/newpipe-spike/build/libs/newpipe-spike.jar
bundle_dir=$(dirname "$bundle")
cp "$jar_src" "${bundle_dir}/newpipe-spike.jar"

if [[ -d "${JAVA_HOME}/jmods" ]]; then
  bash /src/packaging/java/link-runtime.sh "${JAVA_HOME}" "${bundle_dir}/jre"
else
  echo "JDK 17 at ${JAVA_HOME} has no jmods; downloading a JDK to link the runtime" >&2
  jre_work=$(mktemp -d)
  jre_url="https://api.adoptium.net/v3/binary/latest/17/ga/linux/aarch64/jdk/hotspot/normal/eclipse?project=jdk"
  curl -fL --retry 3 -o "${jre_work}/jdk.tgz" "${jre_url}"
  mkdir -p "${jre_work}/extract"
  tar -xzf "${jre_work}/jdk.tgz" -C "${jre_work}/extract"
  jre_top=$(find "${jre_work}/extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)
  if [[ -z "${jre_top}" || ! -d "${jre_top}/jmods" ]]; then
    echo "Temurin JDK archive did not contain jmods" >&2
    exit 1
  fi
  bash /src/packaging/java/link-runtime.sh "${jre_top}" "${bundle_dir}/jre"
  rm -rf "${jre_work}"
fi
python3 - "${bundle_dir}/jre/bin/java" <<'PY'
import re, subprocess, sys
path = sys.argv[1]
text = subprocess.check_output(["readelf", "-V", path], text=True)
too_new = []
for match in re.findall(r"GLIBC_[0-9.]+", text):
    parts = tuple(int(piece) for piece in match.split("_", 1)[1].split(".") if piece)
    if parts > (2, 31):
        too_new.append(match)
if too_new:
    raise SystemExit(f"{path} needs {sorted(set(too_new))}, newer than glibc 2.31")
print(f"{path} glibc is within 2.31")
PY
"${bundle_dir}/jre/bin/java" -version

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
