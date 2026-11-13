# Create and modify persistent spaces

**Status:** planned

## Description

Implement the writable data-volume format and the native mutations needed for
personal and shared spaces. Start with a single administrative principal; grant
enforcement follows in [0029](0029-principals-and-space-grants.md).

## Acceptance criteria

- Specify a versioned writable format, object-ID allocation, free-space
  accounting, maximum file/directory sizes, and a bounded mount scan. Reject
  corrupt metadata and unsupported versions without silently repairing or
  writing over user data.
- Create and list spaces with the four reserved areas `inbox`, `work`,
  `library`, and `archive`; implement file/directory create, bounded read/write,
  rename/move, and removal below those areas. Enforce `[a-z]+`, duplicate-name
  rules, capacity limits, and the no-cross-space-move policy chosen in [0022](0022-filesystem-namespace-contract.md).
- Define an update/flush protocol before coding. After a normal remount, every
  completed operation persists. After an interrupted operation, the mounted
  state is either the old complete state or the new complete state; detect and
  report unrecoverable corruption rather than exposing half-linked objects.
- Preserve stable object IDs across a rename or move and specify what an open
  handle sees after removal. Ensure `archive` is writable under the same
  permissions as the other ordinary areas.
- Add host tests for allocation, exhaustion, malformed metadata, name
  validation, and operation ordering. Add QEMU create/write/remount and
  injected interruption tests. Expose bounded mutation commands in the
  recovery shell for the test path.

## Rationale and dependencies

Depends on [0022](0022-filesystem-namespace-contract.md) and the QEMU block
device [0027](0027-qemu-persistent-storage.md). A narrow, durable data volume
is preferable to promising general-purpose filesystem behavior before recovery
is tested.
