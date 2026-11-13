# Define and implement minimal user syscalls

**Status:** done — fixed embedded context

## Description

Add a small, documented boundary through which the first user-mode program can
write output and exit. Keep the interface independent of POSIX claims.

## Acceptance criteria

- Document the entry mechanism, syscall numbers, register and calling
  conventions, argument sizes, return values, error codes, and clobbers.
- Implement bounded output and exit operations. Output validates the complete
  user buffer range, including overflow, inaccessible and kernel addresses,
  before reading it; invalid arguments return a documented error without
  crashing the kernel. Define zero-length and maximum-length behavior.
- Unknown syscall numbers return a documented error. Exit records an observable
  result, releases the execution context as supported, and returns to the shell.
- Host tests exercise dispatch and range-validation edge cases; QEMU exercises
  output, exit, an invalid pointer or range, and an unknown syscall from user
  mode. Describe any test fixture and expected results.
- Preserve kernel-origin exception handling and serial recovery. Do not add a
  filesystem, scheduler, or POSIX compatibility claim as part of this ticket.

## Rationale and dependencies

Depends on ticket [0018](0018-user-mode-boundary.md). A documented, bounded ABI
lets a separate program interact with the kernel without exposing kernel memory.

## Implementation and verification

The ABI, fixed-mapping validation, exit lifetime, fixture and test commands are
documented in [qemu-boot.md](../qemu-boot.md#minimal-ring-3-syscall-abi).
The embedded fixture is not yet a separately loaded program. Host policy tests
and the QEMU boundary regression cover the syscall path and existing faults.
