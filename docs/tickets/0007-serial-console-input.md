# Add polled serial-console input

**Status:** ready

## Description

Extend the existing COM1 console into a small Zig console module that supports
output and polled input. Provide bounded line input with basic terminal echo,
backspace handling, and CR/LF acceptance. Do not allocate dynamically; define
what happens when a line exceeds the fixed buffer.

## Rationale and dependencies

The current kernel can print to QEMU's serial console but cannot receive input.
A serial console is the smallest practical interactive device path for the
current emulator workflow. Depends on the bootable prototype in ticket
[0003](0003-qemu-boot-and-observable-kernel.md).

## Acceptance criteria

- Console code is isolated from the command interpreter and remains freestanding.
- Input is polled from COM1 and line storage is bounded with documented overflow
  behavior.
- Backspace and line termination behave predictably; empty lines are safe.
- The line-input path is exercised in QEMU when integrated by ticket
  [0009](0009-integrate-interactive-shell.md).
- The implementation makes no claim of keyboard, terminal-emulator, or physical
  UART support beyond the tested QEMU setup.
