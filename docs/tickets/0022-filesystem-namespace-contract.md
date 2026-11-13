# Define the native filesystem namespace contract

**Status:** complete

## Description

Specify the space-based path and object model before encoding it on disk or
exposing it through syscalls. This ticket is the contract for the later
filesystem tickets, not a filesystem implementation.

## Acceptance criteria

- Document the path grammar for `mine:`, named shared spaces, and the protected
  `system:` space, including root paths, separators, relative navigation, and
  how ambiguous shared-space display names are handled.
- Require every persisted space, account, folder, and file name to match
  `[a-z]+`. Set bounded byte and path lengths. Reject invalid input rather than
  silently lowercasing, transliterating, or truncating it. `:` and `/` are path
  syntax, never name characters; `.` and `..` are not stored names.
- Define reserved top-level areas: `inbox`, `work`, `library`, `archive` in
  personal/shared spaces; `boot`, `packages`, `policy` in `system`. Define what
  users may create below them and make `archive` organizational rather than
  implicitly read-only.
- Define stable object IDs, path lookup, rename/move, and open-handle lifetime.
  State whether a move between spaces is supported in this milestone and how
  errors such as missing, duplicate, invalid, denied, and resource-exhausted
  are represented.
- Specify file-type metadata without relying on suffixes, the owner/editor/
  reader space roles, and the rule that a view or alias cannot grant access.
  Record which behavior remains deferred, including saved cross-space views.
- Add host tests for independent path/name parsing and canonicalization,
  including empty components, overlong input, non-ASCII bytes, uppercase,
  digits, punctuation, and delimiter misuse.

## Rationale and dependencies

Follows the completed user-mode milestone [0018–0021](0021-user-mode-qemu-verification.md)
and the [filesystem roadmap](../roadmap.md#next-milestone-native-space-based-filesystem).
Tickets 0023–0030 use this contract. Keep namespace terminology separate from
the disk format so the storage implementation can change without changing paths.

## Verification

The [namespace contract](../filesystem-namespace.md) specifies the logical model.
`zig test kratos/kernel/namespace.zig` passes the independent lexical parser tests
with Zig 0.17.0. Storage, lookup and access enforcement remain later milestones.
