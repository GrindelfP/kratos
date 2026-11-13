# Add principals and enforce space grants

**Status:** completed

## Description

Introduce stable account identities and the first access-control model for
private and shared spaces. Account selection is an administrative recovery-
shell mechanism until authentication and a general process model exist.

## Acceptance criteria

- Store stable account IDs separately from lowercase account names. Define
  account creation, rename, collision handling, and deletion/disable policy;
  changing a name must not change ownership or internal object IDs.
- Create a private `mine:` space for each account and allow a shared space to
  have an owner and explicit owner/editor/reader grants. Define discovery,
  lookup, read, write, rename, and grant-management rights for each role;
  `system:` remains protected and read-only.
- Bind the current shell/user-program context to one active principal. Apply
  permission checks in the kernel's common file-operation layer and in user
  syscall paths. Revalidate open handles after grant removal; a saved path or
  future view must not bypass the check.
- Persist account and grant records with the same interruption/recovery rules
  as other writable metadata. Test private-space isolation, each shared role,
  revocation, rename, malformed grant data, and reboot persistence at host and
  QEMU levels.
- Document that selecting an account in the recovery shell is a privileged
  test mechanism, not password login or a security boundary against someone
  with shell access. Do not claim general process isolation or authentication.

## Rationale and dependencies

Depends on [0022](0022-filesystem-namespace-contract.md),
[0026](0026-user-files-and-package-launch.md), and
[0028](0028-persistent-space-mutations.md). These checks prepare the namespace
for future multiuser sessions without claiming a complete security model.

## Completion

Implemented persisted v2 account/grant metadata with stable account and private-space IDs, account rename/disable, owner/editor/reader roles, recovery-shell principal administration, filtered discovery, authorized mutations, and per-read user-handle revalidation. Host volume (9/9), writable-shell (10/10), dispatcher (20/20), and syscall (14/14) tests passed, along with a freestanding kernel-object build. QEMU remains blocked by the unavailable Zig 0.17.0 and Limine assets.
