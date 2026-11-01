# Add a framebuffer-backed raster console

**Status:** complete; host and BIOS QEMU verified at 1280x800 and 320x200

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
clipped pixel/fill/fill-rectangle operations, a built-in 12x12-cell bitmap font
for upper/lowercase letters, digits, spaces, and common punctuation, and a bounded text console with clear,
wrap, scrolling, CR/LF, backspace, and configurable foreground/background.
Host tests cover invalid pitch/format/backing extent, clipping, multiple pixel
channel orders, row padding, and bounded console behavior.

`kernel.zig` owns the Limine request/response boundary and rejects missing,
empty, unsupported, or malformed framebuffer responses with serial diagnostics;
serial remains the input and recovery channel. Shell prompts and command
responses mirror to the framebuffer while input remains serial-only. QEMU
enables its display by default (`QEMU_DISPLAY=none` opts out); no fixed
resolution is requested. Branding and animation are covered by later tickets.

Host raster/serial-console tests, ISO build, and direct Zig freestanding kernel
compile passed. BIOS QEMU checks at 1280x800 and 320x200 verified the framebuffer
console; `-vga none` verified serial fallback. See
[`../qemu-boot.md`](../qemu-boot.md) for verification details.
