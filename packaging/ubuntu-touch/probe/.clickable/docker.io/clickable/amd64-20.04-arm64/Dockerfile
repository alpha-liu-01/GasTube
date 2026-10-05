FROM docker.io/clickable/amd64-20.04-arm64
LABEL base_image_hash="sha256:8cfcaabc63c71fa27e130f4c8ea4079d59a99fb6eeab521f8ebcd674508c9a94"
ARG GOPATH="/home/alpha/.clickable/go"
ARG SDK_FRAMEWORK="ubuntu-sdk-20.04"
ARG CLICK_FRAMEWORK="ubuntu-sdk-20.04"
ARG CLICK_FRAMEWORK_BASE="20.04"
ARG APPARMOR_POLICY="20.04"
ARG QT_VERSION="5.12"
ARG ARCH="arm64"
ARG ARCH_TRIPLET="aarch64-linux-gnu"
ARG ARCH_RUST="aarch64-unknown-linux-gnu"
ARG NUM_PROCS="56"
ARG ROOT="/home/alpha/Documents/GitHub/FluxTube/packaging/ubuntu-touch/probe"
ARG BUILD_DIR="/home/alpha/Documents/GitHub/FluxTube/packaging/ubuntu-touch/probe/build/aarch64-linux-gnu/app"
ARG SRC_DIR="/home/alpha/Documents/GitHub/FluxTube/packaging/ubuntu-touch/probe"
ARG INSTALL_DIR="/home/alpha/Documents/GitHub/FluxTube/packaging/ubuntu-touch/probe/build/aarch64-linux-gnu/app/install"
ARG CLICK_LD_LIBRARY_PATH="/home/alpha/Documents/GitHub/FluxTube/packaging/ubuntu-touch/probe/build/aarch64-linux-gnu/app/install/lib/aarch64-linux-gnu"
ARG CLICK_PATH="/home/alpha/Documents/GitHub/FluxTube/packaging/ubuntu-touch/probe/build/aarch64-linux-gnu/app/install/lib/aarch64-linux-gnu/bin"
ARG CLICK_QML2_IMPORT_PATH="/home/alpha/Documents/GitHub/FluxTube/packaging/ubuntu-touch/probe/build/aarch64-linux-gnu/app/install/lib/aarch64-linux-gnu"

RUN echo set debconf/frontend Noninteractive | debconf-communicate && echo set debconf/priority critical | debconf-communicate
RUN apt-get update && apt-get install -y --force-yes --no-install-recommends libgtk-3-dev:arm64 libegl1-mesa-dev:arm64 libgles2-mesa-dev:arm64 && apt-get clean