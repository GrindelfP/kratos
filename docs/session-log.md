# Session log

2026-10-31 - 20:19 MSK - Added repository agent guidance, workflow rules, and session log; verified origin remote and pulled latest changes.

2026-10-31 - 20:51 MSK - Researched lightweight UNIX-like OS differentiation and kernel language tradeoffs; added cited research note.

2026-10-31 - 20:56 MSK - Agreed on x86 and Zig as the proposed direction; added staged OS roadmap and six ready tickets for boot, toolchain, and kernel foundations.

2026-10-31 - 21:00 MSK - Added initial kernel boundary and QEMU debug-loop guide for ticket 0004; left ticket in progress pending command and boot verification.

2026-10-31 - 21:35 MSK - Completed tickets 0001–0006: validated Zig 0.17.0, selected and pinned Limine, booted the Zig x86_64 kernel in QEMU, integrated memory-map allocation and exception diagnostics, and verified tests plus controlled NMI handling.

2026-10-31 - 21:53 MSK - Defined and committed tickets 0007–0009 for a serial console, built-in commands, and an interactive QEMU kernel shell; implementation is next.

2026-10-31 - 22:16 MSK - Implemented the serial shell and verified built-in commands, line editing, CRLF input, halt, and NMI reporting in QEMU; completed tickets 0007–0009 with per-ticket commits.

2026-10-31 - 22:45 MSK - Finalized the interactive-shell session with a reproducible verification record, run instructions, limitations, and next-step handoff below.

**Handoff:** Tickets 0007–0009 are done. KratOS currently runs a kernel-mode serial shell in QEMU; it is not yet a userland/POSIX system and has no keyboard driver or filesystem.

**Run:** From the repository root, use `LIMINE_DIR=/path/to/limine-binary ./kratos/build-qemu.sh`. See [`docs/qemu-boot.md`](qemu-boot.md) for prerequisites and commands.

**Next:** Define the smallest user-mode program and syscall milestone, then plan a filesystem/userland path. Keep the serial shell as the recovery/debug console.

2026-11-01 - 13:19 MSK - Planned tickets 0010–0013 for the serial shell input-loss/quoted-echo bug, reusable framebuffer console, Spartan-red branded boot/shell, and animated `kratos` foreground app; updated the roadmap to make these components and user-mode limitations explicit.

2026-11-01 - 13:33 MSK - Fixed ticket 0010 serial input loss by detecting UART receive errors and discarding damaged/over-capacity lines, added allocation-free quoted `echo` parsing and regression tests, and verified the 115-byte rapid-paste/recovery flow in QEMU; documented the root cause and verification.
