# KratOS roadmap

## Direction

KratOS targets x86_64 in QEMU first. Zig is the primary kernel language, with assembly limited to the small architecture-specific boundary where needed. The initial freestanding toolchain and boot path have been validated; their limitations and reproducible build/debug workflow remain documented. The project aims for a lightweight, understandable operating system with its own space-based filesystem. POSIX compatibility may be added as an explicit adapter where useful; the native namespace does not need to imitate a UNIX root tree.

The intended distinction is an inspectable, understandable system: its boundaries, behavior, and development path should be easy to follow. Being lightweight or written in Zig is not, by itself, a claim of uniqueness. Hardware support grows incrementally; broad PC hardware support is an aspiration, not an initial compatibility promise.

## Stages and exit criteria

### 1. Bootable QEMU prototype

Establish a reproducible x86 boot path in QEMU and a minimal observable kernel. Choose a boot protocol/loader and validate the proposed freestanding Zig toolchain rather than assuming either in advance.

**Exit criteria:** a documented command builds a bootable image; it starts in the selected QEMU configuration; the kernel emits a recognizable result over a documented output channel; and the pinned toolchain and remaining limitations are recorded.

**Scope:** build/run path, boot handoff, minimal kernel entry and observable output. **Non-goals:** general-purpose OS services, broad hardware support, and a permanent bootloader/toolchain decision without validation.

### 2. Kernel foundations

Build the minimum architecture and kernel mechanisms needed to support a usable system, keeping hardware-specific code and core logic understandable and bounded.

**Exit criteria:** memory-map handling and a documented allocation strategy work in QEMU; basic exception/interrupt handling is observable and testable; kernel components have clear interfaces and build/debug instructions; known limitations are documented.

**Scope:** early memory management, basic CPU exception/interrupt path, and foundational kernel structure. **Non-goals:** a complete driver set, SMP, security claims, or premature abstraction for multiple architectures.

### 3. Minimal usable system

Add the first end-to-end interactive experience: reliable serial input, a small command interpreter, a framebuffer-backed readable console, and a useful set of built-in commands. Keep serial as the debug and recovery path. The shell and first animation run in the kernel execution model; they are not user-mode processes.

**Exit criteria:** QEMU presents a branded welcome and reaches a usable prompt; users can enter commands without serial input loss and receive predictable responses; line editing, rendering, and command handling are bounded; the `kratos` animated demo can be launched and exited; a documented demo exercises the system.

**Scope:** serial and polled PS/2 keyboard input, framebuffer/raster/font/console interfaces, a simple line editor, built-in commands, boot/shell presentation, a bounded foreground animation, and a kernel command loop. **Non-goals:** user-mode processes, filesystem, arbitrary executable loading, broad application compatibility, polished desktop, or a claim of POSIX completeness.

### 4. Filesystem and userland growth

Grow the native space-based filesystem, process, file, and system-call interfaces alongside userland. Select any POSIX-oriented compatibility goals explicitly and test them separately from the native API.

**Exit criteria:** userland can locate and read named files through a documented native interface; writable storage and user access are added with bounded recovery and permission tests; any claimed compatibility scope has its own tests and examples.

**Scope:** deliberate filesystem, interface, and userland expansion. **Non-goals:** claiming full POSIX conformance unless verified, or adding interfaces without a defined need and tests.

### 5. Broader hardware and installability

Expand from QEMU to selected physical PC hardware and improve installation, recovery, and documentation. Support is incremental and tied to named configurations and tested components.

**Exit criteria:** each added hardware configuration has a recorded test basis and documented limitations; an installation/recovery path is documented and exercised on supported configurations.

**Scope:** staged hardware enablement and practical installation. **Non-goals:** universal PC compatibility or implying that untested hardware is supported.

## Near-term tickets

Tickets 0001–0021 in [`tickets/`](tickets/) are complete. They delivered the QEMU boot path, kernel foundations, interactive recovery shell, and a bounded first user-mode program. The shell remains a kernel-mode debug and recovery console, not userland.

### Completed milestone: first user-mode program

