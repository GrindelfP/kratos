# Add a bounded persistent storage path in QEMU

**Status:** planned

## Description

Provide one documented QEMU block-device path for writable personal and shared
spaces. Keep the read-only `system` image and recovery shell usable when this
device is absent or faulty.

## Acceptance criteria

- Select one explicit QEMU controller/device configuration after a small driver
  probe; document sector size, capacity limits, command timeouts, flush support,
  and what a completed write means. Do not imply other controllers work.
- Expose bounded block read, write, and flush operations to the filesystem
  layer, with checked ranges and distinct errors for no device, timeout,
  I/O failure, and unsupported flush. Avoid unbounded polling and writes to
  memory-mapped or unrelated devices.
- Add a reproducible way to create and attach a blank data image without
  overwriting an existing one. A missing/unformatted/invalid data image must
  not prevent read-only `system:` mounting or recovery-shell commands.
- Verify block I/O with host-testable range/command tests and QEMU read/write/
  reboot checks. Include an injected device-error or timeout path where
  practical, and record the observed recovery behavior.

## Rationale and dependencies

Depends on the read-only mount [0024](0024-kernel-readonly-files.md), but can be
implemented in parallel with [0025](0025-shell-space-browsing.md) and
[0026](0026-user-files-and-package-launch.md). The durable mutation rules are
deliberately separated into [0028](0028-persistent-space-mutations.md).
