#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${OUT_DIR:-"$ROOT/build"}
LIMINE_DIR=${LIMINE_DIR:-}
LIMINE_VERSION=12.9.6
ZIG_VERSION=0.17.0
ZIG=${ZIG:-zig}
CLANG=${CLANG:-clang}
XORRISO=${XORRISO:-xorriso}
QEMU=${QEMU:-qemu-system-x86_64}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required tool: $1" >&2
    exit 1
  }
}

need "$ZIG"
"$ZIG" version | grep -Fqx "$ZIG_VERSION" || {
  echo "expected Zig $ZIG_VERSION" >&2
  exit 1
}
need "$CLANG"
need "$XORRISO"
need "$QEMU"
[ -n "$LIMINE_DIR" ] || { echo "set LIMINE_DIR to a Limine release directory" >&2; exit 1; }
[ -x "$LIMINE_DIR/limine" ] || { echo "missing executable $LIMINE_DIR/limine" >&2; exit 1; }
"$LIMINE_DIR/limine" --version | grep -Fqx "Limine $LIMINE_VERSION" || {
  echo "expected Limine $LIMINE_VERSION in LIMINE_DIR" >&2
  exit 1
}
[ -f "$LIMINE_DIR/limine-bios.sys" ] || { echo "missing $LIMINE_DIR/limine-bios.sys" >&2; exit 1; }
[ -f "$LIMINE_DIR/limine-bios-cd.bin" ] || { echo "missing $LIMINE_DIR/limine-bios-cd.bin" >&2; exit 1; }
[ -f "$LIMINE_DIR/limine-uefi-cd.bin" ] || { echo "missing $LIMINE_DIR/limine-uefi-cd.bin" >&2; exit 1; }

mkdir -p "$OUT/iso_root/boot"
"$CLANG" --target=x86_64-none-elf -c "$ROOT/kratos/kernel/entry.S" \
  -o "$OUT/entry.o"
"$CLANG" --target=x86_64-none-elf -c "$ROOT/kratos/kernel/interrupts.S" \
  -o "$OUT/interrupts.o"
"$ZIG" build-exe "$ROOT/kratos/kernel/kernel.zig" "$OUT/entry.o" "$OUT/interrupts.o" \
  -target x86_64-freestanding -O ReleaseSmall -fno-entry -mcmodel=kernel \
  -mno-red-zone -T "$ROOT/kratos/kernel/linker.ld" \
  -femit-bin="$OUT/kratos.elf"

cp "$OUT/kratos.elf" "$OUT/iso_root/boot/kratos.elf"
cp "$ROOT/kratos/limine.conf" "$OUT/iso_root/limine.conf"
cp "$LIMINE_DIR/limine-bios.sys" "$LIMINE_DIR/limine-bios-cd.bin" \
  "$LIMINE_DIR/limine-uefi-cd.bin" "$OUT/iso_root/"
"$XORRISO" -as mkisofs -b limine-bios-cd.bin -no-emul-boot \
  -boot-load-size 4 -boot-info-table --efi-boot limine-uefi-cd.bin \
  -efi-boot-part --efi-boot-image --protective-msdos-label \
  "$OUT/iso_root" -o "$OUT/kratos.iso"
"$LIMINE_DIR/limine" bios-install "$OUT/kratos.iso"

if [ "${1:-}" = "--build-only" ]; then
  echo "built $OUT/kratos.iso"
  exit 0
fi
exec "$QEMU" -M q35 -m 256M -cdrom "$OUT/kratos.iso" -boot order=d \
  -serial stdio -display "${QEMU_DISPLAY:-default}" -no-reboot -no-shutdown
