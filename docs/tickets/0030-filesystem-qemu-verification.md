# Verify the native filesystem milestone in QEMU

**Status:** planned

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
