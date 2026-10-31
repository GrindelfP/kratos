# Handle the QEMU memory map

**Status:** in progress

## Description

Consume and validate the memory information supplied at boot in the selected QEMU configuration. Establish and document an initial memory-allocation strategy suitable for the next kernel work.

## Rationale and dependencies

Memory-map handling and an allocation strategy are prerequisites for kernel growth. Depends on the boot contract established in ticket [0002](0002-select-x86-boot-path.md) and a working kernel from ticket [0003](0003-qemu-boot-and-observable-kernel.md).

## Acceptance criteria

- The kernel safely identifies usable and reserved memory from the selected boot handoff.
- Invalid or unexpected map entries are handled without silently treating reserved memory as usable.
- The initial allocation strategy and its limits are documented and exercised in QEMU.
- Scope remains limited to the selected x86 QEMU setup; physical-memory discovery beyond it is not claimed.

## Implementation status

An isolated Limine map validator and monotonic page-frame allocator are
implemented and unit-tested. Kernel request wiring, QEMU validation, and
remaining limitations will be recorded after the boot integration is committed.

## Current implementation

An isolated Zig validator and conservative usable-only frame allocator are in
[`kratos/kernel/memory_map.zig`](../../kratos/kernel/memory_map.zig), with its
policy and integration boundary documented in
[`docs/memory-map-and-allocation.md`](../memory-map-and-allocation.md). Request
wiring, build verification, and QEMU evidence remain outstanding; this ticket
is not complete.
