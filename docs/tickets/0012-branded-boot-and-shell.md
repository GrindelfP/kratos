# Add the KratOS welcome screen and branded shell

**Status:** implemented; visual QEMU acceptance pending

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

`kratos/kernel/presentation.zig` owns the welcome layout, responsive scaled
`KratOS` wordmark, and palette: deep Spartan red `#140D0D` background,
`#E34234` logo, `#FF6B5B` prompt/warnings, and warm `#F3E8DF` normal output.
The reusable raster font now renders lower-case and common punctuation as well
as uppercase, digits, and blank spaces; the kernel retains serial diagnostics and
the serial shell when framebuffer setup fails. Framebuffer prompts and command
responses are drawn without ANSI control sequences. Since input still arrives
only over COM1, typed characters are echoed on serial. `clear` clears the
framebuffer and emits a plain-text notice on serial.

Host verification: `zig test kratos/kernel/raster.zig`, `console.zig`,
`shell_commands.zig`, and `presentation.zig`; freestanding kernel compile/link
passed. QEMU visual acceptance was not performed: `LIMINE_DIR` is unavailable.
Use the checklist in [`../qemu-boot.md`](../qemu-boot.md#branded-screen-visual-checklist)
when Limine v12.9.6 files are available.
