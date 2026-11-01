# Make the text shell interactive from the QEMU window

**Status:** done

## Description

The shell currently reads only COM1, so keyboard input goes to the terminal
running QEMU rather than the QEMU display window. Add a bounded, polled PS/2
keyboard driver and a small input-source boundary so the normal QEMU window can
type into the existing shell. Preserve serial input/output as a recovery and
automated-test path. Replace the pixel-scaled wordmark with a readable multiline
ASCII-art `KratOS` logo rendered by the built-in font; keep the welcome text,
red-on-dark theme, and text-console presentation rather than introducing
illustrative graphics.

## Acceptance criteria

- In the documented QEMU graphical window, users can type `help`, quoted `echo`,
  and `kratos`; Enter, Backspace, shifted punctuation, and letter case behave
  predictably, and typed input is echoed in the framebuffer shell.
- Keyboard polling is bounded and non-blocking with respect to serial; serial
  shell input and the existing rapid-paste regression remain supported.
- Keyboard scancode decoding and input-source arbitration are separated from
  hardware I/O and have host tests for make/break, shift, letters, punctuation,
  Enter/Backspace, and irrelevant scan codes.
- `kratos` can be exited from the QEMU keyboard, returns to the shell, and does
  not consume subsequent input; serial `q` remains supported for headless tests.
- Welcome screen displays a centered, legible multiline ASCII-art `KratOS` logo
  using the text font at 1280x800 and 320x200; no scaled pixel-letter wordmark is
  used.
- QEMU verification types commands through the window's keyboard (not only the
  host terminal serial stream), then verifies app exit and shell recovery.
- No unbounded buffers or allocations are introduced; unsupported/missing
  keyboard hardware leaves serial recovery operational.

## Rationale and dependencies

The window currently looks ready for interaction but ignores keyboard input,
which makes the normal demo unusable. A real keyboard input boundary and an
ASCII-art welcome are appropriate next components for the small text-based OS.
Builds on tickets 0010–0013.

## Implementation notes

Implemented a bounded translated set-1 PS/2 decoder, fair serial/keyboard input
boundary, framebuffer input echo, and shared app-exit polling. The ASCII-art
logo uses the regular text font. Keyboard handling assumes the QEMU BIOS i8042
configuration; Caps Lock, non-US layouts, and extended keys are unsupported.

Host input, console, presentation, raster, commands, animation, app, and memory
map tests passed; the freestanding kernel compiled and linked. QEMU 11.1.2
monitor `sendkey` tests at 1280x800 and 320x200 passed Backspace, `help`,
`echo "Hello !"`, `kratos`, keyboard `q`, subsequent `help`, and `halt` with
serial used only for observation. Welcome and shell screenshots were inspected
at both sizes. The existing serial rapid-paste regression also passed. See
`docs/qemu-boot.md` for the repeatable monitor test and limitations.
