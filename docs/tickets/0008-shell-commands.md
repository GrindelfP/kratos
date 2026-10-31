# Implement a small built-in command set

**Status:** in progress

## Implementation notes

- Added `kratos/kernel/shell_commands.zig`, a fixed-line-length dispatcher with
  a writer callback, caller-supplied memory summary, and explicit halt action.
- Added automated tests for empty/whitespace input, arguments, unknown commands,
  memory output, halt, and overlong input; `zig test
  kratos/kernel/shell_commands.zig` passes all four tests.
- Not complete until ticket [0009](0009-integrate-interactive-shell.md)
  integrates and demonstrates the commands in QEMU.

## Description

Implement a bounded, allocation-free command parser and dispatcher for a small
kernel-shell command set: `help`, `about`, `echo`, `mem`, `clear`, and `halt`.
Keep command parsing/dispatch separate from UART input. Pass memory information
through a small context rather than coupling commands to Limine request data.

## Rationale and dependencies

Useful, predictable commands make the first interactive OS build enjoyable to
explore while keeping the project small. This is a kernel monitor, not yet a
POSIX shell or user process. Depends on the bootable kernel and memory summary
from tickets [0003](0003-qemu-boot-and-observable-kernel.md) and
[0005](0005-handle-qemu-memory-map.md).

## Acceptance criteria

- Commands and arguments are parsed from a fixed-size line without heap use.
- The six documented built-ins have defined behavior; unknown commands and
  empty input are handled without crashing.
- `mem` reports the current boot memory summary; `halt` returns an explicit
  action for the kernel loop to perform.
- Parser/dispatch behavior has automated tests for whitespace, arguments,
  unknown commands, empty input, and bounded input.
- Command behavior is demonstrated in QEMU through ticket
  [0009](0009-integrate-interactive-shell.md).
