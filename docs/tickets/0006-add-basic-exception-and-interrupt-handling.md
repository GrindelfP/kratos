# Add basic x86 exception and interrupt handling

**Status:** in progress

## Description

Establish a minimal x86 exception/interrupt entry path with only the assembly glue needed at the machine boundary and kernel-side handling in the chosen primary language where feasible. Make at least one controlled event observable for debugging.

## Rationale and dependencies

Basic fault visibility is needed to debug kernel foundations. Depends on the booted kernel and its documented architecture boundary in tickets [0003](0003-qemu-boot-and-observable-kernel.md) and [0004](0004-document-kernel-boundaries-and-debug-loop.md).

## Acceptance criteria

- The required descriptor/configuration and entry path for the selected x86 execution mode are documented.
- A controlled exception or interrupt reaches a handler and produces a diagnostic in QEMU.
- The kernel fails in a defined, observable way for an unhandled fatal event.
- Assembly remains limited to necessary entry/return glue; no scheduler, SMP, or broad device-interrupt support is included.

## Implementation status

Zig IDT setup and x86_64 assembly stubs for exception vectors 0–31 are
implemented. Kernel linkage, COM1 diagnostics, QEMU event validation, and
remaining limitations will be recorded after integration is committed.

## Implementation notes

An isolated descriptor/dispatch module is in `kratos/kernel/interrupts.zig`,
with normalized x86-64 exception stubs in `kratos/kernel/interrupts.S`. The IDT
currently covers architectural exception vectors 0–31 and reads the active code
selector rather than assuming a GDT layout. Entry normalizes the optional
hardware error-code slot and preserves general-purpose registers before making
the SysV x86-64 call into Zig. The Zig dispatcher records the fatal vector and
error code, then halts; serial reporting, startup integration, and controlled
QEMU observation are still outstanding.

Architecture references consulted: Intel's official *Intel® 64 and IA-32
Architectures Software Developer's Manual*, Volume 3A (system programming,
interrupt and exception handling), available from
<https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html>.
Limine's documented entry state is summarized in [`boot-path.md`](../boot-path.md):
64-bit mode, paging enabled, interrupts disabled, and bootloader-provided stack.
