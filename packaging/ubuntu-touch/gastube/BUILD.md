# Ubuntu Touch builds

The build installed on the phone is a **release** build. `packaging/ubuntu-touch/gastube/build-arm64.sh` runs `flutter build linux --release`. The `libflutter_linux_gtk.so` copied into the Click is built with `--runtime-mode release`.

A release package contains `lib/libapp.so`, which holds the Dart AOT snapshot (`_kDartSnapshotData`). It does not contain `data/flutter_assets/kernel_blob.bin`. The tree installed on the OnePlus 6T on 2026-10-05, `/opt/click.ubuntu.com/gastube.alphaliu01/0.9.3/`, has that layout. `libapp.so` is about 14 MB.

A Flutter debug build is JIT. It ships `kernel_blob.bin` and needs a `libflutter_linux_gtk.so` built with `--runtime-mode debug`. The engine in this repository is a release engine. A debug app and this engine cannot be installed together. `clickable build --debug` only changes the outer CMake build. It does not recompile an existing release bundle as debug. On the phone, use the debug page in Settings inside the release package. `debugPrint` output goes to that page.

The arm64 Flutter bundle is compiled inside an Ubuntu 20.04 container. The host that starts that container is arm64. An x64 machine does not cross-compile it with `flutter build linux --target-platform linux-arm64`.

## Release from GitHub Actions

The workflow [Ubuntu Touch Click](../../../.github/workflows/ubuntu-touch-click.yml) is the build that does not use a private machine. Open Actions, choose Ubuntu Touch Click, and run it. The runner is `ubuntu-24.04-arm`. Compilation stays in the Ubuntu 20.04 image `gastube-flutter-focal-ut:20.04`, so the Click remains within glibc 2.31. The finished file is the `gastube-ubuntu-touch-arm64` artifact.

The same two steps, on any arm64 machine with Docker and Clickable:

```bash
bash packaging/ubuntu-touch/gastube/container-build.sh
cd packaging/ubuntu-touch/gastube
clickable build --skip-review --arch arm64 --non-interactive --no-nvidia
```

`container-build.sh` refuses to run when the host is not arm64. The release engine library checked into `packaging/ubuntu-touch/engine-partial/libflutter_linux_gtk.so` is required. FFmpeg, libmpv, the jar, and the jlink runtime are built in the container. The playback stamp is `ffmpeg-6.1.1-vp9-hybris libass-0.17.3 mpv-0.35.1`.

## Release on the maintainer machine

From the repository root:

```bash
bash packaging/ubuntu-touch/gastube/remote-build.sh
```

The script syncs the tree to `alpha@10.0.0.118`, runs `build-arm64.sh` in the `gastube-flutter-focal-ut:20.04` container, pulls `dist/bundle` back, and runs `check-bundle.sh`. The playback stamp is `ffmpeg-6.1.1-vp9-hybris libass-0.17.3 mpv-0.35.1`. FFmpeg and libmpv are left in place when that stamp is unchanged. The container requires `packaging/ubuntu-touch/engine-partial/libflutter_linux_gtk.so` to already exist.

Then:

```bash
cd packaging/ubuntu-touch/gastube
clickable build --skip-review --arch arm64
```

The Click is written to:

```text
packaging/ubuntu-touch/gastube/build/aarch64-linux-gnu/app/gastube.alphaliu01_0.9.3_arm64.click
```

The version comes from `version` in `manifest.json.in`. The framework is `ubuntu-sdk-20.04` and the architecture is arm64. This file can be installed on a phone or uploaded to the OpenStore.

The two commands above produced a 56 MB package on 2026-10-05. The package contains `lib/libapp.so` and does not contain `kernel_blob.bin`. That package was not installed on the phone. The 6T still has the earlier `0.9.3` release.

Install onto a connected phone:

```bash
cd packaging/ubuntu-touch/gastube
clickable install --arch arm64
```

Leave off `--skip-uninstall`. The install replaces the Click of the same name already on the phone.

Before packaging, confirm the bundle is still a release build:

```bash
test -f packaging/ubuntu-touch/gastube/bundle/lib/libapp.so
test ! -e packaging/ubuntu-touch/gastube/bundle/data/flutter_assets/kernel_blob.bin
```

## Debug

There is no installable debug Click. A Flutter debug build needs a separate `libflutter_linux_gtk.so` built with `--runtime-mode debug`, and `flutter build linux --release` in `build-arm64.sh` changed to `--debug`. That debug engine is not in the tree, and it is not part of the release packaging flow.
