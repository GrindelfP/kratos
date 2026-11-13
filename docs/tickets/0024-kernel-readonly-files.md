# Mount and read the system space in the kernel

**Status:** planned

## Description

Validate and mount the read-only image as `system:` and provide a small kernel
file interface independent of the image's raw offsets.

## Acceptance criteria

- Validate the complete image before publishing a mount. A missing or malformed
  image reports a bounded diagnostic and leaves the serial recovery shell
  available; it must not expose partially parsed entries.
- Implement bounded path lookup, directory enumeration, file size/type lookup,
  and offset-based reads through stable object handles. Distinguish not found,
  wrong kind, invalid path, and unavailable mount.
- Enforce read-only `system:` behavior. Reads cannot escape the image bounds;
  reads at or past EOF and arithmetic overflow have documented results.
- Add host-testable parser/lookup tests and a QEMU smoke test that mounts the
  normal image and rejects a deliberately malformed image while the shell
  remains usable.
- Keep the existing `hello` command working through the transition; program
  launch migration is covered by [0026](0026-user-files-and-package-launch.md).

## Rationale and dependencies

Depends on [0022](0022-filesystem-namespace-contract.md) and
[0023](0023-readonly-space-image.md). A kernel-only read interface makes the
format and recovery behavior observable before adding a user syscall.
