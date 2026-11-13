#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OUT=${OUT_DIR:-"$ROOT/build"}
LIMINE_DIR=${LIMINE_DIR:-}
LIMINE_VERSION=12.9.6
ZIG_VERSION=0.17.0
ZIG=${ZIG:-zig}
CLANG=${CLANG:-clang}
OBJCOPY=${OBJCOPY:-objcopy}
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
need "$OBJCOPY"
need "$XORRISO"
need "$QEMU"
need python3
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
case ${KRATOS_TEST_USER:-hello} in
  hello) USER_SOURCE="$ROOT/kratos/user/hello.S"; TEST_DEFINE=0 ;;
  syscalls) USER_SOURCE="$ROOT/kratos/user/verification.S"; TEST_DEFINE=1 ;;
  ud) USER_SOURCE="$ROOT/kratos/user/verification.S"; TEST_DEFINE=2 ;;
  kernel-read) USER_SOURCE="$ROOT/kratos/user/verification.S"; TEST_DEFINE=3 ;;
  code-write) USER_SOURCE="$ROOT/kratos/user/verification.S"; TEST_DEFINE=4 ;;
  data-execute) USER_SOURCE="$ROOT/kratos/user/verification.S"; TEST_DEFINE=5 ;;
  *) echo "unknown KRATOS_TEST_USER fixture" >&2; exit 1 ;;
esac
"$CLANG" --target=x86_64-none-elf -DTEST_CASE="$TEST_DEFINE" -c "$USER_SOURCE" -o "$OUT/hello.o"
"$OBJCOPY" -O binary -j .text "$OUT/hello.o" "$OUT/hello.kru"
# Package the normal program even when a boundary-test fixture is selected.
"$CLANG" --target=x86_64-none-elf -DTEST_CASE=0 -c "$ROOT/kratos/user/hello.S" -o "$OUT/package-hello.o"
"$OBJCOPY" -O binary -j .text "$OUT/package-hello.o" "$OUT/package-hello.kru"
mkdir -p "$OUT/system-tree/boot" "$OUT/system-tree/packages/hello" "$OUT/system-tree/policy"
cp "$OUT/package-hello.kru" "$OUT/system-tree/packages/hello/program"
cp "$ROOT/kratos/user/package-message.txt" "$OUT/system-tree/packages/hello/message"
if [ "${KRATOS_TEST_BLOCK:-0}" = 1 ]; then
  : > "$OUT/system-tree/policy/blocktest"
  SYSTEM_TYPES="$OUT/system-types-blocktest.json"
  cp "$ROOT/kratos/user/system-types.json" "$SYSTEM_TYPES"
  python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["policy/blocktest"]="opaque"; json.dump(d,open(p,"w"))' "$SYSTEM_TYPES"
else
  SYSTEM_TYPES="$ROOT/kratos/user/system-types.json"
fi
if [ "${KRATOS_TEST_SYSTEM_IMAGE:-normal}" = "malformed-program" ]; then
  printf 'BAD KRU1 payload' > "$OUT/system-tree/packages/hello/program"
fi
python3 "$ROOT/kratos/tools/build-system-image.py" "$OUT/system-tree" "$SYSTEM_TYPES" "$OUT/system.img"
python3 "$ROOT/kratos/tools/validate-system-image.py" "$OUT/system.img"
case ${KRATOS_TEST_SYSTEM_IMAGE:-normal} in
  normal|malformed-program) ;;
  malformed) printf '\002' | dd of="$OUT/system.img" bs=1 seek=8 conv=notrunc 2>/dev/null ;;
  *) echo "unknown KRATOS_TEST_SYSTEM_IMAGE fixture" >&2; exit 1 ;;
esac
cp "$OUT/system.img" "$OUT/iso_root/boot/system.img"
"$CLANG" --target=x86_64-none-elf -c "$ROOT/kratos/kernel/entry.S" \
  -o "$OUT/entry.o"
"$CLANG" --target=x86_64-none-elf -c "$ROOT/kratos/kernel/interrupts.S" \
  -o "$OUT/interrupts.o"
"$CLANG" --target=x86_64-none-elf -c "$ROOT/kratos/kernel/user_entry.S" \
  -o "$OUT/user_entry.o"
"$ZIG" build-exe "$ROOT/kratos/kernel/kernel.zig" "$OUT/entry.o" "$OUT/interrupts.o" "$OUT/user_entry.o" \
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
if [ -n "${KRATOS_DATA_IMAGE:-}" ]; then
  [ -f "$KRATOS_DATA_IMAGE" ] || { echo "data image does not exist: $KRATOS_DATA_IMAGE" >&2; exit 1; }
  exec "$QEMU" -M q35 -m 256M -cdrom "$OUT/kratos.iso" -boot order=d \
    -device piix3-ide,id=kratos-ide \
    -drive if=none,id=kratos-data,file="$KRATOS_DATA_IMAGE",format=raw \
    -device ide-hd,drive=kratos-data,bus=kratos-ide.0 \
    -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
    -serial stdio -display "${QEMU_DISPLAY:-default}" -no-reboot
fi
exec "$QEMU" -M q35 -m 256M -cdrom "$OUT/kratos.iso" -boot order=d \
  -device isa-debug-exit,iobase=0xf4,iosize=0x04 \
  -serial stdio -display "${QEMU_DISPLAY:-default}" -no-reboot
