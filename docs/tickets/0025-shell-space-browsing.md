# Browse spaces from the recovery shell

**Status:** planned

## Description

Expose the native namespace in the existing kernel recovery shell while keeping
its serial and keyboard command paths bounded.

## Acceptance criteria

- Add documented commands to list accessible spaces, list a directory, show
  the current space/path, navigate, and read a bounded portion of a text file.
  Use the path grammar from [0022](0022-filesystem-namespace-contract.md).
- Start at a documented location and handle unknown spaces, non-directory
  paths, invalid names, unavailable mounts, empty directories, and output that
  exceeds the console's visible capacity without corrupting shell state.
- List only spaces the active principal may discover once [0029](0029-principals-and-space-grants.md)
  lands. Until then, expose only the mounted `system` space and state that limit
  in help text.
- Add host tests for command parsing and bounded output where practical, plus
  QEMU serial and keyboard checks for navigation, a failed lookup, and normal
  shell recovery commands.

## Rationale and dependencies

Depends on [0024](0024-kernel-readonly-files.md). The shell is a diagnostic
and recovery interface, not a replacement for the user file API in
[0026](0026-user-files-and-package-launch.md).
