# Document kernel boundaries and the debug loop

**Status:** done

## Description

Document the boot-to-kernel boundary, source/build layout, architecture-specific code boundary, and a repeatable QEMU debugging workflow for the prototype.

## Rationale and dependencies

An inspectable, understandable system is the project’s intended distinction. Clear boundaries and a usable debug loop make later foundations easier to reason about. Depends on ticket [0003](0003-qemu-boot-and-observable-kernel.md).

## Acceptance criteria

- A new contributor can identify the boot handoff, kernel entry, and architecture-specific code.
- Build, run, and debugging steps are documented and verified against the prototype.
- Current assumptions and known gaps are explicit; no future architecture is promised.

## Implementation status

The boot-to-kernel and architecture boundaries and QEMU debug loop are described
in [`kernel-debugging.md`](../kernel-debugging.md). The commands were checked
against `qemu-boot.md` and `kratos/build-qemu.sh`; a Limine ISO built and QEMU's
BIOS path produced the expected serial output. Issuing `nmi` through the QEMU
monitor produced a vector-2 diagnostic. UEFI, physical hardware, and remote
debugger operation remain unverified.
