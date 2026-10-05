#!/usr/bin/env bash
# Build newpipe-spike.jar and link a small JDK 17 runtime into DEST.
# DEST is the directory that contains gastube or gastube.exe.
# The JRE is Eclipse Temurin, GPL-2.0 with the Classpath Exception.
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: bundle-runtime.sh DEST" >&2
  exit 1
fi

dest="$(cd "$1" && pwd)"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Gradle 8.11.1's Kotlin parser rejects a newer launcher JVM with
# "What went wrong: <java.version>" and nothing else. ubuntu-26.04 runners
# default to Java 25 even after openjdk-17 is installed. Compile with 17,
# which is also the sidecar's toolchain and the bundled runtime.
java_major() {
  local line
  line="$("$1" -version 2>&1 | head -n 1 || true)"
  if [[ "${line}" =~ \"([0-9]+) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  fi
}

java_bin() {
  if [[ -z "$1" ]]; then
    return 0
  fi
  if [[ -x "$1/bin/java" ]]; then
    printf '%s\n' "$1/bin/java"
  elif [[ -x "$1/bin/java.exe" ]]; then
    printf '%s\n' "$1/bin/java.exe"
  fi
}

resolve_jdk17() {
  local home bin major candidate
  if [[ -n "${JAVA_HOME:-}" ]]; then
    bin="$(java_bin "${JAVA_HOME}")"
    if [[ -n "${bin}" && "$(java_major "${bin}")" == "17" ]]; then
      printf '%s\n' "${JAVA_HOME}"
      return 0
    fi
  fi
  if [[ -x /usr/libexec/java_home ]]; then
    home="$(/usr/libexec/java_home -v 17 2>/dev/null || true)"
    bin="$(java_bin "${home}")"
    if [[ -n "${bin}" && "$(java_major "${bin}")" == "17" ]]; then
      printf '%s\n' "${home}"
      return 0
    fi
  fi
  shopt -s nullglob
  for candidate in /usr/lib/jvm/java-17-openjdk-* /usr/lib/jvm/java-17-openjdk /usr/lib/jvm/temurin-17-*; do
    bin="$(java_bin "${candidate}")"
    if [[ -n "${bin}" && "$(java_major "${bin}")" == "17" ]]; then
      shopt -u nullglob
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  shopt -u nullglob
  if command -v java >/dev/null 2>&1 && [[ "$(java_major "$(command -v java)")" == "17" ]]; then
    bin="$(readlink -f "$(command -v java)")"
    dirname "$(dirname "${bin}")"
    return 0
  fi
  echo "JDK 17 is required to build the sidecar jar. Gradle 8.11.1 cannot run on the default JVM." >&2
  java -version >&2 || true
  return 1
}

jdk17="$(resolve_jdk17)"
export JAVA_HOME="${jdk17}"
export PATH="${JAVA_HOME}/bin:${PATH}"

echo "Building newpipe-spike.jar with ${JAVA_HOME}"
(
  cd "${root}/packaging/newpipe-spike"
  bash ./gradlew --no-daemon jar
)
jar_src="${root}/packaging/newpipe-spike/build/libs/newpipe-spike.jar"
if [[ ! -f "${jar_src}" ]]; then
  echo "Sidecar jar was not produced at ${jar_src}." >&2
  exit 1
fi
cp "${jar_src}" "${dest}/newpipe-spike.jar"

case "$(uname -s)" in
  Linux) os_name=linux ;;
  Darwin) os_name=mac ;;
  MINGW* | MSYS* | CYGWIN*) os_name=windows ;;
  *)
    echo "Unsupported OS $(uname -s)." >&2
    exit 1
    ;;
esac

# The Windows runner's shell is x64 even when the app is ARM64, so the
# output directory decides the runtime. host_machine is only the fallback.
case "${dest}" in
  */windows/arm64 | */windows/arm64/*) arch=aarch64 ;;
  */windows/x64 | */windows/x64/*) arch=x64 ;;
  *)
    # shellcheck disable=SC1091
    . "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/host-arch.sh"
    case "$(host_machine)" in
      x86_64 | amd64) arch=x64 ;;
      aarch64 | arm64) arch=aarch64 ;;
      *)
        echo "Unsupported CPU $(host_machine). This script bundles the x64 and aarch64 runtimes." >&2
        exit 1
        ;;
    esac
    ;;
esac
echo "Packaging Java runtime into ${dest} as ${arch}"

# CI installs a JDK 17 that matches the runner, and that JDK contains jmods.
# Download a JDK only when this machine cannot link the runtime itself.
# Temurin has no Windows ARM64 JDK 17. Microsoft Build of OpenJDK 17 does,
# and it is also GPL-2.0 with the Classpath Exception.
link_from="${JAVA_HOME}"
if [[ ! -d "${link_from}/jmods" ]]; then
  if [[ "${os_name}" == windows && "${arch}" == aarch64 ]]; then
    url="https://aka.ms/download-jdk/microsoft-jdk-17-windows-aarch64.zip"
    runtime_name="Microsoft OpenJDK 17"
  else
    url="https://api.adoptium.net/v3/binary/latest/17/ga/${os_name}/${arch}/jdk/hotspot/normal/eclipse?project=jdk"
    runtime_name="Temurin 17 JDK"
  fi
  workdir="$(mktemp -d)"
  trap 'rm -rf "${workdir}"' EXIT

  echo "Downloading ${runtime_name} for ${os_name}/${arch}"
  curl -fL --retry 3 -o "${workdir}/jdk.archive" -D "${workdir}/headers" "${url}"
  filename="$(sed -n 's/.*[Ff]ilename=\([^;]*\).*/\1/p' "${workdir}/headers" | tr -d '\r" ' | tail -n 1)"
  case "${filename}" in
    *.zip) kind=zip ;;
    *.tar.gz | *.tgz) kind=tar ;;
    *)
      if file "${workdir}/jdk.archive" | grep -q 'Zip archive'; then
        kind=zip
      else
        kind=tar
      fi
      ;;
  esac

  mkdir -p "${workdir}/extract"
  if [[ "${kind}" == zip ]]; then
    if command -v unzip >/dev/null 2>&1; then
      unzip -q "${workdir}/jdk.archive" -d "${workdir}/extract"
    else
      tar -xf "${workdir}/jdk.archive" -C "${workdir}/extract"
    fi
  else
    tar -xzf "${workdir}/jdk.archive" -C "${workdir}/extract"
  fi

  link_from="$(find "${workdir}/extract" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  if [[ -z "${link_from}" || ! -d "${link_from}/jmods" ]]; then
    echo "JDK archive did not contain jmods." >&2
    exit 1
  fi
fi

bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/link-runtime.sh" "${link_from}" "${dest}/jre"

java_bin="${dest}/jre/bin/java"
if [[ -f "${dest}/jre/bin/java.exe" ]]; then
  java_bin="${dest}/jre/bin/java.exe"
fi
if [[ ! -x "${java_bin}" && ! -f "${java_bin}" ]]; then
  echo "Bundled runtime is missing ${java_bin}." >&2
  exit 1
fi
"${java_bin}" -version
echo "Installed ${dest}/newpipe-spike.jar and ${dest}/jre"
