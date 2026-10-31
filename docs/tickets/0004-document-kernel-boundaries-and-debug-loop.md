# Document kernel boundaries and the debug loop

**Status:** in progress

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
in [`kernel-debugging.md`](../kernel-debugging.md). Command verification and
QEMU evidence will be recorded after the implementation/build workflow is
committed.
