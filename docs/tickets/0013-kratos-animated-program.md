# Add the `kratos` animated screen program

**Status:** implemented; BIOS QEMU launch/exit verified at 1280x800 and 320x200

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

Implemented `kratos/kernel/animation.zig` as hardware-independent bounded grid
movement, edge collision/direction selection, and deterministic xorshift state;
`kratos_app.zig` exposes a frame policy used by the kernel adapter. The screen
adapter draws the multi-line Kratos figure with the integrated raster console.
The framebuffer is cleared once at launch; each frame erases only the previous
figure's bounded rectangle and redraws the three lines at the same x coordinate.
This avoids full-screen flashing and keeps multi-line movement coherent.
Direction tests use explicit seeds. Runtime seed is the x86 `RDTSC` counter
sampled at launch (not cryptographic entropy); zero is remapped to a fixed
nonzero xorshift seed.

Frame pacing uses PIT channel 2 in one-shot mode, counting 23,864 ticks from the
approximately 1.193182 MHz PIT base clock (~20 ms). This avoids changing the
kernel's interrupt/PIC setup. The wait loop polls COM1 every iteration, so `q`
or `Q` exits during a frame without waiting for a shell line. The prior PIT
channel-2/speaker gate byte is restored on exit and after each frame. On exit,
the branded welcome/shell display is redrawn; `halt` and no-framebuffer serial
fallback are unchanged. No allocations or user-mode/process claims are involved.

Host checks: `zig test kratos/kernel/animation.zig`, `zig test
kratos/kernel/kratos_app.zig`, `zig test kratos/kernel/shell_commands.zig`,
`zig test kratos/kernel/console.zig`, and `zig test kratos/kernel/raster.zig`.
Freestanding x86_64 compile/link passed with the same Zig/Clang flags as
`kratos/build-qemu.sh`. QEMU BIOS boot at 1280x800 confirmed the moving figure,
`q` exit, restored prompt, and subsequent `help` and `halt` at both 1280x800 and
320x200; the serial regression and a separate no-framebuffer fallback run also
passed. See [`../qemu-boot.md`](../qemu-boot.md) for details.
