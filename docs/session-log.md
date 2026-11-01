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

2026-11-01 - 13:28 MSK - Implemented ticket 0011's validated Limine RGB framebuffer boundary, reusable raster/font/console module, serial fallback and mirrored shell responses; added host tests and QEMU display/verification documentation. QEMU boot verification remains blocked by the unavailable Limine release files.

2026-11-01 - 13:40 MSK - Integrated tickets 0011–0012 on main after ticket 0010; verified raster, presentation, serial, and shell tests plus a freestanding kernel compile/link, and fixed missing clear callbacks in two shell test contexts. Visual QEMU verification remains blocked by unavailable Limine v12.9.6 files.

2026-11-01 - 14:21 MSK - Built Limine 12.9.6 from the provided source archive (installed mtools with approval), built and BIOS-booted KratOS in QEMU, and verified welcome/logo, shell, `kratos` movement/exit, serial regression, and no-framebuffer fallback at 1280x800 and 320x200. Fixed scaled-logo RGB channel order, enlarged the bitmap console font, corrected multi-line sprite positioning/full-screen flicker, made the narrow-screen footer responsive, and updated visual-verification records.

2026-11-01 - 14:25 MSK - Planned ticket 0014 after discovering the QEMU framebuffer had no direct keyboard input path; the shell only accepted COM1 input. Ticket covers a bounded polled PS/2 keyboard driver, dual keyboard/serial shell input, and a multiline ASCII-art welcome logo while preserving serial recovery.

2026-11-01 - 13:36 MSK - Implemented ticket 0012's responsive KratOS welcome/logo, Spartan-red framebuffer shell presentation, expanded built-in font, direct framebuffer clear without ANSI escapes, host tests, and a QEMU visual checklist. Host validation and freestanding kernel compile/link passed; QEMU visual verification is pending because LIMINE_DIR is unset.

2026-11-01 - 14:10 MSK - Implemented ticket 0013's bounded foreground framebuffer animation, independent movement/direction/frame-policy tests, PIT channel-2 pacing with COM1 exit polling, branded shell restoration, and QEMU checklist; host tests and freestanding compile/link passed, visual QEMU checks remain blocked by unavailable Limine files.

2026-11-01 - 15:29 MSK - Completed ticket 0014: added bounded polled PS/2 decoding, fair serial/keyboard arbitration, framebuffer input echo, keyboard app exit, and a text-font ASCII logo. Host tests, freestanding ISO build, serial rapid-paste regression, and monitor-key QEMU tests at 1280x800 and 320x200 passed; inspected welcome and shell screenshots.

2026-11-01 - 15:38 MSK - Updated README.adoc with current KratOS capabilities and QEMU run instructions; summarized Oct 31–Nov 1 development in devlog.adoc; moved edu/ and the obsolete C kernel.c/kernel.h stubs into legacy/ without deleting them; updated AGENTS.md to reflect the archived layout.

2026-11-01 - 15:41 MSK - Created planned ticket 0015 for a QEMU-specific guest shutdown command and clarified in the README, QEMU guide, and roadmap that `halt` stops the guest CPU while Ctrl+C is a host-side action the guest cannot send.

2026-11-01 - 16:01 MSK - Implemented ticket 0015: added the `shutdown` action and a QEMU `isa-debug-exit` boundary, configured the normal launcher, and extended serial/keyboard QEMU regressions to assert process exit status 33. Verified command tests, freestanding ISO build, serial `halt` preservation, keyboard shutdown, and serial shutdown; updated run documentation.

2026-11-01 - 16:12 MSK - Created ticket 0016 to increase shell font size and add a full-line-height bottom inset, with responsive 1280x800/320x200 layout, scrolling, and screenshot acceptance criteria.

2026-11-01 - 16:58 MSK - Integrated ticket 0016's revised font and all-edge viewport padding into main after user feedback; rebuilt the normal QEMU ISO and reran host, keyboard, serial, halt, and shutdown checks. The standard layout uses 24x28 cells and 50-pixel margins; 320x200 uses compact 18x20 cells with 16x12-pixel insets.

2026-11-01 - 16:22 MSK - Implemented ticket 0016 with 18x20 shell cells, a full-cell bottom inset, compact small-screen ASCII welcome, and inset-aware animation layout; passed host tests, freestanding compile/link, QEMU keyboard and serial/shutdown regressions, and inspected committed 1280x800/320x200 screenshots.

2026-11-01 - 16:41 MSK - Revised ticket 0016 after visual feedback: enlarged standard glyphs to 24x28 cells, added 50-pixel all-edge padding with a 16x12-pixel compact 320x200 mode, preserved the padded cursor after clear, bounded animation and console scrolling to the viewport, and captured fresh QEMU screenshots at both resolutions.

2026-11-01 - 17:32 MSK - Created ticket 0017 for bounded shell command-name Tab completion and Up/Down command history, including extended keyboard events, draft restoration, redraw behavior, and QEMU keyboard regression criteria.

2026-11-01 - 16:47 MSK - Verified the revised ticket 0016 build: all framebuffer/layout/input/app host tests passed, the freestanding kernel compiled and linked, keyboard regressions passed at 1280x800 and 320x200, and serial editing/overflow/halt/shutdown regressions passed (QEMU shutdown status 33); inspected fresh welcome, clear, and animation screenshots.

2026-11-01 - 17:39 MSK - Implemented ticket 0017 keyboard Tab completion and bounded 16-entry Up/Down history with draft restoration; host tests, freestanding ISO, serial regression, and monitor-key tests at 1280x800 and 320x200 passed. Ticket remains in progress: redraw of lines longer than the compact visible viewport needs a viewport-aware solution and visual regression.
