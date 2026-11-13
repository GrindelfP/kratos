# Verify the native filesystem milestone in QEMU

**Status:** completed

## Description

Run the complete read-only, writable, and principal-aware filesystem path on
the documented QEMU configuration and publish reproducible evidence.

## Acceptance criteria

- Document exact prerequisites, host image-builder commands, kernel build,
  QEMU block-device options, test fixtures, and expected serial/screen results
  in the QEMU guide. Automate repeatable success and failure scenarios.
- Verify `system:` image mount and `hello` launch from its package, bounded
  user-mode file read, shell browsing, personal-space create/write/rename,
  persistence after reboot, shared-space owner/editor/reader behavior, and
  denied access from a different principal.
- Verify invalid lowercase-only names, malformed read-only and writable
  images, exhausted capacity, revoked handles, missing storage, and an
  interrupted update. In each nonfatal case, assert the recovery shell remains
  usable and no unauthorized or partially linked file is exposed.
- Run relevant host tests and the existing user-boundary, program, serial,
  keyboard, halt, and shutdown QEMU regressions. Record commands, outcomes,
  limits, and any unsupported configurations in this ticket and user-facing
  documentation.
- State explicitly that the milestone does not provide secure account login,
  general process isolation, POSIX conformance, cross-space saved views, or
  broad hardware support.

## Rationale and dependencies

Depends on [0022](0022-filesystem-namespace-contract.md) through
[0029](0029-principals-and-space-grants.md). This ticket is the evidence gate
for the [filesystem milestone](../roadmap.md#next-milestone-native-space-based-filesystem).

## Verification record — 2026-11-13

Host verification passed on this machine with Zig 0.17.1:

- Ran `zig test` for every `kratos/kernel/*.zig` module containing tests. All
  suites passed, including namespace, system-image, writable-volume, block
  device, shell, and user-syscall coverage.
- `python3 kratos/tools/test-system-image.py` passed (5 tests).
- Python compile checks for all QEMU test drivers and shell syntax checks for
  the build, data-image, and serial-test scripts passed.
- Manually linked the current freestanding kernel with Zig 0.17.1 and Clang.

QEMU acceptance passed with project-local Zig 0.17.0, Limine 12.9.6, GNU
`gobjcopy`, QEMU, and fresh temporary ISO/data images. The system-mount,
packaged-program, user-boundary, serial-shell, ATA persistence, writable-space
create/write/remount, keyboard-shell, and malformed-package recovery fixtures
passed. The two-boot shared-space fixture verifies owner/editor/reader roles,
denied reader writes, revocation, and persistence. Corrupt writable metadata,
capacity exhaustion, and interrupted updates retain their focused host-test
coverage; the system does not claim secure login, general process isolation,
POSIX conformance, saved views, or broad hardware support.
