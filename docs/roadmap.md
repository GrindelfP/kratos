# KratOS roadmap

## Direction

KratOS will begin on x86 and target QEMU first. Zig is the proposed primary kernel language, with assembly limited to the small architecture-specific boundary where needed. Before treating that choice as settled, validate a specific freestanding Zig toolchain, target, linker/debugger workflow, and build path. The project’s long-term aim is a lightweight but full UNIX-like, POSIX-oriented operating system.

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

Add the first end-to-end interactive experience: a polled serial console, a small command interpreter, and a useful set of built-in commands. This is a kernel shell for the QEMU prototype; user-mode programs remain later work.

**Exit criteria:** QEMU reaches a prompt; users can enter commands and receive predictable responses; line editing and command handling are bounded; a documented demo exercises the shell.

**Scope:** serial input/output, a simple line editor, built-in commands, and a kernel command loop. **Non-goals:** keyboard/video drivers, user-mode processes, filesystem, broad application compatibility, polished desktop, or a claim of POSIX completeness.

### 4. POSIX and userland growth

Grow process, file, and system-call interfaces alongside userland, using explicit, tested POSIX-oriented compatibility goals.

**Exit criteria:** a separately documented POSIX scope is selected; implemented interfaces have conformance-oriented tests and examples; userland can be built and run against the stated interface.

**Scope:** deliberate interface and userland expansion. **Non-goals:** claiming full POSIX conformance unless verified, or adding interfaces without a defined need and tests.

### 5. Broader hardware and installability

Expand from QEMU to selected physical PC hardware and improve installation, recovery, and documentation. Support is incremental and tied to named configurations and tested components.

**Exit criteria:** each added hardware configuration has a recorded test basis and documented limitations; an installation/recovery path is documented and exercised on supported configurations.

**Scope:** staged hardware enablement and practical installation. **Non-goals:** universal PC compatibility or implying that untested hardware is supported.

## Near-term tickets

Tickets for stages 1–3 are in [`tickets/`](tickets/). Tickets 0007–0009 deliver the first interactive serial shell; later userland and POSIX work remains roadmap-level until this shell is usable.
