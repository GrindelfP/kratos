# Bug report: writable spaces are listed but not navigable

## Summary

The recovery shell exposes two separate namespace paths. `space-list` enumerates
spaces from the writable data volume, but `cd`, `ls`, `pwd`, and `cat` are
connected only to the read-only `system:` image. As a result, a successfully
created or discoverable personal/shared space cannot be entered with `cd
<space>:`; the browser rejects it with `Unknown space; only system is
available`.

## Evidence and likely causes

- [shell_commands.zig](../../kratos/kernel/shell_commands.zig#L75) routes
  writable commands (`space-create`, `space-list`, `mkdir`, `touch`, etc.) to
  `writable_shell`, but routes `spaces`, `ls`, `pwd`, `cd`, and `cat` to the
  independent `space_shell.Browser`.
- [space_shell.zig](../../kratos/kernel/space_shell.zig#L38) canonicalizes
  paths and explicitly rejects every root other than `system:` at line 44–46.
  The browser stores only a `system_image.Volume` (line 8) and resolves paths
  through that volume (for example, line 81). It has no writable-volume or
  principal context. Thus the error is consistent with the current code path;
  it is not evidence that `space-create` failed.
- [writable_shell.zig](../../kratos/kernel/writable_shell.zig#L135) lists
  spaces through `Volume.listSpacesAs`, while `space-create` persists the new
  space at lines 117–128. The writable volume’s
  [lookupAs implementation](../../kratos/kernel/writable_volume.zig#L308)
  supports principal-relative `mine:` and ordinary named-space paths, but the
  recovery browser never calls it.
- The transcript’s `touch loveletter` and `touch system:loveletter` attempts
  omit a parent-directory separator. [writable_shell.zig](../../kratos/kernel/writable_shell.zig#L149)
  calls `splitPath`, which requires a final `/name` component and returns usage
  when there is no slash ([splitPath](../../kratos/kernel/writable_shell.zig#L228)).
  The documented form is a complete writable path such as
  `touch home:/work/notes/today`; the parent directory must already exist.
  `touch` does not use the `cd` browser's current directory.
- `mine:` is the documented selector for the active account’s private space;
  [lookupAs](../../kratos/kernel/writable_volume.zig#L308) resolves it to the
  account’s stable private-space ID. An account name and its private-space
  selector should not be assumed interchangeable as user-facing syntax.

## Reproduction

With a formatted and mounted data image:

```text
space-create shishagrisha
space-list
cd shishagrisha:
```

Expected from the current implementation: `space-list` includes
`shishagrisha`, then `cd` prints `Unknown space; only system is available`.
For the private space, after `account-use shisha`, try `cd mine:`; it is also
rejected by the system-only browser.

The `touch` usage message is reproducible with `touch loveletter` or
`touch system:loveletter`; neither contains the required parent/name split.
The documented explicit-path shape is `touch <space>:/<area>/<name>`, for
example `touch home:/work/today` after creating `home` (and using an existing
reserved area such as `work`).

## Scope

The principal filesystem lookup and mutation APIs already understand writable
space roots and `mine:`. The user-facing recovery-shell navigation layer has
not been unified with those APIs. The immediate product bug is that listing a
writable space suggests it can be browsed with `cd`, but navigation remains
system-only; the short `touch` inputs in the transcript independently fail the
command’s documented full-path grammar.

