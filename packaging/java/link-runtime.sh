#!/usr/bin/env bash
# Build the sidecar runtime from a JDK 17 that contains jmods.
# A JRE archive has no jmods, so jlink cannot start from one.
# usage: link-runtime.sh JDK_HOME OUTPUT
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: link-runtime.sh JDK_HOME OUTPUT" >&2
  exit 1
fi

jdk="$1"
out="$2"

if [[ ! -d "${jdk}/jmods" ]]; then
  echo "JDK at ${jdk} has no jmods directory. jlink needs a JDK, not a JRE." >&2
  exit 1
fi

jlink="${jdk}/bin/jlink"
if [[ -f "${jdk}/bin/jlink.exe" ]]; then
  jlink="${jdk}/bin/jlink.exe"
fi

# jdeps of newpipe-spike.jar, plus jdk.crypto.ec.
# Without the EC provider, YouTube TLS fails with handshake_failure.
modules="java.base,java.compiler,java.desktop,java.net.http,java.scripting,java.sql,jdk.crypto.ec,jdk.dynalink,jdk.unsupported"

rm -rf "${out}"
"${jlink}" \
  --module-path "${jdk}/jmods" \
  --add-modules "${modules}" \
  --strip-debug \
  --no-man-pages \
  --no-header-files \
  --output "${out}"
