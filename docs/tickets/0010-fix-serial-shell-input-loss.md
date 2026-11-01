# Fix serial shell input loss and define quoted echo behavior

**Status:** planned

## Description

Diagnose and fix the shell corruption reported when entering or pasting a longer
`echo` argument. The observed failure drops input, damages the next prompt, and
can turn later text into commands; do not assume the line parser alone is at
fault. Reproduce it through the documented QEMU serial path, identify whether
the loss occurs in UART servicing, line editing, terminal flow control, or
command parsing, and fix the responsible boundary. Define useful shell quoting
for `echo`: matching single/double quotes delimit an argument and are not
printed; unmatched quotes must have a documented, recoverable behavior.

## Acceptance criteria

- A repeatable QEMU test covers the reported text, a long line, and rapid/pasted
  input followed by another command; no characters leak into subsequent prompts.
- UART receive errors/overrun or other bounded-input failures are handled
  visibly and recoverably rather than silently corrupting shell state.
- `echo` behavior for unquoted, single-quoted, double-quoted, empty, and malformed
  arguments is specified and unit-tested; no heap allocation is required.
- Existing CRLF, backspace, full-line, unknown-command, and halt behavior remains
  covered and works in QEMU.
- Record the root cause and exact verification procedure in the ticket and QEMU
  guide.

## Rationale and dependencies

The first tester found a user-visible shell reliability defect. Fix the input
contract before adding more shell features or a full-screen application. Builds
on tickets 0007–0009.

## Implementation notes

To be completed with the fix. This ticket does not prescribe the root cause or
allow hiding lost input by simply clearing the screen or enlarging the buffer.
