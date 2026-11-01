# Add the KratOS welcome screen and branded shell

**Status:** planned

## Description

Use the framebuffer console from ticket 0011 for a brief welcome message, a
large, legible ASCII-art `KratOS` logo, and a Spartan-red shell theme with a
readable characterful font. Preserve the serial boot diagnostics and shell as a
fallback/recovery path. Keep branding and layout in a small presentation module
so later console/application changes do not spread styling through kernel
initialization and command parsing.

## Acceptance criteria

- Normal QEMU boot displays the welcome text and large `KratOS` ASCII logo
  before the interactive shell; the layout adapts to framebuffer dimensions.
- Shell prompt and output use a documented Spartan-red palette and readable font;
  warnings/errors remain distinguishable and legible.
- Serial-only and framebuffer-unavailable boot paths remain operable and clearly
  report fallback behavior.
- `clear`, command echo, and shell output use the active console consistently;
  no ANSI escape sequences are rendered as visible glyphs on the framebuffer.
- Presentation tests or a documented visual QEMU acceptance checklist cover
  minimum supported resolution and oversized content.

## Rationale and dependencies

KratOS should have an immediate, distinctive, usable identity without sacrificing
readability or the existing recovery console. Depends on ticket 0011.

## Implementation notes

To be completed. A serial terminal cannot select the user's font; the built-in
font is rendered by KratOS itself on the framebuffer.
