# Add basic x86 exception and interrupt handling

**Status:** ready

## Description

Establish a minimal x86 exception/interrupt entry path with only the assembly glue needed at the machine boundary and kernel-side handling in the chosen primary language where feasible. Make at least one controlled event observable for debugging.

## Rationale and dependencies

Basic fault visibility is needed to debug kernel foundations. Depends on the booted kernel and its documented architecture boundary in tickets [0003](0003-qemu-boot-and-observable-kernel.md) and [0004](0004-document-kernel-boundaries-and-debug-loop.md).

## Acceptance criteria

- The required descriptor/configuration and entry path for the selected x86 execution mode are documented.
- A controlled exception or interrupt reaches a handler and produces a diagnostic in QEMU.
- The kernel fails in a defined, observable way for an unhandled fatal event.
- Assembly remains limited to necessary entry/return glue; no scheduler, SMP, or broad device-interrupt support is included.
