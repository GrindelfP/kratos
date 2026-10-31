# Kernel boundaries and QEMU debug loop

This document describes the current x86_64 prototype, not a promise about the
eventual architecture or bootloader. The implementation's exact build and run
commands are maintained in [QEMU boot](qemu-boot.md); keep that guide as the
command source of truth.

## Boot-to-kernel boundary

The prototype uses Limine's x86-64 boot protocol to load a freestanding ELF
kernel from an ISO image. The bootloader owns firmware and loading; the kernel
begins at its declared ELF entry point under the protocol's 64-bit handoff
contract. It is not a BIOS boot sector and does not perform its own firmware
mode transition.

The kernel must treat the protocol as an explicit ABI: consume only requested
and validated boot responses, establish its own interrupt handling before
enabling interrupts, and never return from the entry path. In particular,
memory-map data and other responses must be used according to their lifetime
and not assumed permanent after bootloader-reclaimable memory is reclaimed.
See [the boot-path decision](boot-path.md#kernel-handoff-contract) and the
[Limine protocol specification](https://github.com/Limine-Bootloader/limine-protocol/blob/trunk/PROTOCOL.md)
for the complete contract.

## Source and architecture boundary

`kratos/kernel/` contains kernel-side code; the current prototype entry and
linker configuration are x86_64-specific. `entry.S` enables the baseline FPU/SSE
state before Zig code, and `interrupts.S` is the exception entry/return boundary.
The boot protocol, CPU state, register/stack conventions, port-I/O serial output,
linker target, and QEMU machine are platform boundaries—not portable kernel
interfaces. Keep future architecture-dependent mechanisms behind small
interfaces when there is a real second implementation to support. Do not infer
an established HAL, scheduler, general memory manager, or multi-architecture
design from this prototype.

`docs/boot-path.md` records why Limine was selected for this first proof and
what assumptions remain conditional on toolchain validation. `docs/qemu-boot.md`
records the prototype's build and launch implementation. Keep those
implementation-specific commands there rather than duplicating them here.

## Repeatable QEMU debug loop

Use the exact build and launch commands in [QEMU boot](qemu-boot.md), from the
repository root, so the tool versions, image inputs, and QEMU options remain
consistent. The intended loop is:

1. Build the kernel ELF and bootable image with the documented command. Stop
   on any compiler, linker, or image-creation error; do not debug a stale ISO.
2. Launch the documented x86_64 QEMU configuration with serial output attached
   to the terminal. Capture the complete output for comparison between runs.
3. Check for the kernel's recognizable entry/boot message. No message means
   investigate image/boot selection and entry handoff before later kernel
   behavior; a partial message narrows the failure to the subsequent path.
4. Change one cause at a time, rebuild the image, and repeat. Preserve the
   command, tool versions, and serial transcript with any reported failure.
5. For a hang or fault, use the QEMU options documented by the implementation
   guide and available locally to expose more diagnostics; do not assume an
   unverified debugger or firmware setup is part of the supported loop.

## Verification status and gaps

The documented `./kratos/build-qemu.sh` path was checked with the pinned Zig
and Limine releases, xorriso, and QEMU. The ISO built successfully; QEMU BIOS
serial output confirmed kernel entry and memory-map allocation. Issuing `nmi`
through the QEMU monitor produced the expected vector-2 exception diagnostic.
UEFI boot, physical hardware, and a QEMU GDB/LLDB remote debugging session have
not been verified; those are not currently supported claims.

## References

- [Initial x86_64 QEMU boot path](boot-path.md)
- [Boot an observable kernel in QEMU](tickets/0003-qemu-boot-and-observable-kernel.md)
- [Limine protocol specification](https://github.com/Limine-Bootloader/limine-protocol/blob/trunk/PROTOCOL.md)
