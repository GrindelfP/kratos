# Integrate an interactive QEMU kernel shell

**Status:** ready

## Description

Connect the serial console and built-in command dispatcher to kernel startup.
After boot and memory-map initialization, show a prompt, read and execute one
command at a time, then return to the prompt unless the command requests halt.
Document how to launch QEMU and interact with the shell from its terminal.

## Rationale and dependencies

This is the first small, playable KratOS experience: it turns the bootable
prototype into a system a person can interact with. Depends on
[0007](0007-serial-console-input.md) and
[0008](0008-shell-commands.md).

## Acceptance criteria

- The normal QEMU command reaches a visible prompt and accepts typed input over
  the serial console.
- `help`, `about`, `echo`, `mem`, and `clear` produce documented results;
  unknown commands recover to the prompt; `halt` stops the CPU predictably.
- Multiple commands work in one boot, including empty input and backspace.
- The shell does not require or imply user-mode processes, a filesystem, a
  keyboard driver, or POSIX conformance.
- Build/run instructions and a sample interactive transcript are documented.
