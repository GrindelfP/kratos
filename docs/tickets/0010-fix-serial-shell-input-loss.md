# Fix serial shell input loss and define quoted echo behavior

**Status:** completed

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

Root cause at the input boundary: COM1 receive handling polled only the
data-ready bit and ignored the 16550 line-status error flags (overrun, parity,
framing, and break). A receive failure could therefore silently leave a
shortened line that the shell would dispatch. The bounded editor also kept and
dispatched the prefix of an over-capacity line. Both conditions now invalidate
the complete line; remaining input is ignored through CR/LF, a visible
diagnostic is printed, and a fresh prompt is issued. This addresses the input
boundary rather than concealing corruption or enlarging the buffer. The
reporter's literal payload/environment was not present in the ticket, so an
actual UART overrun could not be attributed as the unique cause of their exact
incident; the updated code and QEMU test cover this plausible loss mechanism
and prove the shell's recovery contract.

`echo` removes matching single- and double-quote delimiters, preserves other
bytes/spaces, supports empty arguments and adjacent quoted portions, and does
not implement backslash escaping. An unmatched quote prints
`echo: unmatched quote`, emits no partial argument, and returns to the prompt.
Parsing uses a fixed stack buffer and performs no allocation.

Verification: `zig test kratos/kernel/console.zig` (5 tests) and
`zig test kratos/kernel/shell_commands.zig` (6 tests) pass. The repeatable BIOS
QEMU test is `./kratos/test-serial-shell.sh [ISO]`; it pastes a 115-byte echo
line plus subsequent commands, checks CRLF, exact-capacity and overflow
recovery, quoted echo, backspace, unknown-command handling, and halt. It passed
under QEMU 11.1.2. For this run,
the updated kernel was built with Zig 0.17.0/Clang and inserted into the
available bootable Limine ISO with xorriso replay because the Limine executable
is not installed in this environment; the ordinary `build-qemu.sh --build-only`
path remains the documented way to create a fresh ISO when Limine 12.9.6 is
available. The ticket did not contain the reporter's literal original input;
the QEMU fixture uses a representative near-capacity 115-byte string. The
captured failure mechanism is established from the ignored UART error flags and
confirmed recovery behavior, rather than claiming a particular physical UART
error occurred in every paste.
