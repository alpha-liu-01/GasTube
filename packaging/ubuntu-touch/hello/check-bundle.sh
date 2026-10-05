#!/bin/bash
# Checks the prebuilt arm64 bundle against the OnePlus 6T's Focal libraries.
set -euo pipefail

root=$(cd "$(dirname "$0")" && pwd)
hello="$root/bundle/hello"
engine="$root/bundle/lib/libflutter_linux_gtk.so"
icu="$root/bundle/data/icudtl.dat"

test -x "$hello"
test -f "$engine"
test -f "$icu"

python3 - "$hello" "$engine" <<'PY'
import re
import subprocess
import sys

hello, engine = sys.argv[1:]
max_glibc = (2, 31)
max_glibcxx = (3, 4, 28)
max_cxxabi = (1, 3, 12)

def version_tuples(text, prefix):
    found = []
    for match in re.findall(re.escape(prefix) + r"[0-9.]+", text):
        parts = tuple(int(piece) for piece in match[len(prefix):].split(".") if piece)
        found.append((match, parts))
    return found

def show(path):
    header = subprocess.check_output(["readelf", "-h", path], text=True)
    dynamic = subprocess.check_output(["readelf", "-d", path], text=True)
    versions = subprocess.check_output(["readelf", "-V", path], text=True)
    print(f"== {path}")
    for line in header.splitlines():
        if "Machine:" in line or "Class:" in line:
            print(line.strip())
    for line in dynamic.splitlines():
        if "NEEDED" in line or "RPATH" in line or "RUNPATH" in line:
            print(line.strip())
    if "/home/" in dynamic or "x86_64" in dynamic:
        raise SystemExit(f"{path} has a host absolute library path")
    if "AArch64" not in header:
        raise SystemExit(f"{path} is not an AArch64 ELF")
    for label, value in version_tuples(versions, "GLIBC_"):
        if value > max_glibc:
            raise SystemExit(f"{path} needs {label}, newer than glibc 2.31")
    for label, value in version_tuples(versions, "GLIBCXX_"):
        if value > max_glibcxx:
            raise SystemExit(f"{path} needs {label}, newer than GLIBCXX_3.4.28")
    for label, value in version_tuples(versions, "CXXABI_"):
        if value > max_cxxabi:
            raise SystemExit(f"{path} needs {label}, newer than CXXABI_1.3.12")
    glibc = sorted({label for label, _ in version_tuples(versions, "GLIBC_")})
    glibcxx = sorted({label for label, _ in version_tuples(versions, "GLIBCXX_")})
    print("GLIBC:", ", ".join(glibc) or "(none)")
    print("GLIBCXX:", ", ".join(glibcxx) or "(none)")

show(hello)
show(engine)
print("bundle matches Focal glibc 2.31 and libstdc++ 10")
PY
