#!/bin/bash
# Checks the prebuilt arm64 bundle against the OnePlus 6T's Focal libraries.
set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
app="$root/bundle/gastube"
engine="$root/bundle/lib/libflutter_linux_gtk.so"
icu="$root/bundle/data/icudtl.dat"

test -x "$app"
test -f "$engine"
test -f "$icu"
test -f "$root/bundle/newpipe-spike.jar"
test -x "$root/bundle/jre/bin/java"

python3 - "$root/bundle" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

bundle = Path(sys.argv[1])
max_glibc = (2, 31)
max_glibcxx = (3, 4, 28)
max_cxxabi = (1, 3, 12)
paths = [bundle / "gastube", bundle / "ffmpeg", bundle / "jre" / "bin" / "java"]
paths.extend(sorted((bundle / "lib").glob("*.so")))
paths.extend(sorted(path for path in (bundle / "lib").glob("*.so.*") if not path.is_symlink()))
paths.extend(sorted((bundle / "jre").rglob("*.so")))
probe = bundle / "playback-probe.mp4"
if not probe.is_file() or probe.stat().st_size < 1000:
    raise SystemExit("playback-probe.mp4 is missing")
if not (bundle / "lib" / "libmpv.so.2").exists():
    raise SystemExit("bundled libmpv.so.2 is missing")
ffmpeg = bundle / "ffmpeg"
if not ffmpeg.is_file():
    raise SystemExit("bundled ffmpeg is missing")

def version_tuples(text, prefix):
    found = []
    for match in re.findall(re.escape(prefix) + r"[0-9.]+", text):
        parts = tuple(int(piece) for piece in match[len(prefix):].split(".") if piece)
        found.append((match, parts))
    return found

def needed(dynamic):
    names = []
    for line in dynamic.splitlines():
        if "NEEDED" in line:
            names.append(line.split("[", 1)[1].split("]", 1)[0])
    return names

plugin_links_mpv = False
for path in paths:
    header = subprocess.check_output(["readelf", "-h", str(path)], text=True)
    dynamic = subprocess.check_output(["readelf", "-d", str(path)], text=True)
    versions = subprocess.check_output(["readelf", "-V", str(path)], text=True)
    print(f"== {path.name}")
    libs = needed(dynamic)
    print("NEEDED:", ", ".join(libs))
    if "/home/" in dynamic or "/opt/" in dynamic or "x86_64" in dynamic:
        raise SystemExit(f"{path} has a host absolute library path")
    if path.name == "ffmpeg" and "$ORIGIN/lib" not in dynamic:
        raise SystemExit(f"{path} run path is not $ORIGIN/lib")
    if "AArch64" not in header:
        raise SystemExit(f"{path} is not an AArch64 ELF")
    if path.name == "libmedia_kit_video_plugin.so" and any(
        name.startswith("libmpv") for name in libs
    ):
        plugin_links_mpv = True
    for label, value in version_tuples(versions, "GLIBC_"):
        if value > max_glibc:
            raise SystemExit(f"{path} needs {label}, newer than glibc 2.31")
    for label, value in version_tuples(versions, "GLIBCXX_"):
        if value > max_glibcxx:
            raise SystemExit(f"{path} needs {label}, newer than GLIBCXX_3.4.28")
    for label, value in version_tuples(versions, "CXXABI_"):
        if value > max_cxxabi:
            raise SystemExit(f"{path} needs {label}, newer than CXXABI_1.3.12")

if not plugin_links_mpv:
    raise SystemExit("media_kit video plugin does not link libmpv")

print("bundle matches Focal glibc 2.31 and includes libmpv")
PY
