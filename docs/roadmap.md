# KratOS roadmap

## Direction

KratOS targets x86_64 in QEMU first. Zig is the primary kernel language, with assembly limited to the small architecture-specific boundary where needed. The initial freestanding toolchain and boot path have been validated; their limitations and reproducible build/debug workflow remain documented. The project’s long-term aim is a lightweight but full UNIX-like, POSIX-oriented operating system.

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

### 4. POSIX and userland growth

Grow process, file, and system-call interfaces alongside userland, using explicit, tested POSIX-oriented compatibility goals.

**Exit criteria:** a separately documented POSIX scope is selected; implemented interfaces have conformance-oriented tests and examples; userland can be built and run against the stated interface.

**Scope:** deliberate interface and userland expansion. **Non-goals:** claiming full POSIX conformance unless verified, or adding interfaces without a defined need and tests.

### 5. Broader hardware and installability

Expand from QEMU to selected physical PC hardware and improve installation, recovery, and documentation. Support is incremental and tied to named configurations and tested components.

**Exit criteria:** each added hardware configuration has a recorded test basis and documented limitations; an installation/recovery path is documented and exercised on supported configurations.

**Scope:** staged hardware enablement and practical installation. **Non-goals:** universal PC compatibility or implying that untested hardware is supported.

## Near-term tickets

Tickets 0001–0017 in [`tickets/`](tickets/) are complete. They delivered the QEMU boot path, kernel foundations, and an interactive kernel shell with serial and keyboard input, framebuffer output, history, completion, and a foreground animation. The shell remains a kernel-mode debug and recovery console, not userland.

### Next milestone: first user-mode program

Define and implement the smallest end-to-end user-mode execution path before expanding the command set. The planned tickets specify the architecture, boundaries, and testable acceptance criteria for:

1. **User-mode boundary:** establish the x86_64 privilege transition and the memory mappings and protections needed for one isolated program; handle user faults without silently corrupting the kernel.
2. **Minimal syscall interface:** define a small, documented ABI for output and program exit, including argument validation and observable error behavior. Do not claim POSIX compatibility for this initial interface.
3. **First program and launch path:** build a separate minimal user-mode program, load it using an explicitly documented initial mechanism, run it in QEMU, and return control to the kernel shell on exit. A general executable loader and process scheduler are not prerequisites unless the design demonstrates they are needed.
4. **Verification:** document reproducible build and QEMU commands; test successful output and exit, invalid syscall arguments, and a user fault; confirm the serial recovery shell still works afterward.

The work is tracked in order by [0018: user-mode boundary](tickets/0018-user-mode-boundary.md), [0019: syscalls](tickets/0019-minimal-user-syscalls.md), [0020: first user program](tickets/0020-first-user-program.md), and [0021: milestone verification](tickets/0021-user-mode-qemu-verification.md).

**Milestone exit:** the separate program executes at user privilege, uses the documented syscall boundary, and exits or faults in a controlled, observable way without losing the recovery console. This is a single-program foundation, not a claim of a complete process model or security guarantee.

### Following milestones

- Define a minimal executable-loading and process-lifecycle model, then add only the scheduling and isolation needed to support it.
- Plan a filesystem path, beginning with a simple read-only source of program files and a bounded file interface; evolve toward persistent storage only after its requirements and recovery behavior are defined.
- Grow userland and POSIX-oriented interfaces in small, tested increments driven by actual programs. Keep compatibility claims limited to the documented, verified scope.
- Continue hardware and installability work only against named, tested configurations; QEMU remains the first target.
