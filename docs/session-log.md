# Session log

2026-10-31 - 20:19 MSK - Added repository agent guidance, workflow rules, and session log; verified origin remote and pulled latest changes.
2026-10-31 - 20:51 MSK - Researched lightweight UNIX-like OS differentiation and kernel language tradeoffs; added cited research note.
2026-10-31 - 20:56 MSK - Agreed on x86 and Zig as the proposed direction; added staged OS roadmap and six ready tickets for boot, toolchain, and kernel foundations.
2026-10-31 - 21:00 MSK - Added initial kernel boundary and QEMU debug-loop guide for ticket 0004; left ticket in progress pending command and boot verification.
2026-10-31 - 21:35 MSK - Completed tickets 0001–0006: validated Zig 0.17.0, selected and pinned Limine, booted the Zig x86_64 kernel in QEMU, integrated memory-map allocation and exception diagnostics, and verified tests plus controlled NMI handling.
2026-10-31 - 21:53 MSK - Defined and committed tickets 0007–0009 for a serial console, built-in commands, and an interactive QEMU kernel shell; implementation is next.
2026-10-31 - 22:16 MSK - Implemented the serial shell and verified built-in commands, line editing, CRLF input, halt, and NMI reporting in QEMU; completed tickets 0007–0009 with per-ticket commits.
