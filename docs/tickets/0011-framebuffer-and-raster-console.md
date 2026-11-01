# Add a framebuffer-backed raster console

**Status:** planned

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

To be completed. Avoid implementing only an ASCII art splash directly in kernel
startup; the drawing and console interfaces must support later applications.
