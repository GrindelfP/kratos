# Session log

2026-11-13 - 12:05 MSK - Completed ticket 0021: added separately built syscall and fault verification images, per-launch serial shell recovery and relaunch assertions, and documented passing host, QEMU boundary, program, serial, keyboard and shutdown regressions and their limits.

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

2026-11-01 - 17:46 MSK - Reviewed and integrated ticket 0017's Tab completion and bounded Up/Down history into main. Fixed-size 16-entry history preserves drafts and duplicates; Tab completes built-in command prefixes; horizontally scrolling input redraw supports full-capacity lines. Host tests, freestanding build, QEMU keyboard tests, and serial/shutdown regressions passed; feature branch changes are now part of the normal main build.

2026-11-01 - 16:47 MSK - Verified the revised ticket 0016 build: all framebuffer/layout/input/app host tests passed, the freestanding kernel compiled and linked, keyboard regressions passed at 1280x800 and 320x200, and serial editing/overflow/halt/shutdown regressions passed (QEMU shutdown status 33); inspected fresh welcome, clear, and animation screenshots.

2026-11-01 - 17:39 MSK - Implemented ticket 0017 keyboard Tab completion and bounded 16-entry Up/Down history with draft restoration; host tests, freestanding ISO, serial regression, and monitor-key tests at 1280x800 and 320x200 passed. Ticket remains in progress: redraw of lines longer than the compact visible viewport needs a viewport-aware solution and visual regression.

2026-11-01 - 17:43 MSK - Fixed ticket 0017 long-line framebuffer redraw using a bounded horizontal input viewport; host raster pixel/margin tests, freestanding build, serial regression and QEMU monitor-key long/short draft screenshot comparisons and recalled execution passed at 1280x800 and 320x200. Ticket remains in progress as requested.

2026-11-10 - 17:26 MSK - Confirmed tickets 0001–0017 are complete and updated the roadmap with the first user-mode program and syscall milestone, verification criteria, and a staged executable, filesystem, and userland path.

2026-11-10 - 17:28 MSK - Planned tickets 0018–0021 for the user-mode boundary, minimal syscall ABI, first separate user program, and end-to-end QEMU verification; linked them from the roadmap.

2026-11-10 - 17:31 MSK - Finalized the planning session with a handoff in docs/session.md; recorded verification limits and ticket 0018 as the next step.

2026-11-13 - 11:41 MSK - Started ticket 0018 with host-tested user-range validation and a successful freestanding ISO build. The validator is not connected to page tables; ring-3 transition, isolation, fault recovery, and QEMU verification remain outstanding.

2026-11-13 - 11:50 MSK - Completed ticket 0018's fixed ring-3 context, supervisor-only inherited mappings, TSS/exception recovery and permission tests. Verified host-testable modules, ISO build, QEMU user faults and kernel NMI, serial and keyboard shell regressions, and no-NX fallback. Direct host testing of interrupts.zig is unsupported by its freestanding port-I/O assembly; it was built and exercised in QEMU.
[2026-11-13] - [11:54] - Implemented ticket 0019 fixed-context int 0x80 output/exit ABI, host policy tests, ring-3 syscall fixture and documentation; verified build, host tests, QEMU boundary/NMI, serial and keyboard regressions.
[2026-11-13] - [12:01 MSK] - Completed ticket 0020: separately assembled bounded KRU1 user image, reusable shell launch and exit reporting; validated host image and shell tests, ISO build, two QEMU launches, NX-unavailable recovery, boundary/NMI, serial and keyboard regressions. User syscall output remains serial-only.
[2026-11-13] - [12:10 MSK] - Discussed an actor-centered filesystem namespace for future users: personal and shared spaces, stable object identities, ordinary folders within spaces, and optional saved views; no implementation or design decision was committed.
[2026-11-13] - [12:15 MSK] - Proposed a standard internal layout for personal and shared spaces based on Inbox, Work, Library, and Archive, plus a package-centered protected system space; discussed predictable paths, user data separation, and sharing semantics without implementing the design.
[2026-11-13] - [12:17 MSK] - Set the proposed filesystem naming constraint to lowercase ASCII letters only (`a` through `z`) for every space, folder, file, and account name; corrected the example layout to lowercase and noted that extensions and numeric suffixes would be excluded under this rule.
[2026-11-13] - [12:19 MSK] - Detailed and separately committed the native space-based filesystem roadmap milestone, replacing the implied UNIX-root goal with an optional POSIX compatibility boundary. Planned tickets 0022–0030 for namespace rules, read-only image and kernel file access, shell/user access, persistent storage and mutations, principals/grants, and QEMU verification; no filesystem code was changed.
[2026-11-13] - [12:26 MSK] - Installed the four personal grindelf skills from the local skills repository into the Codex user skills directory and verified the copies against their sources.
[2026-11-13] - [12:29 MSK] - Updated the personal skills repository from its remote and installed its two additional Codex skills, bringing the installed set to six; verified all copies against the updated source.

[2026-11-13] - [12:31 MSK] - Started a project session, reviewed repository guidance and handoff, and fast-forward checked main against origin.

[2026-11-13] - [12:40 MSK] - Completed ticket 0022: specified the native filesystem namespace and implemented and host-tested bounded lexical path validation and canonicalization; storage and access enforcement remain deferred.
