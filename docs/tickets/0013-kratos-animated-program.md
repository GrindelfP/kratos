# Add the `kratos` animated screen program

**Status:** planned

## Description

Add a `kratos` shell command that launches a bounded foreground application. It
draws a small recognizable Kratos ASCII figure on the framebuffer and animates
it around the screen, changing direction pseudo-randomly while staying within
the drawable area. Use reusable drawing, frame pacing, and entropy interfaces;
do not implement the animation as an unpaced busy loop or as serial escape-code
tricks. The application must return cleanly to the shell on its documented exit
input and restore the branded shell display.

This initial app runs in the existing kernel execution model. It must have a
clear application boundary and avoid corrupting kernel/console state; user-mode
process isolation and loading arbitrary executables remain separate roadmap work
and must not be implied by this command.

## Acceptance criteria

- `help` documents `kratos`; invoking it clears/transitions to the app view,
  displays a small multi-line figure, and visibly animates it in QEMU.
- Movement is bounded for small and large supported framebuffers; direction
  changes are deterministic under a test seed and varied under the runtime seed.
- Frame pacing uses a documented timer source and does not starve serial input or
  diagnostics; no unbounded allocations are introduced.
- The documented exit input returns to the shell with prompt and theme restored;
  `halt`, shell recovery, and serial diagnostics still work afterward.
- Test geometry, collision/edge handling, random-direction selection, command
  dispatch, and frame timing policy independently from Limine and hardware I/O.
- QEMU verification records the app launch, movement, exit, and post-exit shell
  operation. User-mode processes are explicitly out of scope for this ticket.

## Rationale and dependencies

This is a real, interactive demonstration built on reusable display and timing
components, rather than a static splash or terminal gimmick. Depends on tickets
0011 and 0012; ticket 0010's input reliability work is required for dependable
exit and subsequent shell interaction.

## Implementation notes

To be completed. Keep animation state/logic separate from framebuffer writes and
serial input polling so each can be tested and later moved behind a process API.
