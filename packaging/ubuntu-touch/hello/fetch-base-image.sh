#!/bin/bash
# Downloads the public Ubuntu 20.04 arm64 rootfs without Docker's keychain
# credential helper. Non-interactive SSH on macOS cannot unlock the login
# keychain, so `docker pull` fails even for a public image.
set -euo pipefail

export PATH="/Applications/Docker.app/Contents/Resources/bin:${PATH:-}"

if docker image inspect ubuntu:20.04 >/dev/null 2>&1; then
  arch=$(docker image inspect ubuntu:20.04 --format '{{.Architecture}}')
  if [[ "$arch" == "arm64" ]]; then
    exit 0
  fi
  echo "ubuntu:20.04 exists but architecture is $arch" >&2
  exit 1
fi

index_digest=sha256:722ea796ac2d57eeb3627c58a582fc1acc58be51faf815e1bce1682ae5c092f7
token=$(curl -fsSL "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/ubuntu:pull")
token=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["token"])' "$token")
manifest=$(curl -fsSL \
  -H "Authorization: Bearer $token" \
  -H "Accept: application/vnd.oci.image.manifest.v1+json" \
  "https://registry-1.docker.io/v2/library/ubuntu/manifests/$index_digest")
layer=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["layers"][0]["digest"])' "$manifest")
archive=/tmp/ubuntu-20.04-arm64.tar.gz
curl -fL --retry 3 \
  -H "Authorization: Bearer $token" \
  -o "$archive" \
  "https://registry-1.docker.io/v2/library/ubuntu/blobs/$layer"
gunzip -c "$archive" | docker import - ubuntu:20.04
rm -f "$archive"
docker image inspect ubuntu:20.04 --format '{{.Os}}/{{.Architecture}} {{.Size}}'
