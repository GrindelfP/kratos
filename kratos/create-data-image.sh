#!/bin/sh
set -eu

IMAGE=${1:-kratos-data.img}
SIZE=${2:-64M}
QEMU_IMG=${QEMU_IMG:-qemu-img}

command -v "$QEMU_IMG" >/dev/null 2>&1 || {
  echo "missing required tool: $QEMU_IMG" >&2
  exit 1
}
[ ! -e "$IMAGE" ] || {
  echo "refusing to overwrite existing data image: $IMAGE" >&2
  exit 1
}
"$QEMU_IMG" create -f raw "$IMAGE" "$SIZE"
echo "created blank raw data image: $IMAGE"
