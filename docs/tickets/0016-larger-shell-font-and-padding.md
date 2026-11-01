# Improve shell text size and screen padding

**Status:** complete

## Description

The framebuffer shell's text is too small for comfortable reading, and the
bottom prompt/content sits flush against the display edge. Increase the shell
font's rendered height and give the shell a deliberate bottom inset so the last
line is not visually cramped. Preserve bounded rendering, line editing, and the
existing ASCII-art text presentation.

## Acceptance criteria

- Shell glyphs use documented larger 24x28 cells at 1280x800, with 18x20
  compact cells at 320x200.
- The entire standard-resolution interface has a 50-pixel inset from every
  edge. Compact mode uses responsive 16-pixel horizontal and 12-pixel vertical
  insets at 320x200.
- The prompt/input row has a visible baseline and bottom margin; scrolling and
  cursor bounds stay inside the inset viewport. Output, typed echo, Backspace,
  and clear remain correct, and clear preserves the padded cursor origin.
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

Follow-up implementation uses a normal 24x28 cell font (4x4 glyph pixels) and
50-pixel padding on all four edges at 1280x800. At 320x200 it selects 18x20
cells (3x3 glyph pixels), compact two-row ASCII welcome, and 16x12-pixel insets;
50 pixels on each side would make the minimum display unusable. The framebuffer
console carries a bounded padded viewport, so clear returns to its inset origin
and wrap/scroll/editing cannot write into the margins. The animation uses this
same viewport and font scale.

## Verification evidence

- Host tests: normal/compact glyph dimensions, all four inset bounds, console
  input/backspace/output/scroll/clear bounds, welcome/clear cursor placement at
  1280x800 and 320x200, animation policy, input, and shell command tests passed.
- Freestanding kernel ELF compiled and linked with Zig 0.17.0 and Clang.
- QEMU keyboard tests passed at 1280x800 and 320x200: Backspace, quoted echo,
  clear, `kratos` exit/recovery, and guest `shutdown` (QEMU status 33).
- QEMU serial regression passed rapid paste, quoted echo, overflow recovery,
  Backspace, `halt`, and `shutdown` (status 33).
- Captured and inspected fresh welcome and post-clear prompt screenshots after
  this follow-up at both resolutions: [`screenshots`](../screenshots/).
