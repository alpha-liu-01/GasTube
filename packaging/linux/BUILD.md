# Local Linux package

One command detects Debian, Fedora, or Arch, installs that family's build packages when asked, pins Flutter 3.47.1, and writes both the release archive and the native package for this machine:

```bash
bash packaging/linux/build-local.sh --install-deps
```

Omit `--install-deps` when the packages below are already installed. The script then only checks for them and builds. An unknown distro stops and prints the package list for the closest family.

The archive is `dist/gastube-<version>-linux-x64.tar.gz` or `dist/gastube-<version>-linux-arm64.tar.gz`. The package is:

| Family | File | Runtime dependencies |
| --- | --- | --- |
| Debian, Ubuntu, Mint, Pop | `dist/gastube_<version>_amd64.deb` or `_arm64.deb` | `libgtk-3-0`, `libmpv2` or `libmpv1` |
| Fedora, RHEL, Nobara, Rocky, Alma | `dist/gastube-<upstream>-<release>.x86_64.rpm` or `.aarch64.rpm` | `gtk3`, `mpv-libs` |
| Arch, CachyOS, EndeavourOS, Manjaro | `dist/gastube-<upstream>-<release>-x86_64.pkg.tar.zst` or `-aarch64.pkg.tar.zst` | `gtk3`, `mpv` |

`0.9.3+14` becomes upstream `0.9.3` and release `14` for the rpm and Arch package. Installing any of them puts the app in `/opt/gastube`, links `/usr/bin/gastube`, and installs a desktop file plus the hicolor icons, so a desktop shell can launch it. libmpv stays a distro package. The archive and the native package both include a JDK 17 runtime and a static GPL ffmpeg.

Flutter is not installed from the distro. On x64 the script downloads the official 3.47.1 Linux tarball. On aarch64 there is no such tarball, so it clones the `3.47.1` tag into `~/.cache/fluxtube/flutter/flutter`. The release tree is `build/linux/x64/release/bundle` or `build/linux/arm64/release/bundle`. It does not cross-compile.

The sidecar needs JDK 17. Gradle 8.11.1 cannot run on a newer default JVM. Fedora and Arch install `java-17-openjdk-devel` or `jdk17-openjdk`. Debian 13 has no `openjdk-17-jdk-headless` package, so after the apt install the script downloads Eclipse Temurin 17 into `/usr/lib/jvm/temurin-17-jdk`. The same download runs on Fedora or Arch if their JDK 17 package did not land. The copy inside the package is a jlink runtime made from that JDK 17, plus the BtbN GPL ffmpeg from autobuild `2026-09-22-13-18` (`linux64` or `linuxarm64`).

The Linux `volume_controller` plugin in that package is the vendored 3.6.0 tree. It looks for an ALSA playback element named `Master`, then `PCM`, `Speaker`, `Headphone`, `Digital`, and `Playback`, then any element that has a playback volume. If the card has none, volume calls return an error instead of crashing, and mpv keeps its own volume.

## Debian, Ubuntu, and other apt distros

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libmpv-dev \
  curl git unzip xz-utils zip make openjdk-17-jdk-headless ca-certificates \
  dpkg-dev
```

## Fedora, RHEL, and other dnf distros

```bash
sudo dnf install -y \
  clang cmake ninja-build pkgconf gtk3-devel xz-devel mpv-devel \
  curl git unzip xz zip make java-17-openjdk-devel \
  rpm-build
```

## Arch, CachyOS, EndeavourOS, and Manjaro

```bash
sudo pacman -S --needed --noconfirm \
  clang cmake ninja pkgconf gtk3 xz mpv \
  curl git unzip zip make jdk17-openjdk \
  base-devel
```
