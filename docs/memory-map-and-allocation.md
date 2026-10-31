# Initial Limine memory-map handling

`kratos/kernel/memory_map.zig` contains an isolated validator and monotonic
physical-page allocator for the selected Limine x86-64 boot path. It mirrors the
official `limine_memmap_entry` ABI (`base`, `length`, `type`, all `u64`) and the
protocol's current memory-map type values 0 through 8.

## Safety policy

- Reject an empty map, zero-length entries, overflowing ranges, unknown type
  values, and any overlapping entries. A bad map is a boot-fatal condition for
  the caller; it must not continue with a partial result.
- Only type `LIMINE_MEMMAP_USABLE` is eligible for allocation. Reserved,
  ACPI, bad-memory, bootloader-reclaimable, executable/module, framebuffer,
  and reserved-mapped regions are never returned by this initial allocator.
- The first-fit allocator aligns each usable region's beginning upward to a
  4-KiB boundary, allocates one page at a time, and does not cross region ends.
  It does not free or coalesce pages and is intended only as the early physical
  frame allocation strategy.
- The map must be validated before constructing the allocator. It uses caller
  storage for decoded regions and cursors, and does not allocate memory itself.

This strategy does not implement a virtual heap, page-table management, freeing,
NUMA, DMA constraints, or ownership transfer for reclaimable regions. In
particular, do not retain or later dereference Limine's response/entry pointers
after reclaiming bootloader memory; copy the checked values into kernel-owned
storage first.

## Integration and QEMU validation

The kernel requests the official memory-map response, bounds its count to 1–128,
copies entries into fixed kernel-owned storage, validates the complete map,
initializes the allocator, and allocates one frame before continuing. The
response and entry pointers are consumed during boot and not retained by the
allocator.

`zig test kratos/kernel/memory_map.zig` passes the validation and allocator
tests. Under the documented QEMU profile, the kernel reported 16 entries and
allocated the first usable frame at `0x7e000`. Malformed-map cases are covered
by unit tests; a malformed bootloader response was not injected into QEMU. The
allocator remains an early monotonic physical-frame allocator, not a general
memory manager.

## Protocol source

Limine Protocol, official `include/limine.h` (`Memory map` definitions) and
`PROTOCOL.md` (`Memory Map feature`):
<https://github.com/Limine-Bootloader/limine-protocol/blob/trunk/PROTOCOL.md>
