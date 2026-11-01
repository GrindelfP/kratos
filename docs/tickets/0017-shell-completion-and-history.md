# Add shell command completion and history

**Status:** planned

## Description

Make interactive command entry faster by supporting Tab completion for built-in
command names and Up/Down navigation through a bounded history of submitted
commands. Handle keyboard key events without weakening the existing fixed-size
line editor, direct QEMU keyboard path, or serial recovery shell.

## Acceptance criteria

- Tab at the start of a command or within its first token completes a unique
  built-in command prefix from the current command table. For an ambiguous
  prefix, show the matching command names and redraw the prompt and unchanged
  input line; with no match or after the first argument, leave the input intact.
- Up selects progressively older commands. Down moves toward newer commands;
  moving past the newest restores the unsubmitted draft that was present when
  history navigation began. Browsing does not execute a command.
- Keep a fixed, documented number of recent non-empty submitted lines, bounded
  by the existing line capacity. Define duplicate handling and wrap behavior;
  use no dynamic allocation and do not mutate stored history while browsing.
- Add decoded Up/Down/Tab key events for the QEMU keyboard path, including the
  PS/2 translated set-1 extended arrow scancodes. Unrelated extended keys remain
  ignored. Existing letters, Shift, Enter, Backspace, serial input, and app exit
  continue working.
- Host tests cover key decoding, unique/ambiguous/no-match completion, completion
  only in the command token, history ordering/wrap, draft restoration, and line
  bounds. QEMU keyboard regression uses monitor `sendkey` to verify Tab, Up,
  Down, editing, and command execution through the graphical keyboard path.
- The existing keyboard and serial/shutdown regressions pass; update
  `docs/qemu-boot.md`, this ticket, and the session log with usage and evidence.

## Rationale and dependencies

Typing every command and repeating commands manually is cumbersome, especially
in the small kernel shell. Completion and recall improve the basic interactive
loop while keeping it allocation-free and bounded. Builds on the line editor and
QEMU keyboard path from tickets 0010, 0014, and 0016.

## Implementation notes

To be completed. Keep editing/history/completion policy testable independently
from port I/O and framebuffer drawing. Redraw the edited prompt line without
leaving stale characters on screen, including under the current padded viewport
and 24x28 standard font / compact 320x200 font.
