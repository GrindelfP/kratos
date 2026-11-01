# Improve shell text size and screen padding

**Status:** complete

## Description

The framebuffer shell's text is too small for comfortable reading, and the
bottom prompt/content sits flush against the display edge. Increase the shell
font's rendered height and give the shell a deliberate bottom inset so the last
line is not visually cramped. Preserve bounded rendering, line editing, and the
existing ASCII-art text presentation.

## Acceptance criteria

- Shell glyphs are visibly taller/larger than the current 12x12-pixel cells at
  the standard QEMU display mode; the selected cell dimensions are documented.
- The final shell line and prompt have at least one full line-height of visible
  background beneath them, rather than touching the framebuffer's bottom edge.
- Shell scrolling and cursor bounds account for the larger font and bottom
  inset; command output, typed echo, Backspace, and `clear` remain correct.
- The welcome logo, tagline, and prompt remain legible and non-overlapping at
  both 1280x800 and 320x200. Narrow layouts may use a compact logo/layout while
  continuing to render text rather than a pixel wordmark.
- Host tests cover updated glyph/cell bounds and shell padding/layout, including
  the minimum supported resolution; QEMU screenshots are captured and inspected
  at both documented resolutions.
- The `kratos` animation remains bounded and does not overwrite or collide with
  the shell's padded layout after returning to the prompt.

## Rationale and dependencies

The current 12-pixel cells are visually small in the QEMU framebuffer, and the
last shell line is rendered directly at the lower edge. Improve readability and
visual breathing room without changing the direct keyboard input or serial
recovery behavior. Builds on tickets 0011–0015.

## Implementation notes

Implemented an 18x20 cell font with 3x3 rendering of each 5x5 source glyph and
a 20-pixel bottom inset. Presentation selects a compact, non-wrapping ASCII
welcome on narrow/short screens; animation dimensions and its exit label respect
the same inset. Console wrapping, scrolling, clear, and editing retain bounded
cell coordinates.

## Verification evidence

- Host tests: raster/font/scroll, presentation layout bounds at 1280x800 and
  320x200, animation policy, input, and shell command tests passed.
- Freestanding kernel ELF compiled and linked with Zig 0.17.0 and Clang.
- QEMU keyboard tests passed at 1280x800 and 320x200: Backspace, quoted echo,
  clear, `kratos` exit/recovery, and guest `shutdown` (QEMU status 33).
- QEMU serial regression passed rapid paste, quoted echo, overflow recovery,
  Backspace, `halt`, and `shutdown` (status 33).
- Captured and inspected welcome and post-clear shell screenshots at both
  resolutions: [`screenshots`](../screenshots/).
