# Verify the first user-mode milestone in QEMU

**Status:** done — bounded QEMU milestone verified

## Description

Make the first user-mode execution path reproducibly testable end to end,
including error handling and recovery to the existing shell.

## Acceptance criteria

- Document prerequisites and exact build and QEMU commands, including how to
  invoke each test case and recognize success or failure.
- Exercise the separately built program's user-mode output and exit, an invalid
  syscall argument and unknown syscall, and user faults including a kernel-memory
  access attempt. Assert observable results, not merely that QEMU started.
- After normal exit and each fault, verify the serial recovery shell accepts and
  executes a command; verify repeated launch within documented resource limits.
  Distinguish user faults from kernel faults in diagnostics.
- Run the relevant host tests and existing serial, keyboard, and shutdown QEMU
  regressions; record commands, outcomes, and any limitations in the ticket and
  user-facing QEMU documentation. Automate the new regression where practical.
- State explicitly that this verifies a bounded single-program milestone, not
  full process isolation, POSIX conformance, or a general security guarantee.

## Rationale and dependencies

Depends on tickets [0018](0018-user-mode-boundary.md),
[0019](0019-minimal-user-syscalls.md), and
[0020](0020-first-user-program.md). It supplies the milestone-level evidence
that success and failure both preserve the recovery path.

## Implementation and verification

The exact prerequisites, build and individual scenario commands, expected
results, failure interpretation, and scope are in
[qemu-boot.md](../qemu-boot.md#user-mode-milestone-regression). On 2026-11-13,
Linux/QEMU 11.1.3 passed normal and NX-unavailable program runs, all five
separately built syscall/fault fixtures with two launches and a serial command
after each, the kernel-origin NMI distinction, all host-test-bearing Zig modules,
and existing serial, keyboard, halt and shutdown regressions. Both serial and
keyboard shutdown returned QEMU status 33. BIOS and the default keyboard-test
resolution were used; UEFI, additional resolutions, and physical hardware were
not verified in this run. This is not full process isolation, POSIX conformance,
or a general security guarantee.