Define and implement the smallest end-to-end user-mode execution path before expanding the command set. The planned tickets specify the architecture, boundaries, and testable acceptance criteria for:

1. **User-mode boundary:** establish the x86_64 privilege transition and the memory mappings and protections needed for one isolated program; handle user faults without silently corrupting the kernel.
2. **Minimal syscall interface:** define a small, documented ABI for output and program exit, including argument validation and observable error behavior. Do not claim POSIX compatibility for this initial interface.
3. **First program and launch path:** build a separate minimal user-mode program, load it using an explicitly documented initial mechanism, run it in QEMU, and return control to the kernel shell on exit. A general executable loader and process scheduler are not prerequisites unless the design demonstrates they are needed.
4. **Verification:** document reproducible build and QEMU commands; test successful output and exit, invalid syscall arguments, and a user fault; confirm the serial recovery shell still works afterward.

The work is tracked in order by [0018: user-mode boundary](tickets/0018-user-mode-boundary.md), [0019: syscalls](tickets/0019-minimal-user-syscalls.md), [0020: first user program](tickets/0020-first-user-program.md), and [0021: milestone verification](tickets/0021-user-mode-qemu-verification.md).

**Milestone exit:** the separate program executes at user privilege, uses the documented syscall boundary, and exits or faults in a controlled, observable way without losing the recovery console. This is a single-program foundation, not a claim of a complete process model or security guarantee.

### Next milestone: native space-based filesystem

Build the KratOS filesystem in ordered, independently verifiable slices. The native namespace starts with spaces rather than one global root. A personal space and each shared space have the reserved top-level areas `inbox`, `work`, `library`, and `archive`; `archive` is organizational, not automatically read-only. The protected `system` space has `boot`, `packages`, and `policy`, with each installed program kept in one package tree. All persistent space, account, folder, and file names use only ASCII lowercase letters (`[a-z]+`); `:` and `/` are path delimiters, not name characters. File type is metadata rather than a filename extension. Stable object identities are distinct from paths so rename and move do not invalidate an open handle.

1. **Namespace contract:** define path syntax, reserved areas, name and length validation, object identity, folder traversal, and error behavior. Keep the fixed shell's current program path working while the new path is developed.
2. **Read-only foundation:** produce a deterministic, bounded boot image containing `system:packages/hello`; validate it before mount, expose bounded lookup/list/read operations, then browse it from the recovery shell and read files from a user-mode program. Launch the program from the image rather than compiled-in bytes only after image validation and shell recovery are verified.
3. **Persistent mutation:** choose and document one QEMU block-device path and its flush/error behavior. Add file and directory creation, writes, rename/move, and deletion with explicit limits, space accounting, and a recovery rule for interrupted updates. A clean remount and an interrupted-write scenario must be tested.
4. **Principals and sharing:** give each account a stable identity and private space; bind a session to one active principal; allow owner/editor/reader grants on shared spaces. Enforce access on kernel file operations and user syscalls, including stale handles after permission changes. Account selection in the recovery shell is an administrative test mechanism, not a secure login claim.
5. **Milestone verification:** run host-level format and policy tests plus QEMU tests for read-only boot, persistence across reboot, denied access, program launch, malformed media, and shell recovery. Document exact commands, supported QEMU configuration, and remaining limits.

**Milestone exit:** on the documented QEMU configuration, a user can browse and modify a personal space, reopen its files after reboot, share a space with another defined principal under enforced roles, and launch the packaged `hello` program from the read-only `system` image. Invalid names, malformed images, unauthorized access, and interrupted updates fail predictably without losing the recovery shell. This does not claim secure authentication, general process isolation, broad device support, POSIX conformance, or a production-ready filesystem.

### Following milestones

- Define a minimal executable-loading and process-lifecycle model, then add only the scheduling and isolation needed to support it.
- Add saved cross-space views only after canonical storage, permissions, and rename behavior have proven useful; views must not create alternate ownership or bypass access checks.
- Grow userland and optional POSIX-oriented compatibility in small, tested increments driven by actual programs. Keep compatibility claims limited to the documented, verified scope.
- Continue hardware and installability work only against named, tested configurations; QEMU remains the first target.
