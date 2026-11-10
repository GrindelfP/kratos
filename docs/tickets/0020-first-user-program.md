# Build and launch the first user-mode program

**Status:** planned

## Description

Build a minimal program separately from the kernel, integrate a deliberately
limited way to load it, and launch it from the existing kernel shell.

## Acceptance criteria

- Provide reproducible build instructions for a separately built user program,
  its target and ABI, and the mechanism that places it in the boot image or
  otherwise makes it available to the kernel. Document its entry point, layout,
  and size limits.
- Validate the program image and its placement before entering user mode;
  malformed, oversized, or unavailable images fail visibly and leave the shell
  usable. A fixed embedded image or another bounded initial mechanism is enough;
  no general executable loader or filesystem is required.
- A documented shell command launches the program at user privilege. In QEMU it
  writes a recognizable message using the syscall ABI, exits with an observable
  result, and returns to a working shell. It can be launched again within the
  documented resource limits.
- Add tests for image validation and loading logic where practical, and record
  build and QEMU evidence. Serial recovery and existing shell commands continue
  to work.

## Rationale and dependencies

Depends on the boundary in [0018](0018-user-mode-boundary.md) and syscall ABI in
[0019](0019-minimal-user-syscalls.md). This proves the first separate userland
artifact without requiring a full process lifecycle or persistent storage.
