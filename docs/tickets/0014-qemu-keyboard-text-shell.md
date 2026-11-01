# Make the text shell interactive from the QEMU window

**Status:** planned

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

To be completed. The QEMU serial path must remain available for automation and
recovery, but normal interaction must work directly in the QEMU window.
