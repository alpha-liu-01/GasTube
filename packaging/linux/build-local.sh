#!/usr/bin/env bash
# Install this distro's packages, pin Flutter 3.47.1, build the release
# bundle, then write the native package for Debian, Fedora, or Arch.
# Package lists and filenames are in BUILD.md.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
required_flutter="3.47.1"
install_deps=0

for arg in "$@"; do
  case "${arg}" in
    --install-deps) install_deps=1 ;;
    *)
      echo "usage: build-local.sh [--install-deps]" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f /etc/os-release ]]; then
  echo "No /etc/os-release. Install the packages in packaging/linux/BUILD.md and re-run." >&2
  exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release

family=""
distro_id="${ID:-}"
like=" ${ID_LIKE:-} "
case "${distro_id}" in
  debian | ubuntu | linuxmint | pop) family=debian ;;
  fedora | rhel | centos | nobara | rocky | almalinux) family=redhat ;;
  arch | cachyos | endeavouros | manjaro) family=arch ;;
esac
if [[ -z "${family}" ]]; then
  if [[ "${like}" == *" debian "* ]]; then
    family=debian
  elif [[ "${like}" == *" fedora "* || "${like}" == *" rhel "* ]]; then
    family=redhat
  elif [[ "${like}" == *" arch "* ]]; then
    family=arch
  fi
fi

debian_packages=(
  clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libmpv-dev
  curl git unzip xz-utils zip make gcc openjdk-17-jdk-headless ca-certificates
  dpkg-dev
)
redhat_packages=(
  clang cmake ninja-build pkgconf gtk3-devel xz-devel mpv-devel
  curl git unzip xz zip make gcc java-17-openjdk-devel
  rpm-build
)
arch_packages=(
  clang cmake ninja pkgconf gtk3 xz mpv
  curl git unzip zip make gcc jdk17-openjdk
  base-devel
)

print_install() {
  case "${family}" in
    debian)
      echo "sudo apt-get update && sudo apt-get install -y --no-install-recommends ${debian_packages[*]}"
      ;;
    redhat)
      echo "sudo dnf install -y ${redhat_packages[*]}"
      ;;
    arch)
      echo "sudo pacman -S --needed --noconfirm ${arch_packages[*]}"
      ;;
  esac
}

if [[ -z "${family}" ]]; then
  echo "Unknown distro ${distro_id:-unset}. Install the packages in packaging/linux/BUILD.md and re-run." >&2
  exit 1
fi

install_temurin_17() {
  local arch archive dest
  case "$(uname -m)" in
    x86_64 | amd64) arch=x64 ;;
    aarch64 | arm64) arch=aarch64 ;;
    *)
      echo "No Temurin 17 build for $(uname -m)." >&2
      return 1
      ;;
  esac
  if compgen -G "/usr/lib/jvm/temurin-17-*" >/dev/null || compgen -G "/usr/lib/jvm/java-17-openjdk*" >/dev/null; then
    return 0
  fi
  echo "Installing Eclipse Temurin JDK 17"
  archive="$(mktemp)"
  curl -fL --retry 3 -o "${archive}" \
    "https://api.adoptium.net/v3/binary/latest/17/ga/linux/${arch}/jdk/hotspot/normal/eclipse?project=jdk"
  sudo mkdir -p /usr/lib/jvm
  sudo tar -C /usr/lib/jvm -xf "${archive}"
  rm -f "${archive}"
  dest="$(echo /usr/lib/jvm/jdk-17*)"
  sudo ln -sfn "${dest}" /usr/lib/jvm/temurin-17-jdk
}

if [[ "${install_deps}" -eq 1 ]]; then
  case "${family}" in
    debian)
      sudo apt-get update
      debian_install=("${debian_packages[@]}")
      if ! apt-cache show openjdk-17-jdk-headless >/dev/null 2>&1; then
        debian_install=()
        for pkg in "${debian_packages[@]}"; do
          if [[ "${pkg}" != openjdk-17-jdk-headless ]]; then
            debian_install+=("${pkg}")
          fi
        done
      fi
      sudo apt-get install -y --no-install-recommends "${debian_install[@]}"
      ;;
    redhat)
      sudo dnf install -y "${redhat_packages[@]}"
      ;;
    arch)
      sudo pacman -S --needed --noconfirm "${arch_packages[@]}"
      ;;
  esac
  install_temurin_17
else
  missing=0
  for cmd in clang cmake ninja make gcc curl git unzip; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      echo "Missing command: ${cmd}" >&2
      missing=1
    fi
  done
  if ! command -v pkg-config >/dev/null 2>&1; then
    echo "Missing command: pkg-config" >&2
    missing=1
  else
    for module in gtk+-3.0 mpv liblzma; do
      if ! pkg-config --exists "${module}"; then
        echo "Missing pkg-config module: ${module}" >&2
        missing=1
      fi
    done
  fi
  has_jdk17=0
  if command -v java >/dev/null 2>&1; then
    java_line="$(java -version 2>&1 | head -n 1 || true)"
    if [[ "${java_line}" =~ \"17 ]]; then
      has_jdk17=1
    fi
  fi
  if [[ "${has_jdk17}" -eq 0 ]]; then
    shopt -s nullglob
    for candidate in /usr/lib/jvm/java-17-openjdk-* /usr/lib/jvm/java-17-openjdk /usr/lib/jvm/temurin-17-*; do
      if [[ -x "${candidate}/bin/java" ]]; then
        has_jdk17=1
      fi
    done
    shopt -u nullglob
  fi
  if [[ "${has_jdk17}" -eq 0 ]]; then
    echo "Missing JDK 17" >&2
    missing=1
  fi
  if [[ "${missing}" -eq 1 ]]; then
    echo "Install the ${family} packages, then re-run:" >&2
    echo "  bash packaging/linux/build-local.sh --install-deps" >&2
    print_install >&2
    exit 1
  fi
fi

if command -v flutter >/dev/null 2>&1; then
  actual_flutter="$(flutter --version | awk '/^Flutter / {print $2; exit}')"
  if [[ "${actual_flutter}" != "${required_flutter}" ]]; then
    echo "Flutter on PATH is ${actual_flutter:-unknown}. Using the pinned ${required_flutter} SDK." >&2
  fi
else
  actual_flutter=""
fi

if [[ "${actual_flutter}" != "${required_flutter}" ]]; then
  cache="${HOME}/.cache/fluxtube/flutter"
  sdk="${cache}/flutter"
  cached=""
  if [[ -x "${sdk}/bin/flutter" ]]; then
    cached="$("${sdk}/bin/flutter" --version | awk '/^Flutter / {print $2; exit}')"
  fi
  if [[ "${cached}" != "${required_flutter}" ]]; then
    mkdir -p "${cache}"
    rm -rf "${sdk}"
    case "$(uname -m)" in
      aarch64 | arm64)
        echo "Cloning Flutter ${required_flutter} (no official Linux ARM64 tarball)"
        git clone --depth 1 --branch "${required_flutter}" https://github.com/flutter/flutter.git "${sdk}"
        ;;
      *)
        archive="$(mktemp)"
        echo "Downloading Flutter ${required_flutter}"
        curl -fL --retry 3 -o "${archive}" \
          "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${required_flutter}-stable.tar.xz"
        tar -C "${cache}" -xf "${archive}"
        rm -f "${archive}"
        ;;
    esac
  fi
  export PATH="${sdk}/bin:${PATH}"
fi

"${root}/packaging/linux/build-release.sh"
"${root}/packaging/linux/package-native.sh"
