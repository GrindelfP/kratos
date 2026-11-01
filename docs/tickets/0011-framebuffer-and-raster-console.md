# Add a framebuffer-backed raster console

**Status:** complete (host-verified; QEMU verification pending environment prerequisites)

## Description

Request and validate the Limine framebuffer during boot, then add a bounded,
testable framebuffer drawing boundary and readable built-in bitmap font. Build a
text console on that boundary with cursor movement, clipping, scrolling, clear,
and foreground/background colors. Keep serial output available as the reliable
debug/recovery channel. This is a reusable kernel display component, not a
one-off logo renderer.

## Acceptance criteria

- Boot fails safely to serial diagnostics if the framebuffer response is absent,
  malformed, or unsupported; pixel writes honor pitch, dimensions, and pixel
  format without writing outside the mapped framebuffer.
- Font glyphs are readable at documented sizes; text rendering and color choices
  have host-side tests for clipping, bounds, and supported pixel formats.
- Console cursor, newline, backspace, clear, and scrolling behavior are bounded
  and tested; serial diagnostics remain usable.
- QEMU documentation records the framebuffer configuration and how to verify
  the display path. No hard-coded assumptions about a single resolution.
- Hardware-specific Limine/framebuffer handling remains separate from reusable
  raster/font/console logic.

## Rationale and dependencies

An animated character and expressive readable shell require an actual pixel
surface and a font, neither of which the current serial-only kernel has. Builds
on boot and memory initialization (tickets 0003 and 0005).

## Implementation notes

Implemented reusable raster primitives in `kratos/kernel/raster.zig`: a
validated packed 32-bit RGB surface (channel shifts permit RGB/BGR byte order),
clipped pixel/fill operations, a built-in 6x6-cell bitmap font for A–Z and
digits (lowercase maps to uppercase), and a bounded text console with clear,
wrap, scrolling, CR/LF, backspace, and configurable foreground/background.
Host tests cover invalid pitch/format/backing extent, clipping, multiple pixel
channel orders, row padding, and bounded console behavior.

`kernel.zig` owns the Limine request/response boundary and rejects missing,
empty, unsupported, or malformed framebuffer responses with serial diagnostics;
serial remains the input and recovery channel. Shell command responses mirror
to the framebuffer, while prompts and input remain serial-only. QEMU now enables
its display by default (`QEMU_DISPLAY=none` opts out); no fixed resolution is
requested. Branding and animation remain explicitly out of scope.

Host raster/serial-console tests and a direct Zig freestanding kernel compile
passed. QEMU/ISO and visual verification were not possible in the implementation
environment because no Limine v12.9.6 release directory was available; see
[`../qemu-boot.md`](../qemu-boot.md) for the exact verification procedure and
limitation.
